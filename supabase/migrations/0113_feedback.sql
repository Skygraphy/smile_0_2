-- Hilfe & Feedback (2026-11-20): anyone can send a problem, an idea or a
-- question from Einstellungen; it goes to the operator (ops_alert_recipients,
-- migrations/0065 -- today only Ernst) as a push and into a list only they
-- see. The answer goes out by e-mail, outside the app.
--
-- Server-only like ops_alert_recipients: the Edge Function `feedback`
-- writes and reads with the service role, so no policies -- nobody can read
-- someone else's report through the API.
create table feedback_reports (
  id uuid primary key default gen_random_uuid(),
  -- Deleting the account deletes its reports too (delete-account removes
  -- their pictures first).
  user_id uuid not null references auth.users(id) on delete cascade,
  -- As it was when sent (the reply goes to this address).
  sender_name text,
  sender_email text,
  kind text not null check (kind in ('problem', 'idea', 'question')),
  message text not null check (length(message) between 1 and 5000),
  -- The Frame it is about, if any; its state at the time in frame_info.
  frame_id uuid references frames(id) on delete set null,
  frame_info jsonb,
  -- What the phone said about itself: app version, device, Android, language.
  device_info jsonb not null default '{}'::jsonb,
  -- Up to 3 pictures in the private bucket `feedback` (<report id>/<n>.jpg).
  image_paths text[] not null default '{}',
  -- The phone's own id for this report: sending it twice (a retry after a
  -- lost answer) keeps one row.
  client_id text unique,
  status text not null default 'open' check (status in ('open', 'done')),
  created_at timestamptz not null default now(),
  done_at timestamptz
);
alter table feedback_reports enable row level security;
-- No policies: server-only.

create index feedback_reports_created on feedback_reports (created_at desc);

insert into storage.buckets (id, name, public)
values ('feedback', 'feedback', false)
on conflict (id) do nothing;
