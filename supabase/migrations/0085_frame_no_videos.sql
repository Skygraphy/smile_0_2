-- "Keine Videos" (2026-10-18): a Frame can show only photos. video_length
-- gets a third value 'none' next to 'full' and 'photo' (migrations/0079).
alter table frames drop constraint if exists frames_video_length_check;
alter table frames add constraint frames_video_length_check check (video_length in ('full', 'photo', 'none'));
