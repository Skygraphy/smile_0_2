-- Course correction, found during manual testing: 0037_space_co_owners.sql
-- let the founder grant co-owner status directly, with no say from the
-- recipient at all -- inconsistent with every other connection this app
-- ever creates (channel membership, channel sharing), which are always
-- "one side proposes, the other decides" (see migrations/0031_architecture_reset.sql's
-- header comment). Taking on real administrative power over someone
-- else's household Space is not something to have thrust on you, unlike
-- WhatsApp's admin-promotes-an-existing-member pattern this was originally
-- modeled on -- there, the promoted person already opted into being in
-- that group; here, becoming a co-owner is often the *first* relationship
-- to that Space at all.
create table space_co_owner_invites (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  invitee_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz
);

create index idx_space_co_owner_invites_invitee on space_co_owner_invites(invitee_user_id);
-- Only one open invite per (space, person) at a time -- accepted/declined
-- history is kept, not overwritten, same convention as every other
-- request table in this schema.
create unique index uq_space_co_owner_invites_pending
  on space_co_owner_invites(space_id, invitee_user_id) where status = 'pending';

alter table space_co_owner_invites enable row level security;

create policy space_co_owner_invites_select on space_co_owner_invites
  for select using (
    invitee_user_id = auth.uid()
    or exists (select 1 from spaces s where s.id = space_id and s.owner_id = auth.uid())
    or is_staff()
  );

-- Only the founder may invite -- not a co-owner (same reasoning as
-- space_co_owners_founder_insert in 0037: only the founder controls who
-- else ever gets considered for this role at all).
create policy space_co_owner_invites_founder_insert on space_co_owner_invites
  for insert with check (
    exists (select 1 from spaces s where s.id = space_id and s.owner_id = auth.uid())
  );

-- Only the invitee decides -- never the founder, same as every other
-- invite's accept/decline in this app.
create policy space_co_owner_invites_invitee_decide on space_co_owner_invites
  for update using (invitee_user_id = auth.uid() and status = 'pending')
  with check (invitee_user_id = auth.uid());

-- The founder may withdraw a not-yet-answered invite (e.g. wrong person).
create policy space_co_owner_invites_founder_withdraw on space_co_owner_invites
  for delete using (
    status = 'pending' and exists (select 1 from spaces s where s.id = space_id and s.owner_id = auth.uid())
  );

-- Materializes an accepted invite into the real space_co_owners row --
-- mirrors handle_channel_membership_request_decided/
-- handle_channel_share_request_decided's exact shape (0031_architecture_reset.sql).
create or replace function handle_space_co_owner_invite_decided()
returns trigger language plpgsql security definer as $$
begin
  if new.status = 'accepted' and old.status = 'pending' then
    insert into space_co_owners (space_id, user_id) values (new.space_id, new.invitee_user_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger on_space_co_owner_invite_decided
  after update on space_co_owner_invites
  for each row when (new.status is distinct from old.status)
  execute function handle_space_co_owner_invite_decided();
