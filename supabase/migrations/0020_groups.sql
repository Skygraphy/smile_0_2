-- Phase 6b: Gruppen -- a personal, creator-owned distribution list of
-- people (concept doc has no equivalent; see plan under
-- C:\Users\ernst\.claude\plans\swift-riding-snail.md for the full
-- rationale) that can be granted contributor access to any number of
-- channels across any number of Spaces the creator administers. Kept in
-- sync into real channel_memberships rows by a trigger below rather than
-- taught to every existing RLS policy/read path separately -- every
-- permission check, upload flow, delete/hide rule, and Smile-Frame
-- fan-out already keys off channel_memberships, so a group-derived row
-- works everywhere for free.

create table groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (group_id, user_id)
);

create table group_channel_grants (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  channel_id uuid not null references channels(id) on delete cascade,
  granted_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (group_id, channel_id)
);

create index idx_group_members_group on group_members(group_id);
create index idx_group_channel_grants_group on group_channel_grants(group_id);
create index idx_group_channel_grants_channel on group_channel_grants(channel_id);

-- Provenance marker: null = a direct/manual membership (invite code,
-- "add existing member", channel creator auto-join, ...); set = this row
-- exists because of a group grant and is fully owned by the reconcile
-- function below (never hand-edit one, see channel_members_screen.dart).
alter table channel_memberships
  add column via_group_id uuid references groups(id) on delete set null;

-- =========================================================================
-- RLS
-- =========================================================================

alter table groups enable row level security;

create policy groups_owner_all on groups
  for all using (owner_id = auth.uid() or is_staff())
  with check (owner_id = auth.uid() or is_staff());

alter table group_members enable row level security;

create policy group_members_owner_all on group_members
  for all using (
    is_staff() or exists (select 1 from groups g where g.id = group_members.group_id and g.owner_id = auth.uid())
  )
  with check (
    is_staff() or exists (select 1 from groups g where g.id = group_members.group_id and g.owner_id = auth.uid())
  );

alter table group_channel_grants enable row level security;

-- Requires BOTH owning the group AND administering the target channel --
-- otherwise anyone could use their own group to grant themselves access
-- to a channel they don't control.
create policy group_channel_grants_owner_admin_all on group_channel_grants
  for all using (
    is_staff()
    or (
      exists (select 1 from groups g where g.id = group_channel_grants.group_id and g.owner_id = auth.uid())
      and (
        is_channel_admin(channel_id)
        or exists (select 1 from channels c where c.id = group_channel_grants.channel_id and is_space_owner(c.space_id))
      )
    )
  )
  with check (
    is_staff()
    or (
      exists (select 1 from groups g where g.id = group_channel_grants.group_id and g.owner_id = auth.uid())
      and (
        is_channel_admin(channel_id)
        or exists (select 1 from channels c where c.id = group_channel_grants.channel_id and is_space_owner(c.space_id))
      )
    )
  );

-- =========================================================================
-- Reconciliation: keeps channel_memberships in sync with group
-- membership/grants. Called from triggers on both junction tables below.
-- =========================================================================

create or replace function reconcile_channel_group_access(p_channel_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  -- Add anyone in a group granted to this channel who isn't a member yet.
  -- `on conflict do nothing` is what makes this safe to call
  -- unconditionally: a person already directly/manually in the channel is
  -- silently left untouched, never reattributed to a group.
  insert into channel_memberships (channel_id, user_id, role, via_group_id)
  select p_channel_id, gm.user_id, 'contributor', gcg.group_id
  from group_channel_grants gcg
  join group_members gm on gm.group_id = gcg.group_id
  where gcg.channel_id = p_channel_id
  on conflict (channel_id, user_id) do nothing;

  -- Remove a derived row no longer justified by ANY group grant on this
  -- channel. Checks the user's current group memberships directly rather
  -- than just the group on file in via_group_id -- correct even if the
  -- same person is independently in a second group that also grants this
  -- channel, with no need to track/re-attribute which group "wins".
  delete from channel_memberships cm
  where cm.channel_id = p_channel_id
    and cm.via_group_id is not null
    and not exists (
      select 1 from group_channel_grants gcg
      join group_members gm on gm.group_id = gcg.group_id and gm.user_id = cm.user_id
      where gcg.channel_id = p_channel_id
    );
end;
$$;

create or replace function trg_reconcile_on_group_members_change()
returns trigger
language plpgsql
security definer
as $$
declare
  ch record;
begin
  for ch in
    select channel_id from group_channel_grants
    where group_id = coalesce(new.group_id, old.group_id)
  loop
    perform reconcile_channel_group_access(ch.channel_id);
  end loop;
  return null;
end;
$$;

create trigger on_group_members_change
  after insert or delete on group_members
  for each row execute function trg_reconcile_on_group_members_change();

create or replace function trg_reconcile_on_group_channel_grants_change()
returns trigger
language plpgsql
security definer
as $$
begin
  perform reconcile_channel_group_access(coalesce(new.channel_id, old.channel_id));
  return null;
end;
$$;

create trigger on_group_channel_grants_change
  after insert or delete on group_channel_grants
  for each row execute function trg_reconcile_on_group_channel_grants_change();
