-- Keyset-pagination indexes for get-media-batch / get-signed-media-urls.
-- Fixes the smile_0_1 prototype's fixed MAX_ITEMS=300 cap, which its own
-- comments already flagged as a "v1 cap, not enterprise scale" -- multiple
-- channels per space raise per-space media volume well beyond that.
create index idx_media_items_channel_created_id on media_items(channel_id, created_at desc, id desc);
