-- Only `channels, channel_members, channel_shares, media_items,
-- media_recipients, frames` were realtime-enabled (0031_architecture_reset.sql).
-- Every other smile-app screen besides channel_feed_screen.dart only ever
-- loaded once + manual pull-to-refresh, with no way to notice a change
-- made from another device -- the exact class of confusion behind several
-- bugs found during manual testing (see project_smile-full-walkthrough-sept27
-- memory). Adding these six tables lets the client subscribe to them the
-- same way media_items already is.
alter publication supabase_realtime add table
  spaces, frame_channels, channel_membership_requests, channel_share_requests,
  space_co_owners, space_co_owner_invites;
