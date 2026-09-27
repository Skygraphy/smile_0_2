-- Decision 2026-09-27 (walkthrough Schritt 13b): a co-owner must not be
-- able to remove the Space's Administrator (spaces.owner_id) from one of
-- that Space's channels. Consistent with 0037's rule that co-owners never
-- get a say over the Administrator (only the Administrator manages the
-- co-owner list) -- co-owners are equal in what they can DO, not in who
-- they can push out.
--
-- A trigger rather than an RLS change: channel_members_owner_write is a
-- `for all` policy shared by insert/update/delete, and "this particular
-- target row is the Administrator" is easiest to state directly here.
-- Allowed: the Administrator removing themselves, service-role writes
-- (auth.uid() is null), and cascades from deleting the channel/Space
-- itself (the channel row is already gone by the time the cascade reaches
-- channel_members, so the lookup below finds nothing).
create or replace function guard_administrator_channel_membership()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and old.user_id <> auth.uid()
     and exists (
       select 1 from channels c join spaces s on s.id = c.space_id
       where c.id = old.channel_id and s.owner_id = old.user_id
     )
  then
    raise exception 'Der Administrator kann nicht aus dem Channel entfernt werden.'
      using errcode = '42501';
  end if;
  return old;
end;
$$;

drop trigger if exists guard_administrator_channel_membership on channel_members;
create trigger guard_administrator_channel_membership
  before delete on channel_members
  for each row execute function guard_administrator_channel_membership();
