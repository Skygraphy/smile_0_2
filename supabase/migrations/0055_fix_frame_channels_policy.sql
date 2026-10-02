-- Regression from 0047, found in the live test 2026-10-02: the Frame
-- settings screen showed "permission denied for function
-- access_space_can_view_channel" and an empty channel list.
--
-- 0047 made frame_channels_owner_write call access_space_can_view_channel
-- directly -- but the access_* functions are service_role-only on purpose
-- (they take ids, not auth.uid()). A policy runs as the calling user, so
-- every app read of frame_channels failed (the policy is FOR ALL, so it
-- applies to SELECT too). The Frame itself was unaffected: it reads via
-- get-media-batch with the service role.
--
-- Same pattern as every other RLS helper: a security definer wrapper bound
-- to auth.uid(), executable by the app, deciding the same rule.

-- "May the caller put [p_channel] on Frame [p_frame]": they manage the
-- Frame's Space, and that household can see the channel.
create or replace function frame_may_show_channel(p_frame uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from frames f
    where f.id = p_frame
      and access_manages_space(auth.uid(), f.space_id)
      and access_space_can_view_channel(f.space_id, p_channel)
  );
$$;

drop policy frame_channels_owner_write on frame_channels;
create policy frame_channels_owner_write on frame_channels
  for all using (frame_may_show_channel(frame_id, channel_id))
  with check (frame_may_show_channel(frame_id, channel_id));
