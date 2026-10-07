-- Monitoring of live operation, stage 1 (decided 2026-10-07): an hourly
-- health check (Edge Function health-check) looks for problems nobody would
-- otherwise notice and pushes them to the operator -- Frame outages also to
-- the Frame's Space managers. Stage 2 (crash reports) lives in the apps.
--
-- ops_alert_recipients: who gets operator warnings. Deliberately NOT
-- staff_members -- that role makes RLS show a person every Space and album
-- of everyone; receiving warnings must not.
create table ops_alert_recipients (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table ops_alert_recipients enable row level security;
-- No policies: server-only.

-- One row per known problem, so a problem is announced once when it starts,
-- reminded at most daily while it lasts, and announced again when it is
-- over -- not every hour.
create table health_alerts (
  key text primary key,
  title text not null,
  body text not null,
  recipients uuid[] not null default '{}',
  data jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_notified_at timestamptz not null default now(),
  resolved_at timestamptz
);
alter table health_alerts enable row level security;
-- No policies: server-only.

select cron.schedule(
  'smile-health-check',
  '47 * * * *',
  $cron$select invoke_internal('health-check', '{}'::jsonb)$cron$
);
