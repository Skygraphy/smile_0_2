-- Stricter "anchored in the Space" (Ernst 2026-11-19): someone who came in
-- only through an album creator's album (Peter in Ines' "Winterurlaub")
-- does not count as part of the Space -- Ines must propose him again for
-- every further album of hers. Anchored are: the Admin and Co-Admins, those
-- allowed to create albums, and members of albums the Admin or a Co-Admin
-- made (created_by null = made before 0109, always by a manager).

create or replace function access_is_anchored(p_user uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_manages_space(p_user, p_space)
    or exists (select 1 from space_album_creators where space_id = p_space and user_id = p_user)
    or exists (
      select 1 from channel_members cm join channels c on c.id = cm.channel_id
      where cm.user_id = p_user and c.space_id = p_space and c.deleted_at is null
        and (c.created_by is null or access_manages_space(c.created_by, p_space))
    );
$$;

create or replace function album_anchored_people(p_channel uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  with sp as (select space_id from channels where id = p_channel)
  select u.user_id from (
    select s.owner_id as user_id from spaces s where s.id = (select space_id from sp)
    union select user_id from space_co_owners where space_id = (select space_id from sp)
    union select user_id from space_album_creators where space_id = (select space_id from sp)
    union select cm.user_id from channel_members cm join channels c on c.id = cm.channel_id
      where c.space_id = (select space_id from sp) and c.deleted_at is null
        and (c.created_by is null or access_manages_space(c.created_by, c.space_id))
  ) u
  where access_manages_channel(auth.uid(), p_channel);
$$;
