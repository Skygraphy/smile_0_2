-- Like every access_* function (0047): not callable by clients with an
-- arbitrary user -- policies go through auth.uid()-bound wrappers.
create or replace function is_frame_admin(check_frame_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_is_frame_admin(auth.uid(), check_frame_id);
$$;

drop policy if exists frames_select on frames;
create policy frames_select on frames
  for select using (is_space_owner(space_id) or is_frame_admin(id) or is_staff());
drop policy if exists frames_owner_update on frames;
create policy frames_owner_update on frames
  for update using (is_space_owner(space_id) or is_frame_admin(id) or is_staff())
  with check (is_space_owner(space_id) or is_frame_admin(id) or is_staff());

revoke all on function access_is_frame_admin(uuid, uuid) from public, anon, authenticated;
revoke all on function access_manages_frame(uuid, uuid) from public, anon, authenticated;
