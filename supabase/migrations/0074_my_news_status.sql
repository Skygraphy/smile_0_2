-- The Neuigkeiten icon in one query (2026-10-12, speed): it only needs to
-- know whether something waits for the caller's answer and whether there
-- is unseen news -- not the whole inbox. Before, every tab's icon called
-- list-my-invites (about ten queries in a row, ~1.8 s) and
-- list-my-space-co-owner-invites at every start. Same rules as those:
--   needs_answer: an invite to the caller (album, sharing, Co-Admin) or a
--                 request in an album the caller manages, still pending
--   unseen_news:  a notification newer than the caller's news_reads mark

create or replace function public.my_news_status()
returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (select auth.uid() as id),
  managed_spaces as (
    select s.id from spaces s where s.owner_id = (select id from me) and s.deleted_at is null
    union
    select co.space_id from space_co_owners co
      join spaces s on s.id = co.space_id and s.deleted_at is null
    where co.user_id = (select id from me)
  ),
  managed_channels as (
    select c.id from channels c where c.space_id in (select id from managed_spaces) and c.deleted_at is null
  )
  select jsonb_build_object(
    'needs_answer',
      exists (
        select 1 from channel_membership_requests r join channels c on c.id = r.channel_id and c.deleted_at is null
        where r.user_id = (select id from me) and r.direction = 'invite' and r.status = 'pending'
      )
      or exists (
        select 1 from channel_share_requests r join channels c on c.id = r.channel_id and c.deleted_at is null
        where r.target_user_id = (select id from me) and r.direction = 'invite' and r.status = 'pending'
      )
      or exists (
        select 1 from space_co_owner_invites i join spaces s on s.id = i.space_id and s.deleted_at is null
        where i.invitee_user_id = (select id from me) and i.status = 'pending'
      )
      or exists (
        select 1 from channel_membership_requests r
        where r.channel_id in (select id from managed_channels) and r.direction = 'request' and r.status = 'pending'
      )
      or exists (
        select 1 from channel_share_requests r
        where r.channel_id in (select id from managed_channels) and r.direction = 'request' and r.status = 'pending'
      ),
    'unseen_news',
      exists (
        select 1 from user_notifications n
        where n.user_id = (select id from me)
          and n.created_at > coalesce((select seen_at from news_reads where user_id = (select id from me)), '-infinity'::timestamptz)
      )
  );
$$;

revoke all on function public.my_news_status() from public, anon;
grant execute on function public.my_news_status() to authenticated;
