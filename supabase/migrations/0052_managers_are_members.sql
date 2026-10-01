-- Decision 2026-10-01 (live test, Schritt 3): whoever manages a Space --
-- its Administrator and every co-owner -- may post in all of its channels.
-- Before, only a channel's CREATOR was auto-joined (0031's
-- handle_new_channel), so a co-owner managed channels they couldn't post
-- in ("verwaltet alles, darf aber nichts posten"), and a channel a
-- co-owner created left the Administrator out.
--
-- Posting stays membership-based (channel_members) -- managers simply
-- become members automatically: when they become a co-owner, and whenever
-- a new channel is created in their Space. Anyone can still leave a
-- channel they don't want to post in. Losing co-owner status does NOT
-- remove memberships: nothing tells an automatic membership apart from a
-- deliberate one, and the Administrator can remove members at any time.

-- New channel: creator + Administrator + every co-owner.
create or replace function handle_new_channel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into channel_members (channel_id, user_id)
  select new.id, u from (
    select auth.uid() as u
    union
    select owner_id from spaces where id = new.space_id
    union
    select user_id from space_co_owners where space_id = new.space_id
  ) managers
  where u is not null
  on conflict do nothing;
  return new;
end;
$$;

-- New co-owner: member of every channel of the Space at once.
create or replace function handle_co_owner_joins_channels()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into channel_members (channel_id, user_id)
  select c.id, new.user_id from channels c where c.space_id = new.space_id
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_co_owner_joins_channels on space_co_owners;
create trigger on_co_owner_joins_channels
  after insert on space_co_owners
  for each row execute function handle_co_owner_joins_channels();

-- The rule for what exists already: every manager joins every channel of
-- the Spaces they manage.
insert into channel_members (channel_id, user_id)
select c.id, m.user_id
from channels c
join (
  select id as space_id, owner_id as user_id from spaces
  union
  select space_id, user_id from space_co_owners
) m on m.space_id = c.space_id
on conflict do nothing;
