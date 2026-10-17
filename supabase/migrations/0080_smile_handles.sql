-- Smile names (decided 2026-10-17, part 3 of "Einladen ohne E-Mail"):
-- every person may pick a unique name like @ernst.schiener. Others find
-- them only by typing it exactly -- no browsing, no partial matches, so a
-- stranger can't list anyone (the same reason known_people() has no
-- search over all users). The personal card shows it as a QR code and as
-- the link smileapp.app/@name.
--
-- Stored lowercase, without the "@". 3-24 characters: letters, digits,
-- "." and "_"; starts with a letter or digit, doesn't end with ".", no
-- "..". A few names are kept back so nobody poses as Smile itself.

alter table profiles add column handle text;

alter table profiles add constraint profiles_handle_format check (
  handle is null or (
    handle ~ '^[a-z0-9][a-z0-9._]{1,22}[a-z0-9_]$'
    and position('..' in handle) = 0
    and handle not in ('smile', 'smileapp', 'admin', 'administrator', 'support', 'help', 'hilfe',
                       'team', 'official', 'offiziell', 'info', 'frame', 'smileframe', 'noreply', 'root')
  )
);

create unique index profiles_handle_unique on profiles(handle) where handle is not null;

-- '@Ernst.Schiener ' -> 'ernst.schiener'.
create or replace function public.normalize_handle(raw text)
returns text language sql immutable as $$
  select lower(regexp_replace(trim(coalesce(raw, '')), '^@', ''));
$$;

-- Exactly one person or none. Not the caller (they know their own name).
-- manages_a_space as in known_people(): only they can take an album share.
create or replace function public.find_person_by_handle(raw text)
returns table (user_id uuid, display_name text, avatar_path text, handle text, manages_a_space boolean)
language sql stable security definer set search_path = public as $$
  select p.user_id, p.display_name, p.avatar_path, p.handle,
         exists (
           select 1 from spaces s where s.owner_id = p.user_id and s.deleted_at is null
           union all
           select 1 from space_co_owners co join spaces s on s.id = co.space_id and s.deleted_at is null
           where co.user_id = p.user_id
         ) as manages_a_space
  from profiles p
  where p.handle is not null
    and p.handle = public.normalize_handle(raw)
    and p.user_id <> auth.uid();
$$;

revoke all on function public.find_person_by_handle(text) from public, anon;
grant execute on function public.find_person_by_handle(text) to authenticated;

-- While typing a new name: free (and valid)? The own current name counts
-- as free.
create or replace function public.handle_available(raw text)
returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from profiles p
    where p.handle = public.normalize_handle(raw) and p.user_id <> auth.uid()
  );
$$;

revoke all on function public.handle_available(text) from public, anon;
grant execute on function public.handle_available(text) to authenticated;

-- The albums the caller may invite someone into (they manage its Space),
-- for "In ein Album einladen" from a person's card.
create or replace function public.albums_i_can_invite_to()
returns table (channel_id uuid, channel_name text, space_name text)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, s.name
  from channels c
  join spaces s on s.id = c.space_id and s.deleted_at is null
  where c.deleted_at is null and is_space_owner(c.space_id)
  order by c.name;
$$;

revoke all on function public.albums_i_can_invite_to() from public, anon;
grant execute on function public.albums_i_can_invite_to() to authenticated;
