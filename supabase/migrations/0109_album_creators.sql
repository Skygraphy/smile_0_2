-- "Darf Alben anlegen" (Ernst 2026-11-19, preview "Variante B" approved):
-- the Space's Administrator / Co-Admins can let a person of the Space (in
-- one of its albums) create albums there -- without making them Co-Admin.
-- Whoever created an album that way manages THAT album (rename, picture,
-- invite, remove, delete), the Administrator and Co-Admins still manage
-- every album. Frames stay with the managers: a new album does not go onto
-- a Frame by itself, the managers are asked (notify-event album_created).
-- Taking the right away also ends managing the albums made with it; the
-- albums and their photos stay, the person stays a member.

create table space_album_creators (
  space_id uuid not null references spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  granted_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (space_id, user_id)
);

create index idx_space_album_creators_user on space_album_creators(user_id);

-- Who made an album (null for albums made before 2026-11-19).
alter table channels add column created_by uuid references auth.users(id) on delete set null;

create or replace function set_channel_created_by()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists on_channel_created_by on channels;
create trigger on_channel_created_by
  before insert on channels
  for each row execute function set_channel_created_by();

-- =========================================================================
-- The single source (0047/0048), extended
-- =========================================================================

-- In one of the Space's own albums (not trashed).
create or replace function access_is_in_space(p_user uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from channel_members cm join channels c on c.id = cm.channel_id
    where cm.user_id = p_user and c.space_id = p_space and c.deleted_at is null
  );
$$;

create or replace function access_creates_albums(p_user uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_manages_space(p_user, p_space)
    or (access_space_active(p_space)
        and exists (select 1 from space_album_creators where space_id = p_space and user_id = p_user));
$$;

-- Made this album with the right, and still has the right. Not trash-aware
-- for the album itself (like access_manages_space): the one who may
-- restore it.
create or replace function access_created_album(p_user uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from channels c
    join space_album_creators a on a.space_id = c.space_id and a.user_id = p_user
    where c.id = p_channel and c.created_by = p_user and access_space_active(c.space_id)
  );
$$;

create or replace function access_manages_channel(p_user uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_channel_active(p_channel)
    and (exists (select 1 from channels c where c.id = p_channel and access_manages_space(p_user, c.space_id))
         or access_created_album(p_user, p_channel));
$$;

create or replace function access_channel(p_user uuid, p_channel uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when c.id is null then jsonb_build_object('exists', false)
  else jsonb_build_object(
    'exists', true,
    'active', access_channel_active(c.id),
    'home_space_id', c.space_id,
    'is_staff', access_is_staff(p_user),
    'manages', access_manages_space(p_user, c.space_id) or access_created_album(p_user, c.id),
    'manages_space', access_manages_space(p_user, c.space_id),
    'is_admin', access_is_space_admin(p_user, c.space_id),
    'is_member', access_is_channel_member(p_user, c.id),
    'can_view', access_can_view_channel(p_user, c.id)
  ) end
  from (select 1) one left join channels c on c.id = p_channel;
$$;

revoke all on function access_is_in_space(uuid, uuid) from public, anon;
revoke all on function access_creates_albums(uuid, uuid) from public, anon;
revoke all on function access_created_album(uuid, uuid) from public, anon;
grant execute on function access_is_in_space(uuid, uuid) to authenticated, service_role;
grant execute on function access_creates_albums(uuid, uuid) to authenticated, service_role;
grant execute on function access_created_album(uuid, uuid) to authenticated, service_role;

-- New albums: the managers, and whoever has the right.
drop policy if exists channels_owner_insert on channels;
create policy channels_owner_insert on channels
  for insert with check (access_creates_albums(auth.uid(), space_id));

-- =========================================================================
-- The right itself: the managers give and take it, only to people of the
-- Space; the person sees their own rows.
-- =========================================================================

alter table space_album_creators enable row level security;

create policy space_album_creators_select on space_album_creators
  for select using (user_id = auth.uid() or is_space_owner(space_id) or is_staff());
create policy space_album_creators_insert on space_album_creators
  for insert with check (is_space_owner(space_id) and access_is_in_space(user_id, space_id));
create policy space_album_creators_delete on space_album_creators
  for delete using (is_space_owner(space_id) or is_staff());

-- The people of a Space (members of its albums, not its managers), each
-- with whether they may create albums -- for the managers' list.
create or replace function space_people(p_space uuid)
returns table (user_id uuid, display_name text, avatar_path text, creates_albums boolean)
language sql stable security definer set search_path = public as $$
  select p.user_id, pr.display_name, pr.avatar_path,
         exists (select 1 from space_album_creators a where a.space_id = p_space and a.user_id = p.user_id)
  from (
    select distinct cm.user_id from channel_members cm join channels c on c.id = cm.channel_id
    where c.space_id = p_space and c.deleted_at is null
  ) p
  left join profiles pr on pr.user_id = p.user_id
  where access_manages_space(auth.uid(), p_space)
    and not access_manages_space(p.user_id, p_space)
  order by pr.display_name nulls last;
$$;

revoke all on function space_people(uuid) from public, anon;
grant execute on function space_people(uuid) to authenticated;

-- The Spaces someone may create albums in without managing them (the app's
-- "Neues Album" -- spaces_select only shows managed Spaces).
create or replace function album_creator_spaces()
returns table (id uuid, name text, avatar_path text, albums int, frames int)
language sql stable security definer set search_path = public as $$
  select s.id, s.name, s.avatar_path,
         (select count(*)::int from channels c where c.space_id = s.id and c.deleted_at is null),
         (select count(*)::int from frames f where f.space_id = s.id and f.lifecycle_state = 'active')
  from space_album_creators a join spaces s on s.id = a.space_id
  where a.user_id = auth.uid() and s.deleted_at is null
    and not access_manages_space(auth.uid(), s.id)
  order by s.created_at;
$$;

revoke all on function album_creator_spaces() from public, anon;
grant execute on function album_creator_spaces() to authenticated;

-- The person hears about it (push + Verlauf, notify-event).
create or replace function handle_album_right_changed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_op = 'INSERT' then
    perform emit_event('album_right_changed', jsonb_build_object(
      'space_id', new.space_id, 'user_id', new.user_id, 'actor_id', auth.uid(), 'granted', true));
    return new;
  end if;
  if old.user_id <> auth.uid() then
    perform emit_event('album_right_changed', jsonb_build_object(
      'space_id', old.space_id, 'user_id', old.user_id, 'actor_id', auth.uid(), 'granted', false));
  end if;
  return old;
end;
$$;

drop trigger if exists on_album_right_changed on space_album_creators;
create trigger on_album_right_changed
  after insert or delete on space_album_creators
  for each row execute function handle_album_right_changed();

-- Reading the new album back in the same statement (insert ... returning,
-- the app's .insert().select()): its membership row from handle_new_channel
-- is not visible yet (the 0013/0033/0042 gotcha) -- so the creator sees it
-- by the row's own columns.
drop policy channels_select on channels;
create policy channels_select on channels
  for select using (
    (deleted_at is null and (
      is_space_owner(space_id)
      or is_channel_member(id)
      or (created_by = auth.uid() and access_creates_albums(auth.uid(), space_id))
      or exists (select 1 from channel_shares cs where cs.channel_id = channels.id and is_space_owner(cs.space_id))
    ))
    or is_staff()
  );
