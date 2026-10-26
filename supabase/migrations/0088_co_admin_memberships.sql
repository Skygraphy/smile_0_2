-- Decision 2026-10-26 (Ernst, test suite chapter 9): whoever stops being a
-- Co-Admin leaves the albums they were in ONLY because of that role --
-- not the ones they were invited to or have sent photos/videos to.
-- Before (0052) every membership stayed: after helping out briefly, one
-- was still in all albums of that Space, with posting rights.
--
-- channel_members remembers how a membership came about: via_co_admin is
-- true when the Co-Admin role put the person there (0052's triggers). Any
-- deliberate way in (an accepted invite or request, a scanned code) makes
-- it false. Memberships that exist already can't be told apart any more:
-- they count as deliberate (default false), so nothing changes for them.

alter table channel_members add column via_co_admin boolean not null default false;

-- New channel: creator + Administrator deliberately, every other co-owner
-- through the role.
create or replace function handle_new_channel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into channel_members (channel_id, user_id, via_co_admin)
  select new.id, m.u, m.via_role from (
    select auth.uid() as u, false as via_role
    union
    select owner_id, false from spaces where id = new.space_id
    union
    select user_id, true from space_co_owners where space_id = new.space_id
  ) m
  where m.u is not null
  -- The same person twice (e.g. a co-owner creating it): deliberate wins.
  order by m.via_role
  on conflict do nothing;
  return new;
end;
$$;

-- New co-owner: member of every channel of the Space at once, through the role.
create or replace function handle_co_owner_joins_channels()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into channel_members (channel_id, user_id, via_co_admin)
  select c.id, new.user_id, true from channels c where c.space_id = new.space_id
  on conflict do nothing;
  return new;
end;
$$;

-- Saying yes to an album (invite or request accepted, or a scanned code,
-- which goes through the same request row): deliberate from now on.
create or replace function handle_channel_membership_request_decided()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted' and old.status = 'pending' then
    insert into channel_members (channel_id, user_id, via_co_admin) values (new.channel_id, new.user_id, false)
    on conflict (channel_id, user_id) do update set via_co_admin = false;
  end if;
  return new;
end;
$$;

-- No longer a co-owner: leave the albums that came only with the role and
-- that one never sent anything to. Not on a hand-over to them: the new
-- Administrator's co-owner row is removed after they became the owner.
create or replace function handle_co_owner_leaves_channels()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from spaces where id = old.space_id and owner_id = old.user_id) then
    return old;
  end if;
  delete from channel_members m
  using channels c
  where m.channel_id = c.id
    and c.space_id = old.space_id
    and m.user_id = old.user_id
    and m.via_co_admin
    and not exists (select 1 from media_items i where i.channel_id = m.channel_id and i.sender_id = old.user_id);
  return old;
end;
$$;

drop trigger if exists on_co_owner_leaves_channels on space_co_owners;
create trigger on_co_owner_leaves_channels
  after delete on space_co_owners
  for each row execute function handle_co_owner_leaves_channels();
