-- "Bild dreht sich mit dem Frame" (2026-10-17): the Frame's picture turns
-- with the device by its motion sensor, even when the tablet's own
-- auto-rotate is off. Set from the app only (Wiedergabe), not a Frame
-- control; the Frame reads it with its settings (get-media-batch).
alter table frames add column rotate_with_device boolean not null default false;
