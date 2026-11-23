-- The kitchen Frame unpaired itself again (2026-11-23), although 0078 keeps
-- the previous refresh secret valid. Cause: the push-triggered background
-- sync runs in its own isolate, so it and the slideshow's sync can refresh
-- at the same moment with the same secret. Both got a new secret (the
-- second via the 0078 fallback) -- and the Frame kept the first one, which
-- the server no longer knew. Now every secret handed out since the Frame
-- last proved it has the current one stays valid (at most 5).
alter table frame_credentials
  add column if not exists recent_refresh_secret_hashes text[] not null default '{}';
