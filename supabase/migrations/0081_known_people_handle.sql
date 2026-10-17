-- known_people() also returns the Smile name (2026-10-17): people one
-- already knows are found by a part of their @name too, not only by the
-- exact name as strangers are (find_person_by_handle, migrations/0080).
-- Same body as migrations/0073 plus p.handle; the return type changes, so
-- drop and create.

drop function if exists public.known_people();

create function public.known_people()
returns table (user_id uuid, display_name text, avatar_path text, context text, manages_a_space boolean, handle text)
language sql stable security definer set search_path = public as $$
  with me as (select auth.uid() as id),
  via_albums as (
    select other.user_id, c.name as context
    from channel_members mine
    join channel_members other on other.channel_id = mine.channel_id and other.user_id <> mine.user_id
    join channels c on c.id = mine.channel_id and c.deleted_at is null
    where mine.user_id = (select id from me)
  ),
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
         ) as manages_a_space,
         p.handle
  from everyone e
  join profiles p on p.user_id = e.user_id
  where e.user_id <> (select id from me)
  group by p.user_id, p.display_name, p.avatar_path, p.handle
  order by p.display_name;
$$;

revoke all on function public.known_people() from public, anon;
grant execute on function public.known_people() to authenticated;
