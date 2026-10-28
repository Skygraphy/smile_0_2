-- A Frame-Admin (0089) adds albums shared into the Frame's Space too:
-- reading which albums are shared into it (names via 0090).
create or replace function frame_admin_of_space(p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from frame_admins fa join frames f on f.id = fa.frame_id
    where fa.user_id = auth.uid() and f.space_id = p_space
  );
$$;

drop policy if exists channel_shares_frame_admin_select on channel_shares;
create policy channel_shares_frame_admin_select on channel_shares
  for select using (frame_admin_of_space(space_id));
