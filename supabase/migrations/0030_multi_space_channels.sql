-- A Channel can now belong to more than one Space at once -- concrete
-- motivating scenario: divorced grandparents "Oma" and "Opa" each run
-- their own Space household but want one shared "Enkelkinder" channel
-- visible/postable-to from both, instead of duplicating uploads across
-- two separate channels. Previously `channels.space_id` was a strict
-- single not-null FK (0003); replaced here by a join table.
--
-- Groups (0020) look similar but solve a different problem -- granting a
-- *person* cross-space contributor access without ever changing which
-- Space a channel structurally belongs to/displays under. This migration
-- is what actually lets a channel live in two Spaces' "Meine Spaces"
-- lists and be administered by both spaces' owners.

-- =========================================================================
-- Schema: space_channels join table (created first, but not yet enforced
-- as the source of truth -- old policies below still read
-- channels.space_id until they're dropped in the next section).
-- =========================================================================

create table space_channels (
  space_id uuid not null references spaces(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (space_id, channel_id)
);

create index idx_space_channels_channel on space_channels(channel_id);
create index idx_space_channels_space on space_channels(space_id);

-- Backfill every existing 1:1 relationship before the old column goes away.
insert into space_channels (space_id, channel_id)
select space_id, id from channels;

-- =========================================================================
-- Drop every policy that reads channels.space_id, so the column can
-- actually be dropped below. Recreated further down against
-- space_channels instead.
-- =========================================================================

drop policy spaces_select on spaces;
drop policy channels_select on channels;
drop policy channels_owner_insert on channels;
drop policy channels_admin_update on channels;
drop policy channels_owner_delete on channels;
drop policy channel_memberships_select on channel_memberships;
drop policy channel_memberships_admin_write on channel_memberships;
drop policy group_channel_grants_owner_admin_all on group_channel_grants;
drop policy channel_join_requests_select on channel_join_requests;

drop index if exists idx_channels_space;
alter table channels drop column space_id;

-- =========================================================================
-- RLS helper: consolidates the "is caller an owner of ANY space this
-- channel is linked to" check, replacing the five inline
-- `exists (select 1 from channels c where c.id = X and
-- is_space_owner(c.space_id))` occurrences the dropped policies used.
-- =========================================================================

create or replace function is_space_owner_of_channel(check_channel_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from space_channels sc
    where sc.channel_id = check_channel_id and is_space_owner(sc.space_id)
  );
$$;

-- =========================================================================
-- channels: policies rewritten for space_id no longer being a column.
-- Insert is dropped entirely (not recreated) -- creation now exclusively
-- goes through the create_channel() function below, which is security
-- definer and checks authorization itself (a raw client insert has no
-- space to check against any more, since the row itself carries no
-- space_id).
-- =========================================================================

create policy channels_select on channels
  for select using (
    is_space_owner_of_channel(id) or is_channel_member(id) or is_channel_admin(id) or is_staff()
  );

create policy channels_admin_update on channels
  for update using (is_space_owner_of_channel(id) or is_channel_admin(id) or is_staff())
  with check (is_space_owner_of_channel(id) or is_channel_admin(id) or is_staff());

-- Hard-delete is now staff-only -- routine removal is "unlink my Space"
-- (space_channels_owner_delete below), which cleanly deletes the channel
-- itself once no Space references it any more.
create policy channels_owner_delete on channels
  for delete using (is_staff());

-- =========================================================================
-- spaces_select: the "am I a member of a channel in this space" branch
-- now joins through space_channels instead of channels.space_id.
-- =========================================================================

create policy spaces_select on spaces
  for select using (
    is_space_owner(id)
    or is_staff()
    or exists (
      select 1 from space_channels sc
      join channel_memberships cm on cm.channel_id = sc.channel_id
      where sc.space_id = spaces.id and cm.user_id = auth.uid()
    )
  );

-- =========================================================================
-- channel_memberships: replace the inline "space owner of this
-- membership's channel" exists(...) with the new helper.
-- =========================================================================

create policy channel_memberships_select on channel_memberships
  for select using (
    is_channel_member(channel_id)
    or is_channel_admin(channel_id)
    or is_own_device(device_id)
    or is_staff()
    or is_space_owner_of_channel(channel_id)
  );

create policy channel_memberships_admin_write on channel_memberships
  for all using (
    is_channel_admin(channel_id) or is_staff() or is_space_owner_of_channel(channel_id)
  )
  with check (
    is_channel_admin(channel_id) or is_staff() or is_space_owner_of_channel(channel_id)
  );

-- =========================================================================
-- group_channel_grants (0020): same substitution.
-- =========================================================================

create policy group_channel_grants_owner_admin_all on group_channel_grants
  for all using (
    is_staff()
    or (
      exists (select 1 from groups g where g.id = group_channel_grants.group_id and g.owner_id = auth.uid())
      and (is_channel_admin(channel_id) or is_space_owner_of_channel(channel_id))
    )
  )
  with check (
    is_staff()
    or (
      exists (select 1 from groups g where g.id = group_channel_grants.group_id and g.owner_id = auth.uid())
      and (is_channel_admin(channel_id) or is_space_owner_of_channel(channel_id))
    )
  );

-- =========================================================================
-- channel_join_requests (0025): same substitution. Any linked space's
-- owner may see/decide requests -- consistent with both spaces having
-- full symmetric admin power over a shared channel (see create_channel
-- and the sharing mechanism below).
-- =========================================================================

create policy channel_join_requests_select on channel_join_requests
  for select using (
    user_id = auth.uid()
    or is_channel_admin(channel_id)
    or is_space_owner_of_channel(channel_id)
    or is_staff()
  );

-- =========================================================================
-- Unlink/delete semantics
-- =========================================================================
-- Deleting a channel outright used to be a plain Space-Owner action.
-- That can no longer be unilateral once a second Space might depend on
-- the same channel -- Oma must not be able to destroy "Enkelkinder" for
-- Opa just by deleting it from her own Space. The new model: a Space
-- Owner may always remove their OWN space_channels link; removing the
-- last remaining link is what actually deletes the channel, via the
-- trigger below -- reproducing today's "deleting a Space deletes its
-- exclusively-owned channels" behavior for the common single-space case,
-- without ever letting one Space destroy another's shared channel.

alter table space_channels enable row level security;

create policy space_channels_select on space_channels
  for select using (
    is_space_owner(space_id) or is_channel_member(channel_id) or is_channel_admin(channel_id) or is_staff()
  );

-- A Space Owner may link their own Space to a channel they already
-- administer (the actual "share with a second space" write goes through
-- claim-channel-space-share's service-role redemption instead, but this
-- policy also covers the equivalent staff/admin tooling path).
create policy space_channels_insert on space_channels
  for insert with check (
    is_staff() or (is_space_owner(space_id) and is_channel_admin(channel_id))
  );

create policy space_channels_owner_delete on space_channels
  for delete using (is_space_owner(space_id) or is_staff());

-- Locks the parent channels row before counting so that two Space Owners
-- concurrently removing their (each) last link to the same channel can't
-- both observe "still has another link" and leave a permanently
-- orphaned, invisible channels row behind (classic check-then-act race
-- across concurrent transactions).
create or replace function delete_channel_if_orphaned()
returns trigger
language plpgsql
security definer
as $$
declare
  remaining int;
begin
  perform 1 from channels where id = old.channel_id for update;
  select count(*) into remaining from space_channels where channel_id = old.channel_id;
  if remaining = 0 then
    delete from channels where id = old.channel_id;
  end if;
  return old;
end;
$$;

create trigger on_space_channels_unlink
  after delete on space_channels
  for each row execute function delete_channel_if_orphaned();

-- =========================================================================
-- Channel creation: security definer function replacing the old direct
-- client insert (which relied on channels.space_id existing as a
-- column to check against). Mirrors 0020's reconcile-function pattern.
-- The existing on_channel_created trigger (0016) still fires on the
-- `insert into channels` below and auto-joins the caller as
-- channel_admin, unchanged.
-- =========================================================================

create or replace function create_channel(p_space_id uuid, p_name text)
returns channels
language plpgsql
security definer
as $$
declare
  new_channel channels;
begin
  if not (is_space_owner(p_space_id) or is_staff()) then
    raise exception 'not_space_owner' using errcode = '42501';
  end if;

  insert into channels (name) values (p_name) returning * into new_channel;
  insert into space_channels (space_id, channel_id) values (p_space_id, new_channel.id);

  return new_channel;
end;
$$;

-- =========================================================================
-- Sharing an existing channel with a second Space: reuses the
-- pairing_codes mechanism (same reasoning as channel_invite, 0009 --
-- channels_select never lets a non-member/non-owner discover a channel
-- exists, so a code is the only legitimate way to hand someone a
-- channel_id to act on). Generation is a direct client insert (mirrors
-- channel_invite's pairing_codes_channel_invite_member_insert);
-- redemption goes through a new service-role Edge Function
-- (claim-channel-space-share) since it must pick which of the redeemer's
-- OWN spaces to link and atomically bump use_count.
-- =========================================================================

-- Drops the original unnamed check constraint by looking up its actual
-- (Postgres-generated) name rather than guessing it, then replaces it
-- with one that also allows the new code_type.
do $$
declare
  con_name text;
begin
  select conname into con_name
  from pg_constraint
  where conrelid = 'pairing_codes'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%device_provisioning%channel_invite%'
    and pg_get_constraintdef(oid) not like '%channel_id%';
  if con_name is not null then
    execute format('alter table pairing_codes drop constraint %I', con_name);
  end if;
end $$;

alter table pairing_codes add constraint pairing_codes_code_type_check
  check (code_type in ('device_provisioning', 'channel_invite', 'channel_space_share'));

-- Deliberately not channel-admin-only: a Space Owner already has full
-- admin-equivalent power over a channel their space is linked to
-- (channel_memberships_admin_write above), so gating generation to
-- "channel_admin only" would just be a bypassable speed bump -- they
-- could self-promote via that same policy first anyway.
create policy pairing_codes_channel_space_share_insert on pairing_codes
  for insert with check (
    code_type = 'channel_space_share' and (is_channel_admin(channel_id) or is_space_owner_of_channel(channel_id))
  );

create policy pairing_codes_channel_space_share_select on pairing_codes
  for select using (
    code_type = 'channel_space_share' and (is_channel_admin(channel_id) or is_space_owner_of_channel(channel_id))
  );
