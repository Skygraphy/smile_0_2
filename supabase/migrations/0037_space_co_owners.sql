-- Co-owners: a Space still has exactly one founder (`owner_id`, unchanged),
-- but the founder may now name additional people who get the exact same
-- day-to-day SCO power (invite/share/manage Frames, decide requests) --
-- discussed after the manual walkthrough surfaced a real gap: a Space
-- representing a whole household (e.g. a married couple) had only ONE
-- person who could ever manage anything, with no path to fix that if the
-- founder became unreachable. Deliberately NOT a flat list of equal
-- owners: only the founder may add/remove co-owners, so there's always
-- exactly one unambiguous authority over *who else* has access, even
-- though co-owners are otherwise fully equal in what they can *do*.
create table space_co_owners (
  space_id uuid not null references spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create index idx_space_co_owners_user on space_co_owners(user_id);

alter table space_co_owners enable row level security;

create policy space_co_owners_select on space_co_owners
  for select using (
    exists (select 1 from spaces s where s.id = space_id and s.owner_id = auth.uid())
    or user_id = auth.uid()
    or is_staff()
  );

-- Only the founder may grant co-owner status -- deliberately NOT
-- is_space_owner() (which includes co-owners below): a co-owner must never
-- be able to promote anyone else, only the founder controls this list.
create policy space_co_owners_founder_insert on space_co_owners
  for insert with check (
    exists (select 1 from spaces s where s.id = space_id and s.owner_id = auth.uid())
  );

-- The founder can revoke anyone; a co-owner may also remove themselves
-- (step down), same as leaving a channel is self-service elsewhere.
create policy space_co_owners_delete on space_co_owners
  for delete using (
    exists (select 1 from spaces s where s.id = space_id and s.owner_id = auth.uid())
    or user_id = auth.uid()
    or is_staff()
  );

-- Both helpers now recognize a co-owner as equivalent to the founder for
-- every permission they gate (channel/frame management, request
-- decisions, media deletion -- see every policy referencing these two
-- functions across this file and 0031_architecture_reset.sql). This is
-- the ONLY place that needs to change for co-owners to get full SCO power
-- everywhere -- but every service-role Edge Function that re-implements
-- this check itself (bypassing RLS) also had to be updated separately,
-- see _shared/space-access.ts.
create or replace function is_space_owner(check_space_id uuid)
returns boolean language sql security definer stable as $$
  select exists (select 1 from spaces where id = check_space_id and owner_id = auth.uid())
    or exists (select 1 from space_co_owners where space_id = check_space_id and user_id = auth.uid());
$$;

create or replace function is_home_space_owner(check_channel_id uuid)
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from channels c join spaces s on s.id = c.space_id
    where c.id = check_channel_id and (
      s.owner_id = auth.uid()
      or exists (select 1 from space_co_owners sco where sco.space_id = s.id and sco.user_id = auth.uid())
    )
  );
$$;

-- A co-owner needs to actually see the Space itself (spaces_screen.dart's
-- "Meine Spaces" query) to manage anything in it -- previously only the
-- founder or staff could even SELECT the row.
drop policy spaces_select on spaces;
create policy spaces_select on spaces
  for select using (is_space_owner(id) or is_staff());

-- Mirrors WhatsApp's own group-admin-leaves behavior: if a Space's founder
-- account is deleted and a co-owner exists, the longest-standing co-owner
-- automatically becomes the new founder instead of the Space being
-- orphaned. `spaces.owner_id`'s `on delete restrict` (0031_architecture_reset.sql)
-- still applies as the fallback: if there's no co-owner to hand off to,
-- this trigger does nothing and the deletion is correctly blocked, exactly
-- as before -- that's now a deliberate consequence of the founder never
-- having named a co-owner, not an unavoidable architectural gap.
create or replace function handle_space_owner_removal()
returns trigger language plpgsql security definer as $$
declare
  space_record record;
  successor_id uuid;
begin
  for space_record in select id from spaces where owner_id = old.id loop
    select user_id into successor_id
      from space_co_owners
      where space_id = space_record.id
      order by created_at asc
      limit 1;
    if successor_id is not null then
      update spaces set owner_id = successor_id where id = space_record.id;
      delete from space_co_owners where space_id = space_record.id and user_id = successor_id;
    end if;
  end loop;
  return old;
end;
$$;

create trigger on_auth_user_deleted_handover_spaces
  before delete on auth.users
  for each row execute function handle_space_owner_removal();
