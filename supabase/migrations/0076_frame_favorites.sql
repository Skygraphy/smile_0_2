-- Lieblingsbilder (decided with the user 2026-10-14, preview "Lieblingsbilder
-- am Frame"): favorites belong to a Frame, not to a person -- the grandma
-- in front of it has no account. Marked on the Frame (added_by null) or by
-- one of the Frame's managers in the app; managed (and removed in bulk) by
-- them. Two new controls: "favorite" (mark on the Frame) and "favorites"
-- (play them there), both from level 3 "Einfach" on. A fourth playback
-- content: only the favorites.

create table if not exists frame_favorites (
  frame_id uuid not null references frames(id) on delete cascade,
  media_item_id uuid not null references media_items(id) on delete cascade,
  -- Null: marked on the Frame itself.
  added_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (frame_id, media_item_id)
);
create index if not exists idx_frame_favorites_media on frame_favorites(media_item_id);

alter table frame_favorites enable row level security;

-- The Frame's managers (its Space's Admin and Co-Admins), like the Frame.
create policy frame_favorites_select on frame_favorites
  for select using (exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id)));
create policy frame_favorites_insert on frame_favorites
  for insert with check (
    added_by = auth.uid()
    and exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
  );
create policy frame_favorites_delete on frame_favorites
  for delete using (exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id)));

-- Only the favorites as a playback content.
alter table frames drop constraint if exists frames_content_mode_check;
alter table frames add constraint frames_content_mode_check
  check (content_mode in ('album', 'rotate', 'recent', 'favorites'));

-- The two new controls: on from level 3; on a custom selection like "Neueste".
alter table frames alter column controls set default
  '{"next": true, "back": true, "pause": true, "newest": true, "favorite": true, "favorites": true, "overview": false, "album": false, "duration": false, "playback": false}'::jsonb;
update frames set controls = controls || jsonb_build_object(
  'favorite', coalesce(control_level >= 3, controls->>'newest' = 'true'),
  'favorites', coalesce(control_level >= 3, controls->>'newest' = 'true')
);

-- Changes to a Frame's favorites wake the Frame and reach its managers'
-- apps. Same function as 0061, frame_favorites added next to frame_channels.
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
  v_user uuid;
begin
  if tg_op in ('INSERT', 'UPDATE') then
    select coalesce(jsonb_agg(to_jsonb(n)), '[]'::jsonb) into v_new from new_rows n;
  end if;
  if tg_op in ('DELETE', 'UPDATE') then
    select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) into v_old from old_rows o;
  end if;

  -- A photo moving from "uploaded" to "processing" changes nothing anyone
  -- sees (the preview shows either way): only its arrival, it becoming
  -- ready (or failing) and its deletion are worth waking devices for.
  if tg_table_name = 'media_items' and tg_op = 'UPDATE' and not exists (
    select 1 from jsonb_array_elements(v_new) r where r->>'processing_status' in ('ready', 'failed')
  ) then
    return null;
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
      when 'album_reads' then (r->>'user_id')::uuid
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
      where tg_table_name in ('frame_channels', 'frame_favorites')
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
      where tg_table_name in ('frame_channels', 'frame_favorites')
    union
    select (r->>'id')::uuid
      from jsonb_array_elements(v_rows) r
      where tg_table_name = 'frames' and tg_op <> 'DELETE'
    union
    -- Space renamed/trashed/restored: its name shows on every Frame of it
    -- ("Bergoma · Enkelkinder"), found in the 2026-10-06 walkthrough.
    select f.id
      from frames f
      where tg_table_name = 'spaces' and f.space_id::text = any(v_space_ids)
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

  -- Through the outbox (0050): retried until it arrives.
  perform invoke_internal('sync-fanout', jsonb_build_object(
    'table', tg_table_name,
    'op', lower(tg_op),
    'users', coalesce(to_jsonb(v_users), '[]'::jsonb),
    'frames', coalesce(to_jsonb(v_frames), '[]'::jsonb),
    'channel_ids', coalesce(to_jsonb(v_channel_ids), '[]'::jsonb),
    'space_ids', coalesce(to_jsonb(v_space_ids), '[]'::jsonb)
  ));
  -- Open apps (iPhone and Android alike) get the same signal at once over
  -- their private live channel (0053) -- iOS throttles silent pushes even
  -- for an app in the foreground. Delivered by Realtime after commit.
  if v_users is not null then
    for v_user in select unnest(v_users) loop
      perform realtime.send(
        jsonb_build_object(
          'type', 'sync',
          'table', tg_table_name,
          'op', lower(tg_op),
          'channel_ids', coalesce(array_to_string(v_channel_ids, ','), ''),
          'space_ids', coalesce(array_to_string(v_space_ids, ','), '')
        ),
        'sync',
        'sync:' || v_user,
        true
      );
    end loop;
  end if;
  return null;
exception when others then
  -- A sync push is a convenience layered on top of the write -- it must
  -- never be the reason the write itself fails.
  raise warning 'sync_notify(%) failed: %', tg_table_name, sqlerrm;
  return null;
end;
$$;

drop trigger if exists sync_notify_ins on frame_favorites;
drop trigger if exists sync_notify_del on frame_favorites;
create trigger sync_notify_ins after insert on frame_favorites referencing new table as new_rows
  for each statement execute function sync_notify();
create trigger sync_notify_del after delete on frame_favorites referencing old table as old_rows
  for each statement execute function sync_notify();
