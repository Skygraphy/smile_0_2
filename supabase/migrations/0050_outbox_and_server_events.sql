-- Architecture review 2026-09-29, weakness 6: delivery without a
-- guarantee. Every call the database made to our own Edge Functions
-- (sync-fanout for the silent sync, notify-event for visible
-- notifications, purge-trash) was a single fire-and-forget pg_net request:
-- if the function was briefly unavailable, the push was simply lost. And
-- "your invite was accepted/declined" was sent by the deciding APP after
-- the fact (notify-request-decided) -- closed right after deciding, and
-- nobody heard of it; it also only ever told the Administrator, never the
-- co-owners.
--
-- 1. An outbox: invoke_internal() records every call first, sends it at
--    once, and a job every minute checks pg_net's responses -- anything
--    that didn't come back 2xx is retried with growing gaps (1, 2, 4, 8,
--    16 minutes), up to 5 attempts. It all happens inside the writing
--    transaction, so a rolled-back write still sends nothing.
-- 2. Deciding a request/invite raises a server-side event (notify-event
--    'request_decided'); the app no longer sends anything itself.
-- 3. media_items updates that nobody can see (uploaded -> processing) no
--    longer wake every device (sync_notify below).

-- =========================================================================
-- 1. Outbox
-- =========================================================================

create table internal_calls (
  id bigserial primary key,
  fn text not null,
  body jsonb not null,
  attempts int not null default 0,
  request_id bigint,
  sent_at timestamptz,
  next_attempt_at timestamptz not null default now(),
  done_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create index idx_internal_calls_open on internal_calls(next_attempt_at) where done_at is null;

-- Server-internal only: no client role ever reads or writes it.
alter table internal_calls enable row level security;

create or replace function internal_call_send(p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_call internal_calls;
  v_url text;
  v_secret text;
  v_request bigint;
begin
  select * into v_call from internal_calls where id = p_id;
  select replace(decrypted_secret, '/sync-fanout', '/' || v_call.fn) into v_url
    from vault.decrypted_secrets where name = 'sync_fanout_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'sync_fanout_secret';
  if v_url is null or v_secret is null then
    update internal_calls set done_at = now(), last_error = 'not configured' where id = p_id;
    return;
  end if;
  select net.http_post(
    url := v_url,
    body := v_call.body,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-sync-secret', v_secret),
    timeout_milliseconds := 30000
  ) into v_request;
  update internal_calls set attempts = attempts + 1, request_id = v_request, sent_at = now() where id = p_id;
end;
$$;

create or replace function invoke_internal(fn text, body jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_id bigint;
begin
  insert into internal_calls (fn, body) values (fn, body) returning id into v_id;
  perform internal_call_send(v_id);
exception when others then
  -- Never the reason a user's write fails.
  raise warning 'invoke_internal(%) failed: %', fn, sqlerrm;
end;
$$;

-- Every minute: settle what came back, retry what didn't, forget old
-- successes.
create or replace function process_internal_calls()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_call record;
begin
  for v_call in
    select c.id, c.attempts, c.sent_at, r.status_code, r.error_msg, r.created as responded_at
    from internal_calls c
    left join net._http_response r on r.id = c.request_id
    where c.done_at is null and c.request_id is not null
  loop
    if v_call.status_code between 200 and 299 then
      update internal_calls set done_at = now(), last_error = null where id = v_call.id;
    elsif v_call.responded_at is not null or v_call.sent_at < now() - interval '10 minutes' then
      -- Failed (or never answered): retry later, or give up after 5 tries.
      update internal_calls set
        request_id = null,
        last_error = coalesce(v_call.error_msg, 'HTTP ' || v_call.status_code, 'no response'),
        next_attempt_at = now() + make_interval(mins => power(2, v_call.attempts - 1)::int),
        done_at = case when v_call.attempts >= 5 then now() end
      where id = v_call.id;
    end if;
  end loop;

  for v_call in
    select id from internal_calls
    where done_at is null and request_id is null and next_attempt_at <= now()
    order by id
    limit 200
  loop
    perform internal_call_send(v_call.id);
  end loop;

  delete from internal_calls where done_at < now() - interval '7 days';
end;
$$;

revoke all on function internal_call_send(bigint) from public, anon, authenticated;
revoke all on function invoke_internal(text, jsonb) from public, anon, authenticated;
revoke all on function process_internal_calls() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'smile-internal-calls';
select cron.schedule('smile-internal-calls', '* * * * *', $cron$select process_internal_calls()$cron$);

-- =========================================================================
-- 2. "Request decided" from the server
-- =========================================================================

create or replace function handle_request_decided_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status = 'pending' and new.status in ('accepted', 'declined') then
    perform emit_event('request_decided', jsonb_build_object(
      'table', tg_table_name, 'id', new.id, 'actor_id', auth.uid()));
  end if;
  return new;
end;
$$;

drop trigger if exists on_request_decided_event on channel_membership_requests;
create trigger on_request_decided_event
  after update on channel_membership_requests
  for each row execute function handle_request_decided_event();
drop trigger if exists on_request_decided_event on channel_share_requests;
create trigger on_request_decided_event
  after update on channel_share_requests
  for each row execute function handle_request_decided_event();
drop trigger if exists on_request_decided_event on space_co_owner_invites;
create trigger on_request_decided_event
  after update on space_co_owner_invites
  for each row execute function handle_request_decided_event();

-- =========================================================================
-- 3. sync_notify through the outbox, without invisible media updates
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
  -- itself on every sync).
  v_ignore text[] := case tg_table_name
    when 'frames' then array['last_seen_at', 'battery_level', 'is_charging', 'current_app_version', 'fcm_token', 'device_model']
    else array[]::text[]
  end;
  v_users uuid[];
  v_frames uuid[];
  v_channel_ids text[];
  v_space_ids text[];
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

  -- Through the outbox (0050): retried until it arrives.
  perform invoke_internal('sync-fanout', jsonb_build_object(
    'table', tg_table_name,
    'op', lower(tg_op),
    'users', coalesce(to_jsonb(v_users), '[]'::jsonb),
    'frames', coalesce(to_jsonb(v_frames), '[]'::jsonb),
    'channel_ids', coalesce(to_jsonb(v_channel_ids), '[]'::jsonb),
    'space_ids', coalesce(to_jsonb(v_space_ids), '[]'::jsonb)
  ));
  return null;
exception when others then
  -- A sync push is a convenience layered on top of the write -- it must
  -- never be the reason the write itself fails.
  raise warning 'sync_notify(%) failed: %', tg_table_name, sqlerrm;
  return null;
end;
$$;
