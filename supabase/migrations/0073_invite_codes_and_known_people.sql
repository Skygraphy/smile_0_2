-- Inviting by name and by QR code instead of only by email (decided
-- 2026-10-11, like WhatsApp):
--
-- 1. invite_codes: a short code (shown as a QR code or sent as text) that
--    lets someone join an album, see it with their Space, or become a
--    Co-Admin. Only Edge Functions touch it (create-invite-code,
--    redeem-invite-code) -- RLS on, no policies. Redeeming maps onto the
--    existing request tables, so accepting, notifications and pushes stay
--    exactly as they are:
--      scanned (QR, in person)  -> an invite that is accepted at once
--      typed (from a message)   -> a request the admin still decides
--    A Co-Admin code works by QR only (no request direction for that, and
--    a forwarded message must never be enough for that role).
--
-- 2. known_people(): the people the caller already shares an album or a
--    Space with -- the "per Name" list. Deliberately no search over all
--    users: names aren't unique, and strangers mustn't find anyone.

create table invite_codes (
  id uuid primary key default gen_random_uuid(),
  -- Six characters without look-alikes (no 0/O, 1/I/L); shown as K7P-2QX.
  code text not null unique check (code ~ '^[A-HJ-KM-NP-Z2-9]{6}$'),
  kind text not null check (kind in ('album_member', 'album_share', 'space_co_owner')),
  -- The album (album_*) or the Space (space_co_owner).
  target_id uuid not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  revoked_at timestamptz
);

create index idx_invite_codes_target on invite_codes(kind, target_id, created_by);

alter table invite_codes enable row level security;

-- Codes of a deleted album/Space go with it.
create or replace function delete_invite_codes_of_target()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from invite_codes where target_id = old.id;
  return old;
end;
$$;

create trigger on_channel_deleted_invite_codes after delete on channels
  for each row execute function delete_invite_codes_of_target();
create trigger on_space_deleted_invite_codes after delete on spaces
  for each row execute function delete_invite_codes_of_target();

create or replace function public.known_people()
returns table (user_id uuid, display_name text, avatar_path text, context text, manages_a_space boolean)
language sql stable security definer set search_path = public as $$
  with me as (select auth.uid() as id),
  -- Albums I'm in, and the people in them.
  via_albums as (
    select other.user_id, c.name as context
    from channel_members mine
    join channel_members other on other.channel_id = mine.channel_id and other.user_id <> mine.user_id
    join channels c on c.id = mine.channel_id and c.deleted_at is null
    where mine.user_id = (select id from me)
  ),
  -- Spaces I manage or co-manage, and the people managing them with me.
  my_spaces as (
    select s.id from spaces s where s.owner_id = (select id from me) and s.deleted_at is null
    union
    select co.space_id from space_co_owners co join spaces s on s.id = co.space_id and s.deleted_at is null
    where co.user_id = (select id from me)
  ),
  via_spaces as (
    select s.owner_id as user_id, s.name as context from spaces s where s.id in (select id from my_spaces)
    union all
    select co.user_id, s.name from space_co_owners co join spaces s on s.id = co.space_id
    where co.space_id in (select id from my_spaces)
  ),
  everyone as (
    select * from via_albums
    union all
    select * from via_spaces
  )
  select p.user_id, p.display_name, p.avatar_path, min(e.context) as context,
         exists (
           select 1 from spaces s where s.owner_id = p.user_id and s.deleted_at is null
           union all
           select 1 from space_co_owners co join spaces s on s.id = co.space_id and s.deleted_at is null
           where co.user_id = p.user_id
         ) as manages_a_space
  from everyone e
  join profiles p on p.user_id = e.user_id
  where e.user_id <> (select id from me)
  group by p.user_id, p.display_name, p.avatar_path
  order by p.display_name;
$$;

revoke all on function public.known_people() from public, anon;
grant execute on function public.known_people() to authenticated;
