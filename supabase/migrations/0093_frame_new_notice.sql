-- New photos on the Frame get noticed (2026-10-28, Ernst): a chime when
-- something new arrives (Ton C, tools/sounds/make3.js), repeated hourly
-- at most three times until someone taps, and a glowing hint that stays
-- until someone taps -- even on level 1. Each can be switched off by
-- whoever manages the Frame.
alter table frames add column if not exists new_sound boolean not null default true;
alter table frames add column if not exists new_sound_reminder boolean not null default true;
alter table frames add column if not exists new_hint boolean not null default true;
