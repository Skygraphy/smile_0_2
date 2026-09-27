-- Found during the 2026-09-27 walkthrough (Schritt 13a): Ernst revoked
-- Bergoma's view-only share of Roman's "Renovierung" -- but his Frame
-- "Küche" (in Bergoma) kept Renovierung assigned (frame_channels) and kept
-- showing it. A Space losing access to a channel must also take that
-- channel off every Frame of that Space, or the Frame keeps displaying
-- content the Space may no longer see at all -- a privacy leak, not just a
-- stale UI.
--
-- Only the share-revoke path can cause this: a Frame only ever gets a
-- channel its own Space can see (home Space or a share), and a home Space
-- never loses its own channel short of deleting it (which cascades anyway).
create or replace function handle_channel_share_removed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Photos first: media_recipients isn't keyed to frame_channels, so it
  -- wouldn't go away on its own and get-media-batch would keep serving it.
  delete from media_recipients r
    using frames f
    where r.frame_id = f.id and f.space_id = old.space_id and r.channel_id = old.channel_id;
  delete from frame_channels fc
    using frames f
    where fc.frame_id = f.id and f.space_id = old.space_id and fc.channel_id = old.channel_id;
  return old;
end;
$$;

drop trigger if exists on_channel_share_removed on channel_shares;
create trigger on_channel_share_removed
  after delete on channel_shares
  for each row execute function handle_channel_share_removed();

-- Clean up the one leftover from before this fix (Küche -> Renovierung):
-- any frame assignment whose channel the Frame's Space can no longer see.
delete from media_recipients r
  using frames f, channels c
  where r.frame_id = f.id and c.id = r.channel_id
    and c.space_id <> f.space_id
    and not exists (select 1 from channel_shares cs where cs.channel_id = c.id and cs.space_id = f.space_id);
delete from frame_channels fc
  using frames f, channels c
  where fc.frame_id = f.id and c.id = fc.channel_id
    and c.space_id <> f.space_id
    and not exists (select 1 from channel_shares cs where cs.channel_id = c.id and cs.space_id = f.space_id);
