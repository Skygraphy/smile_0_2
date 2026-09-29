-- Architecture review 2026-09-29, weakness 3: authorization was decided in
-- three places -- RLS helpers here, each Edge Function's own TypeScript
-- re-implementation (_shared/channel-access.ts, space-access.ts, inline
-- checks) and client pre-checks. Every new role had to be found and added
-- in all of them, and on 2026-09-27/29 several copies had already drifted:
--   - delete-media didn't know co-owners (fixed in b690833),
--   - resolveChannelAccess treated only a shared-in Space's Administrator as
--     a viewer, not its co-owners (RLS let them see the channel, the Edge
--     Functions answered 403),
--   - list-my-channels left out a co-owner's own Space's channels and
--     channels shared into Spaces they co-own,
--   - frame_channels' RLS asked whether the *person* can see a channel, not
--     whether the Frame's *household* can -- a co-owner who is personally a
--     member of someone else's channel could put it on the household Frame.
--
-- From here on every decision exists exactly ONCE, as an access_* function
-- taking the user explicitly. RLS calls them through the familiar
-- auth.uid() wrappers (is_space_owner(), can_view_channel(), ...); Edge
-- Functions call the same access_* functions via RPC. The access_*
-- functions take any user id, so only service_role may execute them
-- directly -- otherwise anyone could probe someone else's access.

-- =========================================================================
-- 1. The single source
-- =========================================================================

create or replace function access_is_staff(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from staff_members where user_id = p_user);
$$;

-- The Administrator (spaces.owner_id) only.
create or replace function access_is_space_admin(p_user uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from spaces where id = p_space and owner_id = p_user);
$$;

-- Administrator or co-owner: everyone who manages the Space.
create or replace function access_manages_space(p_user uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_is_space_admin(p_user, p_space)
    or exists (select 1 from space_co_owners where space_id = p_space and user_id = p_user);
$$;

-- Manages the channel's home Space.
create or replace function access_manages_channel(p_user uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from channels c where c.id = p_channel and access_manages_space(p_user, c.space_id));
$$;

-- Posting rights.
create or replace function access_is_channel_member(p_user uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from channel_members where channel_id = p_channel and user_id = p_user);
$$;

-- Can a HOUSEHOLD see a channel: its own, or shared into it. What a Frame
-- of that Space may show.
create or replace function access_space_can_view_channel(p_space uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from channels where id = p_channel and space_id = p_space)
    or exists (select 1 from channel_shares where channel_id = p_channel and space_id = p_space);
$$;

-- Can a PERSON see a channel: manages its home Space, posts in it, manages
-- a Space it is shared into (a share belongs to the whole household,
-- decision 2026-09-29), or is staff.
create or replace function access_can_view_channel(p_user uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_manages_channel(p_user, p_channel)
    or access_is_channel_member(p_user, p_channel)
    or exists (
      select 1 from channel_shares cs where cs.channel_id = p_channel and access_manages_space(p_user, cs.space_id)
    )
    or access_is_staff(p_user);
$$;

-- The same rule as a list -- for "all my channels" (list-my-channels).
create or replace function access_visible_channel_ids(p_user uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  with my_spaces as (
    select id from spaces where owner_id = p_user
    union
    select space_id from space_co_owners where user_id = p_user
  )
  select id from channels where space_id in (select id from my_spaces)
  union
  select channel_id from channel_members where user_id = p_user
  union
  select channel_id from channel_shares where space_id in (select id from my_spaces);
$$;

-- One summary per channel for Edge Functions (replaces the TypeScript
-- resolveChannelAccess logic).
create or replace function access_channel(p_user uuid, p_channel uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when c.id is null then jsonb_build_object('exists', false)
  else jsonb_build_object(
    'exists', true,
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
    'is_staff', access_is_staff(p_user),
    'manages', access_manages_space(p_user, s.id),
    'is_admin', s.owner_id = p_user,
    'admin_id', s.owner_id
  ) end
  from (select 1) one left join spaces s on s.id = p_space;
$$;

-- Any user id goes in -> service_role only. The RLS wrappers below run as
-- the function owner (security definer), so they may still call these.
do $$
declare
  f text;
begin
  foreach f in array array[
    'access_is_staff(uuid)', 'access_is_space_admin(uuid, uuid)', 'access_manages_space(uuid, uuid)',
    'access_manages_channel(uuid, uuid)', 'access_is_channel_member(uuid, uuid)',
    'access_space_can_view_channel(uuid, uuid)', 'access_can_view_channel(uuid, uuid)',
    'access_visible_channel_ids(uuid)', 'access_channel(uuid, uuid)', 'access_space(uuid, uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end;
$$;

-- =========================================================================
-- 2. The RLS wrappers -- same names/signatures every policy already uses,
--    now just auth.uid() applied to the single source.
-- =========================================================================

create or replace function is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select access_is_staff(auth.uid());
$$;

create or replace function is_space_owner(check_space_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_manages_space(auth.uid(), check_space_id);
$$;

create or replace function is_space_admin(check_space_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_is_space_admin(auth.uid(), check_space_id);
$$;

create or replace function is_home_space_owner(check_channel_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_manages_channel(auth.uid(), check_channel_id);
$$;

create or replace function is_channel_member(check_channel_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_is_channel_member(auth.uid(), check_channel_id);
$$;

create or replace function can_view_channel(check_channel_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_can_view_channel(auth.uid(), check_channel_id);
$$;

-- =========================================================================
-- 3. Policies that still spelled a rule out inline
-- =========================================================================

-- "Only the Administrator" rules (co-owner list, co-owner invites) --
-- previously an inline `exists (... owner_id = auth.uid())` each.
drop policy space_co_owner_invites_founder_insert on space_co_owner_invites;
create policy space_co_owner_invites_founder_insert on space_co_owner_invites
  for insert with check (is_space_admin(space_id));
drop policy space_co_owner_invites_founder_withdraw on space_co_owner_invites;
create policy space_co_owner_invites_founder_withdraw on space_co_owner_invites
  for delete using (status = 'pending' and is_space_admin(space_id));
drop policy space_co_owner_invites_select on space_co_owner_invites;
create policy space_co_owner_invites_select on space_co_owner_invites
  for select using (invitee_user_id = auth.uid() or is_space_admin(space_id) or is_staff());

drop policy space_co_owners_founder_insert on space_co_owners;
create policy space_co_owners_founder_insert on space_co_owners
  for insert with check (is_space_admin(space_id));
drop policy space_co_owners_delete on space_co_owners;
create policy space_co_owners_delete on space_co_owners
  for delete using (is_space_admin(space_id) or user_id = auth.uid() or is_staff());
drop policy space_co_owners_select on space_co_owners;
create policy space_co_owners_select on space_co_owners
  for select using (is_space_admin(space_id) or user_id = auth.uid() or is_staff());

-- Co-owners manage the Space, so they may rename it too (before: the
-- Administrator only). Who IS Administrator is guarded separately below.
drop policy spaces_owner_update on spaces;
create policy spaces_owner_update on spaces
  for update using (is_space_owner(id) or is_staff())
  with check (is_space_owner(id) or is_staff());

-- A Frame may only hold what its HOUSEHOLD can see -- not merely what the
-- person assigning it can see (see header).
drop policy frame_channels_owner_write on frame_channels;
create policy frame_channels_owner_write on frame_channels
  for all using (
    exists (
      select 1 from frames f
      where f.id = frame_channels.frame_id and is_space_owner(f.space_id)
        and access_space_can_view_channel(f.space_id, frame_channels.channel_id)
    )
  )
  with check (
    exists (
      select 1 from frames f
      where f.id = frame_channels.frame_id and is_space_owner(f.space_id)
        and access_space_can_view_channel(f.space_id, frame_channels.channel_id)
    )
  );

-- The Administrator role changes hands only through the handover paths
-- (transfer-space-ownership, handle_space_owner_removal) -- never by a
-- plain client update of owner_id, which until now let the Administrator
-- hand the Space to anyone at all, bypassing "must already be a co-owner".
create or replace function guard_space_owner_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is distinct from old.owner_id and auth.uid() is not null and not access_is_staff(auth.uid()) then
    raise exception 'Der Administrator wird nur über die Übergabe gewechselt.' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_space_owner_change on spaces;
create trigger guard_space_owner_change
  before update on spaces
  for each row execute function guard_space_owner_change();
