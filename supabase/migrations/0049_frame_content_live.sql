-- Architecture review 2026-09-29, weakness 4: media_recipients was a
-- stored copy of "which photo shows on which Frame" (one row per photo and
-- Frame). Every change to who may see what needed its own code to keep it
-- in step -- the backfill on assignment, the fan-out on upload, 0044's
-- cleanup on a share ending -- and one missed path (2026-09-27) left a
-- Frame showing a channel its household could no longer see.
--
-- Frames now compute their content live on every poll (get-media-batch):
-- the channels assigned to the Frame that its household can see right now
-- (frame_visible_channels, built on 0047's single source, so trash and
-- revoked shares are covered automatically), and the ready photos in them.
-- Nothing derived to keep in step any more.

-- The channels a Frame may show right now, in its order.
create or replace function frame_visible_channels(p_frame uuid)
returns table (channel_id uuid, name text, sort_order int)
language sql stable security definer set search_path = public as $$
  select fc.channel_id, c.name, fc.sort_order
  from frame_channels fc
  join frames f on f.id = fc.frame_id
  join channels c on c.id = fc.channel_id
  where fc.frame_id = p_frame
    and access_space_can_view_channel(f.space_id, fc.channel_id)
  order by fc.sort_order, fc.created_at;
$$;

-- One page of ready photos in a channel, oldest first. sort_key = the
-- photo's created_at in microseconds: unique enough to page by (a
-- millisecond key could repeat the page's last photo on the next page)
-- and still a plain integer for the Frame's existing cursor.
create or replace function frame_media_page(p_channel uuid, p_after bigint, p_limit int)
returns table (media_item_id uuid, media_type text, storage_path_display text, sort_key bigint)
language sql stable security definer set search_path = public as $$
  select id, media_type, storage_path_display, (extract(epoch from created_at) * 1000000)::bigint as sort_key
  from media_items
  where channel_id = p_channel
    and processing_status = 'ready'
    and storage_path_display is not null
    and (p_after is null or (extract(epoch from created_at) * 1000000)::bigint > p_after)
  order by created_at, id
  limit p_limit;
$$;

revoke all on function frame_visible_channels(uuid) from public, anon, authenticated;
grant execute on function frame_visible_channels(uuid) to service_role;
revoke all on function frame_media_page(uuid, bigint, int) from public, anon, authenticated;
grant execute on function frame_media_page(uuid, bigint, int) to service_role;

-- 0044's cleanup no longer has a media_recipients to clear; the frame
-- assignment itself still goes, so a later re-share doesn't silently put
-- the channel back on the Frame.
create or replace function handle_channel_share_removed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from frame_channels fc
    using frames f
    where fc.frame_id = f.id and f.space_id = old.space_id and fc.channel_id = old.channel_id;
  return old;
end;
$$;

drop table media_recipients;

-- sync_notify (0041) without media_recipients: Frames are woken by the
-- media_items change itself.
create or replace function sync_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_rows jsonb;
  v_new jsonb;
  v_old jsonb;
  -- Columns whose change alone is NOT worth a push: Frame telemetry
  -- (submit-heartbeat/get-media-batch write these every few minutes -- a
  -- push per heartbeat would be pure noise, and the Frame would even push
  -- itself on every sync).
  v_ignore text[] := case tg_table_name
    when 'frames' then array['last_seen_at', 'battery_level', 'is_charging', 'current_app_version', 'fcm_token', 'device_model']
    else array[]::text[]
  end;
  v_users uuid[];
  v_frames uuid[];
  v_channel_ids text[];
  v_space_ids text[];
  v_url text;
  v_secret text;
begin
  if tg_op in ('INSERT', 'UPDATE') then
    select coalesce(jsonb_agg(to_jsonb(n)), '[]'::jsonb) into v_new from new_rows n;
  end if;
  if tg_op in ('DELETE', 'UPDATE') then
    select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) into v_old from old_rows o;
  end if;

  if tg_op = 'UPDATE' then
    -- Skip an update that changed nothing but ignored columns (or nothing
    -- at all). Compared as sorted sets, so no per-table key knowledge needed.
    if (select coalesce(jsonb_agg(r - v_ignore order by (r - v_ignore)::text), '[]'::jsonb) from jsonb_array_elements(v_new) r)
       = (select coalesce(jsonb_agg(r - v_ignore order by (r - v_ignore)::text), '[]'::jsonb) from jsonb_array_elements(v_old) r)
    then
      return null;
    end if;
  end if;

  v_rows := coalesce(v_new, '[]'::jsonb) || coalesce(v_old, '[]'::jsonb);
  if jsonb_array_length(v_rows) = 0 then
    return null;
  end if;

  select array_agg(distinct x) into v_channel_ids from (
    select coalesce(r->>'channel_id', case when tg_table_name = 'channels' then r->>'id' end) as x
    from jsonb_array_elements(v_rows) r
  ) s where x is not null;

  select array_agg(distinct x) into v_space_ids from (
    select coalesce(r->>'space_id', case when tg_table_name = 'spaces' then r->>'id' end) as x
    from jsonb_array_elements(v_rows) r
  ) s where x is not null;

  -- Who sees it. Direct user columns on the row itself are always
  -- included too -- after a delete (someone removed from a channel, an
  -- invite withdrawn) that person is no longer derivable from the
  -- remaining data, but is exactly who most needs to reload.
  select array_agg(distinct u) into v_users from (
    select case tg_table_name
      when 'spaces' then (r->>'owner_id')::uuid
      when 'channel_members' then (r->>'user_id')::uuid
      when 'channel_membership_requests' then (r->>'user_id')::uuid
      when 'channel_share_requests' then (r->>'target_user_id')::uuid
      when 'space_co_owners' then (r->>'user_id')::uuid
      when 'space_co_owner_invites' then (r->>'invitee_user_id')::uuid
      when 'media_item_hides' then (r->>'user_id')::uuid
      when 'profiles' then (r->>'user_id')::uuid
    end as u
    from jsonb_array_elements(v_rows) r
    union
    -- Requests/invites are only visible to the two parties -- never to
    -- every channel member -- so they get the home Space's audience, not
    -- the whole channel's. Same for a Frame's own settings/assignments.
    select sync_space_audience(c.space_id)
      from channels c
      where tg_table_name in ('channel_membership_requests', 'channel_share_requests')
        and c.id::text = any(v_channel_ids)
    union
    select sync_channel_audience(cid::uuid)
      from unnest(v_channel_ids) cid
      where tg_table_name in ('channels', 'channel_members', 'channel_shares', 'media_items')
    union
    select sync_space_audience(sid::uuid)
      from unnest(v_space_ids) sid
      where tg_table_name in ('spaces', 'channels', 'channel_shares', 'channel_share_requests',
                              'space_co_owners', 'space_co_owner_invites', 'frames')
    union
    -- A Space rename shows up in its channels' and shared-in channels' lists.
    select sync_channel_audience(c.id)
      from channels c
      where tg_table_name = 'spaces' and c.space_id::text = any(v_space_ids)
    union
    select sync_channel_audience(cs.channel_id)
      from channel_shares cs
      where tg_table_name = 'spaces' and cs.space_id::text = any(v_space_ids)
    union
    select sync_space_audience(f.space_id)
      from frames f
      where tg_table_name = 'frame_channels'
        and f.id::text in (select r->>'frame_id' from jsonb_array_elements(v_rows) r)
    union
    select sync_user_audience((r->>'user_id')::uuid)
      from jsonb_array_elements(v_rows) r
      where tg_table_name = 'profiles'
  ) s where u is not null;

  -- Which Frames need to re-sync (smile-frame treats any FCM message as
  -- "sync now", see PushSyncSignal).
  select array_agg(distinct f) into v_frames from (
    select (r->>'frame_id')::uuid as f
      from jsonb_array_elements(v_rows) r
      where tg_table_name = 'frame_channels'
    union
    select (r->>'id')::uuid
      from jsonb_array_elements(v_rows) r
      where tg_table_name = 'frames' and tg_op <> 'DELETE'
    union
    -- Channel renamed/trashed: its name shows in the Frame's switcher.
    select fc.frame_id
      from frame_channels fc
      where tg_table_name = 'channels' and fc.channel_id::text = any(v_channel_ids)
    union
    -- A photo became ready (or was deleted) in a channel a Frame shows.
    -- Frames compute their content live from media_items now (0049), so
    -- this replaces the push the media_recipients insert used to cause.
    -- Uploads still processing don't wake Frames: they can't show them yet.
    select fc.frame_id
      from frame_channels fc
      where tg_table_name = 'media_items'
        and fc.channel_id::text = any(v_channel_ids)
        and (tg_op = 'DELETE' or exists (
          select 1 from jsonb_array_elements(v_new) r where r->>'processing_status' = 'ready'
        ))
  ) s where f is not null;

  if coalesce(array_length(v_users, 1), 0) = 0 and coalesce(array_length(v_frames, 1), 0) = 0 then
    return null;
  end if;

  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'sync_fanout_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'sync_fanout_secret';
  if v_url is null or v_secret is null then
    return null;
  end if;

  perform net.http_post(
    url := v_url,
    body := jsonb_build_object(
      'table', tg_table_name,
      'op', lower(tg_op),
      'users', coalesce(to_jsonb(v_users), '[]'::jsonb),
      'frames', coalesce(to_jsonb(v_frames), '[]'::jsonb),
      'channel_ids', coalesce(to_jsonb(v_channel_ids), '[]'::jsonb),
      'space_ids', coalesce(to_jsonb(v_space_ids), '[]'::jsonb)
    ),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-sync-secret', v_secret),
    timeout_milliseconds := 5000
  );
  return null;
exception when others then
  -- A sync push is a convenience layered on top of the write -- it must
  -- never be the reason the write itself fails.
  raise warning 'sync_notify(%) failed: %', tg_table_name, sqlerrm;
  return null;
end;
$$;
