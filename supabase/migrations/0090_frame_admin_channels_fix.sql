-- 0089's channels_frame_admin_select called access_space_can_view_channel
-- directly, which authenticated may not execute -- every channels read
-- failed. Wrapped in a security definer function like the other checks.
create or replace function frame_admin_may_see_channel(p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from frame_admins fa join frames f on f.id = fa.frame_id
    where fa.user_id = auth.uid() and access_space_can_view_channel(f.space_id, p_channel)
  );
$$;

drop policy if exists channels_frame_admin_select on channels;
create policy channels_frame_admin_select on channels
  for select using (frame_admin_may_see_channel(id));
