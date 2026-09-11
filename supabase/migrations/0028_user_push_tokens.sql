-- Push notifications for humans (smile-app), not just Smile-Frame's
-- data-only sync nudges. One row per (user, installed app instance) --
-- a user can have several devices/reinstalls, all of them notified.
create table user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fcm_token text not null,
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

create index idx_user_push_tokens_user on user_push_tokens(user_id);

alter table user_push_tokens enable row level security;

-- Fully self-managed -- a user registers/deregisters their own token on
-- login/logout; nothing else ever needs to read or write this table
-- directly (edge functions use the service-role key). Includes a select
-- policy from the start (see project_smile-app-self-service-leave memory:
-- a PostgREST DELETE/UPSERT needs SELECT visibility too, or it silently
-- no-ops).
create policy user_push_tokens_self_all on user_push_tokens
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());
