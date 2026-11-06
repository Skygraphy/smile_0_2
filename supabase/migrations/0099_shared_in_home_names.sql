-- Albums shared into a Space show which Space they come from (Ernst
-- 2026-11-06): "Stammtisch -- aus dem Space Davidopa". The home Space's name
-- isn't readable via RLS for the receiving side, so this hands out just the
-- name, only to who may see the share itself (the receiving Space's managers
-- and its Frame-Admins, as channel_shares_select / _frame_admin_select).
create or replace function shared_in_home_spaces(p_space uuid)
returns table (channel_id uuid, space_name text)
language sql stable security definer set search_path = public as $$
  select cs.channel_id, s.name
  from channel_shares cs
  join channels c on c.id = cs.channel_id
  join spaces s on s.id = c.space_id
  where cs.space_id = p_space
    and (is_space_owner(p_space) or frame_admin_of_space(p_space));
$$;
revoke all on function shared_in_home_spaces(uuid) from public, anon;
grant execute on function shared_in_home_spaces(uuid) to authenticated;
