-- Easy Stopping is part of every control level (Ernst 2026-10-28: even
-- Oma manages it on level 1) -- one of the level's switches in controls,
-- the easy_stop column (0094) kept in step for the Frame.
alter table frames alter column controls set default
  '{"back": true, "next": true, "album": false, "pause": true, "newest": true, "captions": false, "duration": false, "favorite": true, "overview": false, "playback": false, "favorites": true, "easy_stop": true}'::jsonb;
update frames set controls = coalesce(controls, '{}'::jsonb) || jsonb_build_object('easy_stop', easy_stop);
