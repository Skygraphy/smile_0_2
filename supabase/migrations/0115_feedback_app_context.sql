-- "Screenshot melden" (2026-11-21): where in the app a report was made and
-- the app's last technical errors -- for the Verwaltung only, never shown
-- to the person. {screen?: text, errors: [{at, text}]}, cleaned by the
-- Edge Function `feedback`.
alter table feedback_reports add column app_context jsonb;
