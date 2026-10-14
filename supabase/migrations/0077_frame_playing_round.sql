-- What a Frame plays right now beyond its settings (2026-10-14): a round
-- started on the Frame itself ("Neueste", "Lieblingsbilder") -- reported by
-- the Frame, so the app shows "zeigt gerade Lieblingsbilder" instead of the
-- album stored as current. Null: no round, its settings apply.
alter table frames add column if not exists playing_round text
  check (playing_round in ('newest', 'favorites'));
