-- Per-Frame video sound (UI redesign stage 5, decided 2026-10-05):
-- Frames played videos with sound unconditionally; a kitchen Frame may
-- want that, a hotel lobby usually not. Default true keeps today's
-- behavior for every existing Frame.
--
-- No policy or trigger change needed: frames_update already lets the
-- Space's managers change the row, and the existing sync trigger on
-- frames (0050/0053) pushes the change to the Frame itself, which
-- re-reads its settings via get-media-batch.
alter table frames add column video_sound boolean not null default true;
