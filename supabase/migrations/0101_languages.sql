-- Mehrsprachigkeit (Ernst 2026-11-10). The language a person's app shows
-- (the one chosen, or the phone's) -- the server writes their notifications
-- in it; null for apps from before: German.
alter table profiles add column if not exists language text;

-- A Frame's own language, set in the app ("Sprache am Frame"); null: like
-- the tablet.
alter table frames add column if not exists language text;
