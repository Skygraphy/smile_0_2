-- The Neuigkeiten icon must show that something new arrived (user feedback
-- 2026-10-06: it "rarely turns coral", so new messages went unnoticed).
-- Coral stays "something waits for your answer"; additionally a small coral
-- dot means "unseen entries in the Verlauf". news_reads remembers when the
-- person last opened Neuigkeiten; everything in user_notifications after
-- that is unseen.

create table news_reads (
  user_id uuid primary key references auth.users(id) on delete cascade,
  seen_at timestamptz not null default now()
);

alter table news_reads enable row level security;

create policy news_reads_own_select on news_reads
  for select using (user_id = auth.uid());

-- "I opened Neuigkeiten" -- server time, so a wrong phone clock can't hide
-- or resurrect the dot.
create or replace function mark_news_seen()
returns void language sql security definer set search_path = public as $$
  insert into news_reads (user_id, seen_at) values (auth.uid(), now())
  on conflict (user_id) do update set seen_at = now();
$$;

revoke all on function mark_news_seen() from public, anon;
grant execute on function mark_news_seen() to authenticated;

-- Everything already in anyone's Verlauf counts as seen at rollout.
insert into news_reads (user_id, seen_at)
select distinct user_id, now() from user_notifications
on conflict do nothing;
