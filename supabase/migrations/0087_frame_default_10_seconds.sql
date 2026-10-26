-- A new Frame shows each photo 10 seconds (decided 2026-10-26): 8 was not
-- one of the choices (5, 10, 20 seconds, 1 minute), so none showed as
-- picked. Frames that exist keep their setting.
alter table public.frames alter column slideshow_interval_seconds set default 10;
