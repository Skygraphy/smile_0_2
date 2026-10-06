-- Notification history (decided 2026-10-06 in the live walkthrough): every
-- visible push is also kept for 30 days, so Neuigkeiten can show a
-- "Verlauf" below its open to-dos -- "Ernst hat Stammtisch verlassen" no
-- longer vanishes once the notification is swiped away. The coral
-- Neuigkeiten icon stays reserved for things that need an answer; the
-- history never lights it up.
--
-- Written only by the Edge Functions (service role) next to every push
-- (_shared/push-users.ts); the app only reads its own rows.

create table user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  -- The same routing data the push carries (type, channel_id, ...), so a
  -- tap in the history opens the same place as a tap on the notification.
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_user_notifications_user_created on user_notifications(user_id, created_at desc);

alter table user_notifications enable row level security;

create policy user_notifications_own_select on user_notifications
  for select using (user_id = auth.uid());

-- Older than 30 days -> gone, daily, next to the trash purge.
select cron.schedule(
  'smile-purge-notifications',
  '27 3 * * *',
  $cron$delete from user_notifications where created_at < now() - interval '30 days'$cron$
);
