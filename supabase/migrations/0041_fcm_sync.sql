-- FCM-only cross-device sync (decision 2026-09-27): EVERY change another
-- device needs to know about now reaches it as a silent FCM data message,
-- and Supabase Realtime is dropped entirely -- including the only
-- subscription that ever existed (channel_feed_screen.dart's media_items
-- watch) and the six tables 0040_realtime_expand.sql had just added for a
-- Realtime-based approach that was never wired into any screen.
--
-- Why triggers rather than Edge Functions sending the push themselves:
-- most writes in this app are plain RLS-governed client updates (deciding
-- a request, renaming, leaving a channel, hiding a photo ...) that never
-- pass through any Edge Function. A statement-level trigger on every
-- relevant table is the one place that sees ALL of them, whoever wrote
-- them. It resolves *who* is affected right here in SQL (while the rows
-- are still at hand, before anything is cascaded away) and hands the list
-- to the sync-fanout Edge Function via pg_net, which only looks up tokens
-- and sends. pg_net queues requests in a table, so a rolled-back write
-- never sends anything.
--
-- Visible notifications (invites, decisions, new photos ...) are
-- unaffected -- those stay with the Edge Functions that already send them.
-- This is purely the silent "something you can see changed, reload" layer.
--
-- Setup outside of git (secrets never belong in a migration), once per
-- project:
--   select vault.create_secret('https://<ref>.supabase.co/functions/v1/sync-fanout', 'sync_fanout_url');
--   select vault.create_secret('<random>', 'sync_fanout_secret');
--   supabase secrets set SYNC_FANOUT_SECRET=<same random>
-- Without those two vault secrets, sync_notify() silently does nothing --
-- never a reason for the write itself to fail.

create extension if not exists pg_net;

-- =========================================================================
-- 1. Drop Supabase Realtime entirely
-- =========================================================================

do $$
declare
  t record;
begin
  for t in
    select schemaname, tablename from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
  loop
    execute format('alter publication supabase_realtime drop table %I.%I', t.schemaname, t.tablename);
  end loop;
end;
$$;

-- Only ever needed so Realtime could RLS-check a DELETE's old row
-- (0036_media_items_replica_identity_full.sql) -- pure WAL overhead now.
alter table media_items replica identity default;

-- =========================================================================
-- 2. Audience helpers -- who can currently see a given Space/Channel.
--    Mirror can_view_channel()/is_space_owner() (incl. co-owners, 0037),
--    but for "list everyone" instead of "check auth.uid()".
-- =========================================================================

create or replace function sync_space_audience(check_space_id uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select owner_id from spaces where id = check_space_id
  union
  select user_id from space_co_owners where space_id = check_space_id;
$$;

create or replace function sync_channel_audience(check_channel_id uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select sync_space_audience(c.space_id) from channels c where c.id = check_channel_id
  union
  select user_id from channel_members where channel_id = check_channel_id
  union
  select sync_space_audience(cs.space_id) from channel_shares cs where cs.channel_id = check_channel_id;
$$;

-- Everyone who could be showing this user's name/avatar somewhere: every
-- channel they can see, every Space they (co-)own, and whoever is on the
-- other end of a request/invite concerning them.
create or replace function sync_user_audience(check_user_id uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  with my_spaces as (
    select id from spaces where owner_id = check_user_id
    union
    select space_id from space_co_owners where user_id = check_user_id
  ),
  my_channels as (
    select channel_id from channel_members where user_id = check_user_id
    union
    select id from channels where space_id in (select id from my_spaces)
    union
    select channel_id from channel_shares where space_id in (select id from my_spaces)
  )
  select check_user_id
  union
  select sync_channel_audience(channel_id) from my_channels
  union
  select sync_space_audience(id) from my_spaces
  union
  select sync_space_audience(c.space_id)
    from channel_membership_requests r join channels c on c.id = r.channel_id
    where r.user_id = check_user_id and r.status = 'pending'
  union
  select sync_space_audience(c.space_id)
    from channel_share_requests r join channels c on c.id = r.channel_id
    where r.target_user_id = check_user_id and r.status = 'pending'
  union
  select sync_space_audience(i.space_id)
    from space_co_owner_invites i
    where i.invitee_user_id = check_user_id and i.status = 'pending';
$$;

-- =========================================================================
-- 3. The trigger
-- =========================================================================

create or replace function sync_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_rows jsonb;
  v_new jsonb;
  v_old jsonb;
  -- Columns whose change alone is NOT worth a push: Frame telemetry
  -- (submit-heartbeat/get-media-batch write these every few minutes -- a
  -- push per heartbeat would be pure noise, and the Frame would even push
  -- itself on every sync), and per-delivery bookkeeping on
  -- media_recipients.
  v_ignore text[] := case tg_table_name
    when 'frames' then array['last_seen_at', 'battery_level', 'is_charging', 'current_app_version', 'fcm_token', 'device_model']
    when 'media_recipients' then array['delivered_at', 'viewed_at']
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
      where tg_table_name in ('frame_channels', 'media_recipients')
    union
    select (r->>'id')::uuid
      from jsonb_array_elements(v_rows) r
      where tg_table_name = 'frames' and tg_op <> 'DELETE'
    union
    -- Channel renamed/deleted: its name shows in the Frame's switcher.
    select fc.frame_id
      from frame_channels fc
      where tg_table_name = 'channels' and fc.channel_id::text = any(v_channel_ids)
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

-- Statement-level, one trigger per event (Postgres doesn't allow
-- transition tables on a multi-event trigger): a bulk write or a cascade
-- is one push per table, not one per row.
do $$
declare
  t text;
begin
  foreach t in array array[
    'spaces', 'channels', 'channel_members', 'channel_shares',
    'channel_membership_requests', 'channel_share_requests',
    'space_co_owners', 'space_co_owner_invites',
    'frames', 'frame_channels',
    'media_items', 'media_item_hides', 'media_recipients',
    'profiles'
  ] loop
    execute format('drop trigger if exists sync_notify_ins on %I', t);
    execute format('drop trigger if exists sync_notify_upd on %I', t);
    execute format('drop trigger if exists sync_notify_del on %I', t);
    execute format(
      'create trigger sync_notify_ins after insert on %I referencing new table as new_rows '
      'for each statement execute function sync_notify()', t);
    execute format(
      'create trigger sync_notify_upd after update on %I referencing old table as old_rows new table as new_rows '
      'for each statement execute function sync_notify()', t);
    execute format(
      'create trigger sync_notify_del after delete on %I referencing old table as old_rows '
      'for each statement execute function sync_notify()', t);
  end loop;
end;
$$;
