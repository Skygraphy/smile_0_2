-- A Frame locked out for good (2026-10-15, the kitchen P610): the server
-- rotated its refresh secret, the answer never reached the Frame (a WLAN
-- blip), and the old secret was dead at once -- from then on every refresh
-- failed and the Frame only showed its cache. Now the previous secret stays
-- valid until the new one has been used once: a Frame that missed the
-- answer simply asks again with the secret it has.
alter table frame_credentials add column if not exists previous_refresh_secret_hash text;
