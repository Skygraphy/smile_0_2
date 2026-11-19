-- "Darf Alben anlegen" only by an invitation of its own (Ernst 2026-11-19,
-- right after 0109): being in an album of the Space must never be the way
-- to the right. The Space's Admin or a Co-Admin invites a person (by name
-- or QR, like a Co-Admin), the person accepts -- only then the right
-- (space_album_creators). The person needs no album in the Space for it.
-- 0109's switch list (space_people, direct insert by a manager) is gone.

-- No more direct granting: only an accepted invite puts a row there.
drop policy if exists space_album_creators_insert on space_album_creators;
drop function if exists space_people(uuid);
drop function if exists access_is_in_space(uuid, uuid);

-- Taking it away (managers) or giving it back (the person).
drop policy if exists space_album_creators_delete on space_album_creators;
create policy space_album_creators_delete on space_album_creators
  for delete using (is_space_owner(space_id) or user_id = auth.uid() or is_staff());

create table space_album_creator_invites (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  invitee_user_id uuid not null references auth.users(id) on delete cascade,
  invited_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz
);
create index idx_album_creator_invites_invitee on space_album_creator_invites(invitee_user_id);
create unique index uq_album_creator_invites_pending
  on space_album_creator_invites(space_id, invitee_user_id) where status = 'pending';

alter table space_album_creator_invites enable row level security;
create policy album_creator_invites_select on space_album_creator_invites
  for select using (invitee_user_id = auth.uid() or is_space_owner(space_id) or is_staff());
-- Invites are made by the Edge Function invite-album-creator (service role).
create policy album_creator_invites_decide on space_album_creator_invites
  for update using (invitee_user_id = auth.uid() and status = 'pending')
  with check (invitee_user_id = auth.uid());
create policy album_creator_invites_withdraw on space_album_creator_invites
  for delete using (status = 'pending' and is_space_owner(space_id));

-- Accepted: the right. Accepted or declined: the inviter hears it.
create or replace function handle_album_creator_invite_decided()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted' and old.status = 'pending' then
    insert into space_album_creators (space_id, user_id, granted_by)
    values (new.space_id, new.invitee_user_id, new.invited_by)
    on conflict do nothing;
  end if;
  if old.status = 'pending' and new.status in ('accepted', 'declined') then
    perform emit_event('album_creator_decided', jsonb_build_object(
      'space_id', new.space_id, 'user_id', new.invitee_user_id,
      'inviter_id', new.invited_by, 'accepted', new.status = 'accepted'));
  end if;
  return new;
end;
$$;

drop trigger if exists on_album_creator_invite_decided on space_album_creator_invites;
create trigger on_album_creator_invite_decided
  after update on space_album_creator_invites
  for each row when (new.status is distinct from old.status)
  execute function handle_album_creator_invite_decided();

-- The person hears only about losing it (taken by a manager); getting it
-- they did themselves by accepting.
create or replace function handle_album_right_changed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' and auth.uid() is not null and old.user_id <> auth.uid() then
    perform emit_event('album_right_changed', jsonb_build_object(
      'space_id', old.space_id, 'user_id', old.user_id, 'actor_id', auth.uid(), 'granted', false));
  end if;
  return coalesce(new, old);
end;
$$;

-- QR codes for it (redeem-invite-code, kind album_creator).
alter table invite_codes drop constraint if exists invite_codes_kind_check;
alter table invite_codes add constraint invite_codes_kind_check
  check (kind in ('album_member', 'album_share', 'space_co_owner', 'frame_admin', 'album_creator'));

-- The managers' list: who has the right, and who is invited.
create or replace function album_creator_roster(p_space uuid)
returns table (user_id uuid, display_name text, avatar_path text, status text, invite_id uuid)
language sql stable security definer set search_path = public as $$
  select a.user_id, p.display_name, p.avatar_path, 'active', null::uuid
  from space_album_creators a left join profiles p on p.user_id = a.user_id
  where a.space_id = p_space and access_manages_space(auth.uid(), p_space)
  union all
  select i.invitee_user_id, p.display_name, p.avatar_path, 'pending', i.id
  from space_album_creator_invites i left join profiles p on p.user_id = i.invitee_user_id
  where i.space_id = p_space and i.status = 'pending' and access_manages_space(auth.uid(), p_space)
  order by 4, 2 nulls last;
$$;
revoke all on function album_creator_roster(uuid) from public, anon;
grant execute on function album_creator_roster(uuid) to authenticated;

-- The invitee's own open invites (Neuigkeiten) -- spaces_select hides the
-- Space's name from someone who doesn't manage it.
create or replace function my_album_creator_invites()
returns table (id uuid, space_id uuid, space_name text, inviter_name text, inviter_avatar_path text)
language sql stable security definer set search_path = public as $$
  select i.id, s.id, s.name, p.display_name, p.avatar_path
  from space_album_creator_invites i
  join spaces s on s.id = i.space_id and s.deleted_at is null
  left join profiles p on p.user_id = i.invited_by
  where i.invitee_user_id = auth.uid() and i.status = 'pending'
  order by i.requested_at desc;
$$;
revoke all on function my_album_creator_invites() from public, anon;
grant execute on function my_album_creator_invites() to authenticated;

-- The Neuigkeiten icon: an album-creator invite waits for an answer too.
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
      ),
    'unseen_news',
      exists (
        select 1 from user_notifications n
        where n.user_id = (select id from me)
          and n.created_at > coalesce((select seen_at from news_reads where user_id = (select id from me)), '-infinity'::timestamptz)
      )
  );
$$;
