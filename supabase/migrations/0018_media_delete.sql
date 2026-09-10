-- Two-tier delete (see delete-media Edge Function):
--   - "for everyone": soft-delete via deleted_at. Kept as a row (not a hard
--     delete) so a bulk multi-select mistake isn't instantly unrecoverable
--     -- actual storage/row purging is a later, separate cleanup concern.
--     Every read path (get-signed-media-urls, get-media-batch) excludes
--     deleted_at is not null rows, so this disappears from the sender's
--     feed, every other member's feed, and every Smile-Frame's cache
--     (frames already evict anything no longer returned by get-media-batch
--     via their existing sync diff).
--   - "for me": a personal hide, scoped to just the user who deleted it --
--     everyone else (and every frame) keeps seeing the photo normally.
alter table media_items add column deleted_at timestamptz;

create table media_item_hides (
  media_item_id uuid not null references media_items(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (media_item_id, user_id)
);

alter table media_item_hides enable row level security;

-- Writes only ever go through delete-media (service role) after its own
-- sender-or-admin-or-staff check, same pattern as every other mutation in
-- this schema -- so the only client-facing policy needed here is read
-- access to your own hide list.
create policy media_item_hides_select on media_item_hides
  for select using (user_id = auth.uid());
