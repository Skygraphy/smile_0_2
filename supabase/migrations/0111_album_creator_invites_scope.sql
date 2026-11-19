-- Who an album creator may bring in (Ernst 2026-11-19, preview "Ines lädt
-- ein" approved): Ines manages her own album, but she must never bring a
-- stranger into Bergoma on her own.
--   * people already anchored in the Space (in one of its albums, managing
--     it, or allowed to create albums) -> she invites them directly
--   * anyone else -> only a PROPOSAL; the Space's Admin / Co-Admins approve
--     or decline it, and only after approval the person is invited (and
--     still decides themselves)
--   * her QR / link: anchored people join, anyone else becomes a request
--     the managers decide
--   * sharing an album with another Space stays with the managers
-- The managers (Admin, Co-Admins) are not limited -- as before.

create or replace function access_is_anchored(p_user uuid, p_space uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_manages_space(p_user, p_space)
    or exists (select 1 from space_album_creators where space_id = p_space and user_id = p_user)
    or exists (
      select 1 from channel_members cm join channels c on c.id = cm.channel_id
      where cm.user_id = p_user and c.space_id = p_space and c.deleted_at is null
    );
$$;
revoke all on function access_is_anchored(uuid, uuid) from public, anon;
grant execute on function access_is_anchored(uuid, uuid) to authenticated, service_role;

-- Who in this album's Space is anchored (the invite sheet marks the rest
-- "Vorschlagen"). For whoever manages the album.
create or replace function album_anchored_people(p_channel uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  with sp as (select space_id from channels where id = p_channel)
  select u.user_id from (
    select s.owner_id as user_id from spaces s where s.id = (select space_id from sp)
    union select user_id from space_co_owners where space_id = (select space_id from sp)
    union select user_id from space_album_creators where space_id = (select space_id from sp)
    union select cm.user_id from channel_members cm join channels c on c.id = cm.channel_id
      where c.space_id = (select space_id from sp) and c.deleted_at is null
  ) u
  where access_manages_channel(auth.uid(), p_channel);
$$;
revoke all on function album_anchored_people(uuid) from public, anon;
grant execute on function album_anchored_people(uuid) to authenticated;

-- The direct ways in through the database follow the same rule: an album
-- creator can't write an invite for a stranger, nor approve a stranger's
-- request (before 0111 is_home_space_owner allowed both).
drop policy if exists channel_membership_requests_insert on channel_membership_requests;
create policy channel_membership_requests_insert on channel_membership_requests
  for insert with check (
    (direction = 'invite' and is_home_space_owner(channel_id) and (
      exists (select 1 from channels c where c.id = channel_id and is_space_owner(c.space_id))
      or exists (select 1 from channels c where c.id = channel_id and access_is_anchored(user_id, c.space_id))
    ))
    or (direction = 'request' and user_id = auth.uid())
  );

drop policy if exists channel_membership_requests_decide on channel_membership_requests;
create policy channel_membership_requests_decide on channel_membership_requests
  for update using (
    (direction = 'invite' and user_id = auth.uid())
    or (direction = 'request' and is_home_space_owner(channel_id) and (
      exists (select 1 from channels c where c.id = channel_id and is_space_owner(c.space_id))
      or exists (select 1 from channels c where c.id = channel_id and access_is_anchored(user_id, c.space_id))
    ))
    or is_staff()
  )
  with check (
    (direction = 'invite' and user_id = auth.uid())
    or (direction = 'request' and is_home_space_owner(channel_id))
    or is_staff()
  );

-- Proposals: an album creator suggests someone new; the managers decide.
create table channel_invite_proposals (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references channels(id) on delete cascade,
  invitee_user_id uuid not null references auth.users(id) on delete cascade,
  proposed_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null
);
create index idx_invite_proposals_channel on channel_invite_proposals(channel_id);
create unique index uq_invite_proposals_pending
  on channel_invite_proposals(channel_id, invitee_user_id) where status = 'pending';

alter table channel_invite_proposals enable row level security;
drop policy if exists invite_proposals_select on channel_invite_proposals;
create policy invite_proposals_select on channel_invite_proposals
  for select using (
    proposed_by = auth.uid()
    or exists (select 1 from channels c where c.id = channel_id and is_space_owner(c.space_id))
    or is_staff()
  );
-- Made by invite-channel-member (service role); decided by the managers.
drop policy if exists invite_proposals_decide on channel_invite_proposals;
create policy invite_proposals_decide on channel_invite_proposals
  for update using (
    status = 'pending'
    and exists (select 1 from channels c where c.id = channel_id and is_space_owner(c.space_id))
  )
  with check (
    exists (select 1 from channels c where c.id = channel_id and is_space_owner(c.space_id))
  );
drop policy if exists invite_proposals_withdraw on channel_invite_proposals;
create policy invite_proposals_withdraw on channel_invite_proposals
  for delete using (status = 'pending' and proposed_by = auth.uid());

-- Approved: the person gets the invitation (and decides). Either way the
-- proposer hears it, the invitee gets the usual invite push (notify-event).
create or replace function handle_invite_proposal_decided()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status <> 'pending' or new.status = 'pending' then
    return new;
  end if;
  new.decided_at := coalesce(new.decided_at, now());
  new.decided_by := coalesce(new.decided_by, auth.uid());
  if new.status = 'approved'
     and not exists (select 1 from channel_members where channel_id = new.channel_id and user_id = new.invitee_user_id)
     and not exists (select 1 from channel_membership_requests
                     where channel_id = new.channel_id and user_id = new.invitee_user_id and status = 'pending') then
    insert into channel_membership_requests (channel_id, user_id, direction)
    values (new.channel_id, new.invitee_user_id, 'invite');
  end if;
  perform emit_event('proposal_decided', jsonb_build_object(
    'channel_id', new.channel_id, 'invitee_id', new.invitee_user_id,
    'proposer_id', new.proposed_by, 'approved', new.status = 'approved'));
  return new;
end;
$$;

drop trigger if exists on_invite_proposal_decided on channel_invite_proposals;
create trigger on_invite_proposal_decided
  before update on channel_invite_proposals
  for each row when (new.status is distinct from old.status)
  execute function handle_invite_proposal_decided();

-- The managers' open proposals (Neuigkeiten).
create or replace function my_invite_proposals()
returns table (id uuid, channel_id uuid, channel_name text, space_name text,
               invitee_name text, invitee_avatar_path text, proposer_name text)
language sql stable security definer set search_path = public as $$
  select p.id, c.id, c.name, s.name, pi.display_name, pi.avatar_path, pp.display_name
  from channel_invite_proposals p
  join channels c on c.id = p.channel_id and c.deleted_at is null
  join spaces s on s.id = c.space_id and s.deleted_at is null
  left join profiles pi on pi.user_id = p.invitee_user_id
  left join profiles pp on pp.user_id = p.proposed_by
  where p.status = 'pending' and access_manages_space(auth.uid(), c.space_id)
  order by p.created_at desc;
$$;
revoke all on function my_invite_proposals() from public, anon;
grant execute on function my_invite_proposals() to authenticated;

-- The Neuigkeiten icon: requests to an album creator's own albums, and
-- proposals waiting for the managers.
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
    union
    select c.id from channels c where c.created_by = (select id from me) and c.deleted_at is null
      and access_created_album((select id from me), c.id)
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
        select 1 from frame_admin_invites i join frames f on f.id = i.frame_id and f.lifecycle_state <> 'revoked'
        where i.invitee_user_id = (select id from me) and i.status = 'pending'
      )
      or exists (
        select 1 from space_album_creator_invites i join spaces s on s.id = i.space_id and s.deleted_at is null
        where i.invitee_user_id = (select id from me) and i.status = 'pending'
      )
      or exists (
        select 1 from channel_membership_requests r
        where r.channel_id in (select id from managed_channels) and r.direction = 'request' and r.status = 'pending'
      )
      or exists (
        select 1 from channel_share_requests r
        where r.channel_id in (select id from managed_channels) and r.direction = 'request' and r.status = 'pending'
      )
      or exists (
        select 1 from channel_invite_proposals p join channels c on c.id = p.channel_id and c.deleted_at is null
        where p.status = 'pending' and c.space_id in (select id from managed_spaces)
      ),
    'unseen_news',
      exists (
        select 1 from user_notifications n
        where n.user_id = (select id from me)
          and n.created_at > coalesce((select seen_at from news_reads where user_id = (select id from me)), '-infinity'::timestamptz)
      )
  );
$$;
