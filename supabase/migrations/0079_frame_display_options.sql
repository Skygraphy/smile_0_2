-- Three more playback settings (decided with the user 2026-10-16):
--   video_length  'full' = a video plays to its end; 'photo' = only as long
--                 as a photo is shown (slideshow_interval_seconds)
--   fill_mode     'fit' = always the whole photo; 'auto' = fills the screen
--                 when at most ~15% would be cut off, else the whole photo on
--                 a blurred copy of itself; 'fill' = always fills
--   slow_zoom     every photo slowly grows a little (on by default)
alter table frames
  add column if not exists video_length text not null default 'full' check (video_length in ('full', 'photo')),
  add column if not exists fill_mode text not null default 'auto' check (fill_mode in ('fit', 'auto', 'fill')),
  add column if not exists slow_zoom boolean not null default true;
