-- Decision 2026-09-29 (architecture review, weakness 2): deleting a Space
-- or Channel no longer destroys everyone's photos on the spot. It moves it
-- to a 30-day trash: invisible to everyone, everyone affected is notified,
-- the people who manage it can restore it, and only after 30 days does a
-- daily job (purge-trash) delete it for good, files included.
--
-- Built on 0047's single source: the access_* functions treat anything in
-- the trash as not there. So a trashed Channel disappears at once from
-- RLS, every Edge Function, every client list and every Frame -- no
-- per-screen filtering needed.

alter table spaces
  add column deleted_at timestamptz,
  add column deleted_by uuid references auth.users(id) on delete set null;
alter table channels
  add column deleted_at timestamptz,
  add column deleted_by uuid references auth.users(id) on delete set null;

create index idx_spaces_deleted_at on spaces(deleted_at) where deleted_at is not null;
create index idx_channels_deleted_at on channels(deleted_at) where deleted_at is not null;

-- =========================================================================
-- 1. "Active" = not in the trash, itself or through its Space
-- =========================================================================

create or replace function access_space_active(p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from spaces where id = p_space and deleted_at is null);
$$;

create or replace function access_channel_active(p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from channels c join spaces s on s.id = c.space_id
    where c.id = p_channel and c.deleted_at is null and s.deleted_at is null
  );
$$;

-- =========================================================================
-- 2. The single source, now trash-aware. access_is_space_admin stays
--    unfiltered on purpose: the Administrator of a trashed Space is still
--    the one who may restore it.
-- =========================================================================

create or replace function access_manages_space(p_user uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_space_active(p_space) and (
    access_is_space_admin(p_user, p_space)
    or exists (select 1 from space_co_owners where space_id = p_space and user_id = p_user)
  );
$$;

create or replace function access_manages_channel(p_user uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_channel_active(p_channel)
    and exists (select 1 from channels c where c.id = p_channel and access_manages_space(p_user, c.space_id));
$$;

create or replace function access_is_channel_member(p_user uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_channel_active(p_channel)
    and exists (select 1 from channel_members where channel_id = p_channel and user_id = p_user);
$$;

create or replace function access_space_can_view_channel(p_space uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_space_active(p_space) and access_channel_active(p_channel) and (
    exists (select 1 from channels where id = p_channel and space_id = p_space)
    or exists (select 1 from channel_shares where channel_id = p_channel and space_id = p_space)
  );
$$;

-- access_can_view_channel needs no change: every branch above it is now
-- trash-aware (staff keep seeing everything, as before).

create or replace function access_visible_channel_ids(p_user uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  with my_spaces as (
    select id from spaces where owner_id = p_user and deleted_at is null
    union
    select sco.space_id from space_co_owners sco join spaces s on s.id = sco.space_id
      where sco.user_id = p_user and s.deleted_at is null
  ),
  candidates as (
    select id from channels where space_id in (select id from my_spaces)
    union
    select channel_id from channel_members where user_id = p_user
    union
    select channel_id from channel_shares where space_id in (select id from my_spaces)
  )
  select id from candidates where access_channel_active(id);
$$;

create or replace function access_channel(p_user uuid, p_channel uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when c.id is null then jsonb_build_object('exists', false)
  else jsonb_build_object(
    'exists', true,
    'active', access_channel_active(c.id),
    'home_space_id', c.space_id,
    'is_staff', access_is_staff(p_user),
    'manages', access_manages_space(p_user, c.space_id),
    'is_admin', access_is_space_admin(p_user, c.space_id),
    'is_member', access_is_channel_member(p_user, c.id),
    'can_view', access_can_view_channel(p_user, c.id)
  ) end
  from (select 1) one left join channels c on c.id = p_channel;
$$;

create or replace function access_space(p_user uuid, p_space uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when s.id is null then jsonb_build_object('exists', false)
  else jsonb_build_object(
    'exists', true,
    'active', s.deleted_at is null,
    'is_staff', access_is_staff(p_user),
    'manages', access_manages_space(p_user, s.id),
    'is_admin', s.owner_id = p_user,
    'admin_id', s.owner_id
  ) end
  from (select 1) one left join spaces s on s.id = p_space;
$$;

do $$
declare
  f text;
begin
  foreach f in array array['access_space_active(uuid)', 'access_channel_active(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

-- =========================================================================
-- 3. The two policies that decide visibility from the row itself
-- =========================================================================

drop policy spaces_select on spaces;
create policy spaces_select on spaces
  for select using (
    (deleted_at is null and (owner_id = auth.uid() or is_space_owner(id)))
    or is_staff()
  );

drop policy channels_select on channels;
create policy channels_select on channels
  for select using (
    (deleted_at is null and (
      is_space_owner(space_id)
      or is_channel_member(id)
      or exists (select 1 from channel_shares cs where cs.channel_id = channels.id and is_space_owner(cs.space_id))
    ))
    or is_staff()
  );

-- =========================================================================
-- 4. Calling our own Edge Functions from the database (events, the daily
--    purge) -- one helper, emit_event() now just a use of it.
-- =========================================================================

create or replace function invoke_internal(fn text, body jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_secret text;
begin
  select replace(decrypted_secret, '/sync-fanout', '/' || fn) into v_url
    from vault.decrypted_secrets where name = 'sync_fanout_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'sync_fanout_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    body := body,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-sync-secret', v_secret),
    timeout_milliseconds := 30000
  );
exception when others then
  raise warning 'invoke_internal(%) failed: %', fn, sqlerrm;
end;
$$;

create or replace function emit_event(kind text, payload jsonb)
returns void language sql security definer set search_path = public as $$
  select invoke_internal('notify-event', jsonb_build_object('kind', kind, 'payload', payload));
$$;

revoke all on function invoke_internal(text, jsonb) from public, anon, authenticated;
revoke all on function emit_event(text, jsonb) from public, anon, authenticated;

-- Daily at 03:17 UTC: delete for good whatever has been in the trash for
-- more than 30 days (purge-trash/index.ts).
create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'smile-purge-trash';
select cron.schedule('smile-purge-trash', '17 3 * * *', $cron$select invoke_internal('purge-trash', '{}'::jsonb)$cron$);
