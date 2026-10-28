-- Frame-Admin (2026-10-28, Ernst): the Space's Admin makes someone -- e.g.
-- the mother of the child whose Frame it is -- Frame-Admin of ONE Frame.
-- Then that person decides everything about how this Frame is used: the
-- control level and buttons, playback, the remote, its Lieblingsbilder and
-- which albums of the Space run on it. Not: pairing, renaming, deleting the
-- Frame, or anything else in the Space (photos, albums, people).
-- Invited like a Co-Admin: by name or QR code, the invitee decides.
--
-- Plus the code to unlock a Frame on the device itself (Kindersperre):
-- a long press on the clock and the code shows every button for a while.
-- Set by the Frame's Space managers or a Frame-Admin; stored as a hash.

create table frame_admins (
  frame_id uuid not null references frames(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (frame_id, user_id)
);
create index idx_frame_admins_user on frame_admins(user_id);

create table frame_admin_invites (
  id uuid primary key default gen_random_uuid(),
  frame_id uuid not null references frames(id) on delete cascade,
  invitee_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz
);
create index idx_frame_admin_invites_invitee on frame_admin_invites(invitee_user_id);
create unique index uq_frame_admin_invites_pending
  on frame_admin_invites(frame_id, invitee_user_id) where status = 'pending';

-- The unlock code's hash: sha256 of "<frame id>:<code>", hex.
alter table frames add column if not exists unlock_code_hash text;

create or replace function access_is_frame_admin(p_user uuid, p_frame uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_user is not null and exists (select 1 from frame_admins where frame_id = p_frame and user_id = p_user);
$$;

-- Manages the Frame: its Space's Admin or a Co-Admin, or a Frame-Admin.
create or replace function access_manages_frame(p_user uuid, p_frame uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from frames f where f.id = p_frame and access_manages_space(p_user, f.space_id))
      or access_is_frame_admin(p_user, p_frame);
$$;

create or replace function is_frame_manager(check_frame_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select access_manages_frame(auth.uid(), check_frame_id);
$$;

-- frames: Frame-Admins see and change their Frame ...
drop policy if exists frames_select on frames;
create policy frames_select on frames
  for select using (is_space_owner(space_id) or access_is_frame_admin(auth.uid(), id) or is_staff());
drop policy if exists frames_owner_update on frames;
create policy frames_owner_update on frames
  for update using (is_space_owner(space_id) or access_is_frame_admin(auth.uid(), id) or is_staff())
  with check (is_space_owner(space_id) or access_is_frame_admin(auth.uid(), id) or is_staff());

-- ... but only how it is used: name, picture, Space, pairing and its life
-- stay with the Space's managers.
create or replace function guard_frame_admin_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or is_staff() or access_manages_space(auth.uid(), old.space_id) then
    return new;
  end if;
  if new.name is distinct from old.name
     or new.space_id is distinct from old.space_id
     or new.avatar_path is distinct from old.avatar_path
     or new.lifecycle_state is distinct from old.lifecycle_state
     or new.pairing_code is distinct from old.pairing_code
     or new.pairing_code_expires_at is distinct from old.pairing_code_expires_at
     or new.paired_at is distinct from old.paired_at
     or new.fcm_token is distinct from old.fcm_token then
    raise exception 'frame_admin_not_allowed' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_frame_admin_update on frames;
create trigger guard_frame_admin_update before update on frames
  for each row execute function guard_frame_admin_update();

-- Which albums run on it: the Space's albums (and those shared into it).
create or replace function frame_may_show_channel(p_frame uuid, p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from frames f
    where f.id = p_frame
      and access_manages_frame(auth.uid(), f.id)
      and access_space_can_view_channel(f.space_id, p_channel)
  );
$$;

drop policy if exists frame_channels_select on frame_channels;
create policy frame_channels_select on frame_channels
  for select using (is_frame_manager(frame_id) or is_staff());

drop policy if exists frame_favorites_select on frame_favorites;
create policy frame_favorites_select on frame_favorites
  for select using (is_frame_manager(frame_id));
drop policy if exists frame_favorites_insert on frame_favorites;
create policy frame_favorites_insert on frame_favorites
  for insert with check (added_by = auth.uid() and is_frame_manager(frame_id));
drop policy if exists frame_favorites_delete on frame_favorites;
create policy frame_favorites_delete on frame_favorites
  for delete using (is_frame_manager(frame_id));

-- A Frame-Admin chooses among the albums its Space may show -- so sees
-- their names (not their photos: those stay with the album's people).
drop policy if exists channels_frame_admin_select on channels;
create policy channels_frame_admin_select on channels
  for select using (
    exists (
      select 1 from frame_admins fa join frames f on f.id = fa.frame_id
      where fa.user_id = auth.uid() and access_space_can_view_channel(f.space_id, channels.id)
    )
  );

-- The Space's name for a Frame-Admin's Frames tab, without opening the
-- Space itself to them.
create or replace function my_frame_space_names(p_frames uuid[])
returns table (frame_id uuid, space_name text)
language sql stable security definer set search_path = public as $$
  select f.id, s.name from frames f join spaces s on s.id = f.space_id
  where f.id = any(p_frames) and access_manages_frame(auth.uid(), f.id);
$$;
revoke all on function my_frame_space_names(uuid[]) from public, anon;
grant execute on function my_frame_space_names(uuid[]) to authenticated;

alter table frame_admins enable row level security;
create policy frame_admins_select on frame_admins
  for select using (
    user_id = auth.uid()
    or exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
    or is_staff()
  );
-- Ended by the Space's managers -- or given up by the Frame-Admin.
create policy frame_admins_delete on frame_admins
  for delete using (
    user_id = auth.uid()
    or exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
  );

alter table frame_admin_invites enable row level security;
create policy frame_admin_invites_select on frame_admin_invites
  for select using (
    invitee_user_id = auth.uid()
    or exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
    or is_staff()
  );
create policy frame_admin_invites_insert on frame_admin_invites
  for insert with check (exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id)));
create policy frame_admin_invites_invitee_decide on frame_admin_invites
  for update using (invitee_user_id = auth.uid() and status = 'pending')
  with check (invitee_user_id = auth.uid());
create policy frame_admin_invites_withdraw on frame_admin_invites
  for delete using (
    status = 'pending' and exists (select 1 from frames f where f.id = frame_id and is_space_owner(f.space_id))
  );

create or replace function handle_frame_admin_invite_decided()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted' and old.status = 'pending' then
    insert into frame_admins (frame_id, user_id) values (new.frame_id, new.invitee_user_id)
    on conflict do nothing;
  end if;
  return new;
end;
$$;
create trigger on_frame_admin_invite_decided
  after update on frame_admin_invites
  for each row when (new.status is distinct from old.status)
  execute function handle_frame_admin_invite_decided();

-- QR codes for it (create-invite-code / redeem-invite-code).
alter table invite_codes drop constraint if exists invite_codes_kind_check;
alter table invite_codes add constraint invite_codes_kind_check
  check (kind in ('album_member', 'album_share', 'space_co_owner', 'frame_admin'));

-- The badge on Neuigkeiten: an open Frame-Admin invite needs an answer too.
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

-- Live sync: Frame-Admins hear about their Frame (same function as 0076).
create or replace function sync_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_rows jsonb;
  v_new jsonb;
  v_old jsonb;
  -- Columns whose change alone is NOT worth a push: Frame telemetry
  -- (submit-heartbeat/get-media-batch write these every few minutes -- a
  -- push per heartbeat would be pure noise, and the Frame would even push
  -- itself on every sync).
  v_ignore text[] := case tg_table_name
    when 'frames' then array['last_seen_at', 'battery_level', 'is_charging', 'current_app_version', 'fcm_token', 'device_model']
    else array[]::text[]
  end;
  v_users uuid[];
  v_frames uuid[];
  v_channel_ids text[];
  v_space_ids text[];
  v_user uuid;
begin
  if tg_op in ('INSERT', 'UPDATE') then
    select coalesce(jsonb_agg(to_jsonb(n)), '[]'::jsonb) into v_new from new_rows n;
  end if;
  if tg_op in ('DELETE', 'UPDATE') then
    select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) into v_old from old_rows o;
  end if;

  -- A photo moving from "uploaded" to "processing" changes nothing anyone
  -- sees (the preview shows either way): only its arrival, it becoming
  -- ready (or failing) and its deletion are worth waking devices for.
  if tg_table_name = 'media_items' and tg_op = 'UPDATE' and not exists (
    select 1 from jsonb_array_elements(v_new) r where r->>'processing_status' in ('ready', 'failed')
  ) then
    return null;
  end if;

  if tg_op = 'UPDATE' then
    -- Skip an update that changed nothing but ignored columns (or nothing
    -- at all). Compared as sorted sets, so no per-table key knowledge needed.
    if (select coalesce(jsonb_agg(r - v_ignore order by (r - v_ignore)::text), '[]'::jsonb) from jsonb_array_elements(v_new) r)
       = (select coalesce(jsonb_agg(r - v_ignore order by (r - v_ignore)::text), '[]'::jsonb) from jsonb_array_elements(v_old) r)
    then
      return null;
    end if;
  end if;

  v_rows := coalesce(v_new, '[]'::jsonb) || coalesce(v_old, '[]'::jsonb);
  if jsonb_array_length(v_rows) = 0 then
    return null;
  end if;

  select array_agg(distinct x) into v_channel_ids from (
    select coalesce(r->>'channel_id', case when tg_table_name = 'channels' then r->>'id' end) as x
    from jsonb_array_elements(v_rows) r
  ) s where x is not null;

  select array_agg(distinct x) into v_space_ids from (
    select coalesce(r->>'space_id', case when tg_table_name = 'spaces' then r->>'id' end) as x
    from jsonb_array_elements(v_rows) r
  ) s where x is not null;

  -- Who sees it. Direct user columns on the row itself are always
  -- included too -- after a delete (someone removed from a channel, an
  -- invite withdrawn) that person is no longer derivable from the
  -- remaining data, but is exactly who most needs to reload.
  select array_agg(distinct u) into v_users from (
    select case tg_table_name
      when 'spaces' then (r->>'owner_id')::uuid
      when 'channel_members' then (r->>'user_id')::uuid
      when 'channel_membership_requests' then (r->>'user_id')::uuid
      when 'channel_share_requests' then (r->>'target_user_id')::uuid
      when 'space_co_owners' then (r->>'user_id')::uuid
      when 'space_co_owner_invites' then (r->>'invitee_user_id')::uuid
      when 'media_item_hides' then (r->>'user_id')::uuid
      when 'album_reads' then (r->>'user_id')::uuid
      when 'profiles' then (r->>'user_id')::uuid
      when 'frame_admins' then (r->>'user_id')::uuid
      when 'frame_admin_invites' then (r->>'invitee_user_id')::uuid
    end as u
    from jsonb_array_elements(v_rows) r
    union
    -- Requests/invites are only visible to the two parties -- never to
    -- every channel member -- so they get the home Space's audience, not
    -- the whole channel's. Same for a Frame's own settings/assignments.
    select sync_space_audience(c.space_id)
      from channels c
      where tg_table_name in ('channel_membership_requests', 'channel_share_requests')
        and c.id::text = any(v_channel_ids)
    union
    select sync_channel_audience(cid::uuid)
      from unnest(v_channel_ids) cid
      where tg_table_name in ('channels', 'channel_members', 'channel_shares', 'media_items')
    union
    select sync_space_audience(sid::uuid)
      from unnest(v_space_ids) sid
      where tg_table_name in ('spaces', 'channels', 'channel_shares', 'channel_share_requests',
                              'space_co_owners', 'space_co_owner_invites', 'frames')
    union
    -- A Space rename shows up in its channels' and shared-in channels' lists.
    select sync_channel_audience(c.id)
      from channels c
      where tg_table_name = 'spaces' and c.space_id::text = any(v_space_ids)
    union
    select sync_channel_audience(cs.channel_id)
      from channel_shares cs
      where tg_table_name = 'spaces' and cs.space_id::text = any(v_space_ids)
    union
    select sync_space_audience(f.space_id)
      from frames f
      where tg_table_name in ('frame_channels', 'frame_favorites')
        and f.id::text in (select r->>'frame_id' from jsonb_array_elements(v_rows) r)
    union
    -- Frame-Admins (0089): everything about their Frame reaches them, and
    -- the Space's managers see who is Frame-Admin of their Frames.
    select fa.user_id
      from frame_admins fa
      where tg_table_name in ('frames', 'frame_channels', 'frame_favorites')
        and fa.frame_id::text in (
          select coalesce(r->>'frame_id', case when tg_table_name = 'frames' then r->>'id' end)
          from jsonb_array_elements(v_rows) r
        )
    union
    select sync_space_audience(f.space_id)
      from frames f
      where tg_table_name in ('frame_admins', 'frame_admin_invites')
        and f.id::text in (select r->>'frame_id' from jsonb_array_elements(v_rows) r)
    union
    select sync_user_audience((r->>'user_id')::uuid)
      from jsonb_array_elements(v_rows) r
      where tg_table_name = 'profiles'
  ) s where u is not null;

  -- Which Frames need to re-sync (smile-frame treats any FCM message as
  -- "sync now", see PushSyncSignal).
  select array_agg(distinct f) into v_frames from (
    select (r->>'frame_id')::uuid as f
      from jsonb_array_elements(v_rows) r
      where tg_table_name in ('frame_channels', 'frame_favorites')
    union
    select (r->>'id')::uuid
      from jsonb_array_elements(v_rows) r
      where tg_table_name = 'frames' and tg_op <> 'DELETE'
    union
    -- Space renamed/trashed/restored: its name shows on every Frame of it
    -- ("Bergoma · Enkelkinder"), found in the 2026-10-06 walkthrough.
    select f.id
      from frames f
      where tg_table_name = 'spaces' and f.space_id::text = any(v_space_ids)
    union
    -- Channel renamed/trashed: its name shows in the Frame's switcher.
    select fc.frame_id
      from frame_channels fc
      where tg_table_name = 'channels' and fc.channel_id::text = any(v_channel_ids)
    union
    -- A photo became ready (or was deleted) in a channel a Frame shows.
    -- Frames compute their content live from media_items now (0049), so
    -- this replaces the push the media_recipients insert used to cause.
    -- Uploads still processing don't wake Frames: they can't show them yet.
    select fc.frame_id
      from frame_channels fc
      where tg_table_name = 'media_items'
        and fc.channel_id::text = any(v_channel_ids)
        and (tg_op = 'DELETE' or exists (
          select 1 from jsonb_array_elements(v_new) r where r->>'processing_status' = 'ready'
        ))
  ) s where f is not null;

  if coalesce(array_length(v_users, 1), 0) = 0 and coalesce(array_length(v_frames, 1), 0) = 0 then
    return null;
  end if;

  -- Through the outbox (0050): retried until it arrives.
  perform invoke_internal('sync-fanout', jsonb_build_object(
    'table', tg_table_name,
    'op', lower(tg_op),
    'users', coalesce(to_jsonb(v_users), '[]'::jsonb),
    'frames', coalesce(to_jsonb(v_frames), '[]'::jsonb),
    'channel_ids', coalesce(to_jsonb(v_channel_ids), '[]'::jsonb),
    'space_ids', coalesce(to_jsonb(v_space_ids), '[]'::jsonb)
  ));
  -- Open apps (iPhone and Android alike) get the same signal at once over
  -- their private live channel (0053) -- iOS throttles silent pushes even
  -- for an app in the foreground. Delivered by Realtime after commit.
  if v_users is not null then
    for v_user in select unnest(v_users) loop
      perform realtime.send(
        jsonb_build_object(
          'type', 'sync',
          'table', tg_table_name,
          'op', lower(tg_op),
          'channel_ids', coalesce(array_to_string(v_channel_ids, ','), ''),
          'space_ids', coalesce(array_to_string(v_space_ids, ','), '')
        ),
        'sync',
        'sync:' || v_user,
        true
      );
    end loop;
  end if;
  return null;
exception when others then
  -- A sync push is a convenience layered on top of the write -- it must
  -- never be the reason the write itself fails.
  raise warning 'sync_notify(%) failed: %', tg_table_name, sqlerrm;
  return null;
end;
$$;

drop trigger if exists sync_notify_ins on frame_admins;
drop trigger if exists sync_notify_del on frame_admins;
create trigger sync_notify_ins after insert on frame_admins referencing new table as new_rows
  for each statement execute function sync_notify();
create trigger sync_notify_del after delete on frame_admins referencing old table as old_rows
  for each statement execute function sync_notify();
drop trigger if exists sync_notify_ins on frame_admin_invites;
drop trigger if exists sync_notify_upd on frame_admin_invites;
drop trigger if exists sync_notify_del on frame_admin_invites;
create trigger sync_notify_ins after insert on frame_admin_invites referencing new table as new_rows
  for each statement execute function sync_notify();
create trigger sync_notify_upd after update on frame_admin_invites referencing old table as old_rows new table as new_rows
  for each statement execute function sync_notify();
create trigger sync_notify_del after delete on frame_admin_invites referencing old table as old_rows
  for each statement execute function sync_notify();
