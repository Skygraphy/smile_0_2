-- Ton for all videos from the Frame itself (Ernst 2026-11-19): the big
-- sound button asks "only this video / all videos" when the Frame's
-- controls allow it (controls.sound_all, from level 3 "Einfach"). "All"
-- saves frames.video_sound, as the app's Wiedergabe setting does.

update frames
set controls = controls || jsonb_build_object(
  'sound_all',
  case
    when control_level is not null then control_level >= 3
    else coalesce((controls->>'newest')::boolean, false)
  end)
where controls is not null and not (controls ? 'sound_all');

-- New Frames start on level 3: sound for all videos allowed.
alter table frames alter column controls set default
  '{"back": true, "next": true, "album": false, "pause": true, "newest": true, "captions": false, "duration": false, "favorite": true, "overview": false, "playback": false, "favorites": true, "easy_stop": true, "sound_all": true}'::jsonb;
