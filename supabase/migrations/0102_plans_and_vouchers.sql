-- Frame subscriptions and voucher codes (2026-11-11, Ernst).
--
-- The app stays free. What a Space may do is decided here, on the server:
--   * no plan:  5 GB, videos up to 2 minutes, Frames get no new photos
--   * trial:    2 months from its first paired Frame, every Frame gets new
--               photos, storage and video stay at the free level
--   * 1 Frame   25 GB, 5 min    * 3 Frames  50 GB, 10 min
--   * 5 Frames 100 GB, 10 min   * more:    +20 GB per extra Frame, 15 min
-- A plan comes from Google Play (later, via RevenueCat), a voucher code, or
-- staff. A Frame without cover keeps everything it already shows and gets
-- nothing newer (frame_photos_until). Nothing is ever deleted.
--
-- Voucher codes: only staff create them, in batches (gift / partner /
-- promo). Each code works once, for one Space, redeemed by its Admin or a
-- Co-Admin. Only an HMAC of the code is stored (pepper in the Edge
-- Functions), plus the last four characters for display.

-- --------------------------------------------------------------------------
-- Limits per plan size (frames = 0: free)
-- --------------------------------------------------------------------------
create or replace function plan_limits(p_frames int)
returns jsonb language sql immutable as $$
  select case
    when coalesce(p_frames, 0) <= 0 then jsonb_build_object('storage_bytes', 5::bigint * 1073741824, 'video_seconds', 120)
    when p_frames <= 1 then jsonb_build_object('storage_bytes', 25::bigint * 1073741824, 'video_seconds', 300)
    when p_frames <= 3 then jsonb_build_object('storage_bytes', 50::bigint * 1073741824, 'video_seconds', 600)
    when p_frames <= 5 then jsonb_build_object('storage_bytes', 100::bigint * 1073741824, 'video_seconds', 600)
    else jsonb_build_object('storage_bytes', (100 + 20 * (p_frames - 5))::bigint * 1073741824, 'video_seconds', 900)
  end;
$$;

-- --------------------------------------------------------------------------
-- Vouchers
-- --------------------------------------------------------------------------
create table voucher_batches (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  kind text not null check (kind in ('gift', 'partner', 'promo')),
  frames int not null check (frames between 1 and 100),
  months int not null check (months between 1 and 36),
  redeem_until timestamptz not null,
  invoice_ref text check (invoice_ref is null or char_length(invoice_ref) <= 60),
  -- Shown to the family after redeeming ("Ein Geschenk von ..."), optional.
  card_name text check (card_name is null or char_length(card_name) <= 80),
  -- The partner's secret link smileapp.app/partner/<token>: shows only
  -- which cards are redeemed, nothing about the families.
  partner_token text unique,
  blocked_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table voucher_codes (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references voucher_batches(id) on delete cascade,
  code_hash text not null unique,
  last4 text not null,
  redeemed_at timestamptz,
  redeemed_space_id uuid references spaces(id) on delete set null,
  redeemed_by uuid references auth.users(id) on delete set null,
  blocked_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_voucher_codes_batch on voucher_codes(batch_id);

-- Wrong codes per person, for "at most 5 wrong tries per hour".
create table voucher_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ok boolean not null,
  at timestamptz not null default now()
);
create index idx_voucher_attempts_user on voucher_attempts(user_id, at);

-- --------------------------------------------------------------------------
-- Plans
-- --------------------------------------------------------------------------
create table space_plans (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  source text not null check (source in ('trial', 'play', 'voucher', 'staff')),
  -- How many Frames it covers (the trial covers all of them).
  frames int not null check (frames between 1 and 10000),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  voucher_code_id uuid references voucher_codes(id) on delete set null,
  -- Google Play / RevenueCat purchase reference (later).
  external_ref text,
  -- Reminder bookkeeping (health-check): 30 and 7 days before, the day after.
  reminded_30_at timestamptz,
  reminded_7_at timestamptz,
  ended_notice_at timestamptz,
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);
create index idx_space_plans_space on space_plans(space_id);

alter table voucher_batches enable row level security;
alter table voucher_codes enable row level security;
alter table voucher_attempts enable row level security;
alter table space_plans enable row level security;
-- No policies: everything goes through the functions below / Edge Functions.

-- --------------------------------------------------------------------------
-- What a Space has right now
-- --------------------------------------------------------------------------
create or replace function space_entitlement_internal(p_space uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  paid space_plans;
  trial space_plans;
  chain_end timestamptz;
  open_ended boolean;
  last_end timestamptz;
  used int;
begin
  select count(*) into used from frames where space_id = p_space and lifecycle_state = 'active';

  select * into paid from space_plans
   where space_id = p_space and source <> 'trial'
     and starts_at <= now() and (ends_at is null or ends_at > now())
   order by frames desc limit 1;
  if found then
    -- Plans redeemed back to back: the end of the chain is the latest end.
    select bool_or(ends_at is null), max(ends_at) into open_ended, chain_end
      from space_plans where space_id = p_space and source <> 'trial' and (ends_at is null or ends_at > now());
    return plan_limits(paid.frames) || jsonb_build_object(
      'status', 'active', 'source', paid.source, 'frames', paid.frames, 'frames_used', used,
      'ends_at', case when open_ended then null else chain_end end);
  end if;

  select * into trial from space_plans
   where space_id = p_space and source = 'trial'
     and starts_at <= now() and (ends_at is null or ends_at > now())
   order by ends_at desc nulls first limit 1;
  if found then
    return plan_limits(0) || jsonb_build_object(
      'status', 'trial', 'source', 'trial', 'frames', trial.frames, 'frames_used', used, 'ends_at', trial.ends_at);
  end if;

  select max(ends_at) into last_end from space_plans where space_id = p_space and ends_at <= now();
  return plan_limits(0) || jsonb_build_object(
    'status', 'none', 'source', null, 'frames', 0, 'frames_used', used, 'ended_at', last_end,
    'trial_used', exists (select 1 from space_plans where space_id = p_space and source = 'trial'));
end $$;
revoke all on function space_entitlement_internal(uuid) from public, anon, authenticated;
grant execute on function space_entitlement_internal(uuid) to service_role;

create or replace function space_used_bytes(p_space uuid)
returns bigint language sql stable security definer set search_path = public as $$
  select coalesce(sum(m.file_size_bytes), 0)::bigint
  from media_items m join channels c on c.id = m.channel_id
  where c.space_id = p_space and m.processing_status = 'ready';
$$;
revoke all on function space_used_bytes(uuid) from public, anon, authenticated;
grant execute on function space_used_bytes(uuid) to service_role;

-- For the Space page (Admin and Co-Admins): plan, limits, storage, and
-- which Frames are covered (the first paired ones).
create or replace function space_plan(p_space uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  e jsonb;
  covered jsonb;
begin
  if not (is_space_owner(p_space) or is_staff()) then return null; end if;
  e := space_entitlement_internal(p_space);
  select coalesce(jsonb_agg(id), '[]'::jsonb) into covered from (
    select f.id from frames f
     where f.space_id = p_space and f.lifecycle_state = 'active'
     order by f.paired_at nulls last, f.id
     limit case when e->>'status' = 'none' then 0 else (e->>'frames')::int end
  ) x;
  return e || jsonb_build_object(
    'used_bytes', space_used_bytes(p_space),
    'covered_frames', covered,
    'photos', (select count(*) from media_items m join channels c on c.id = m.channel_id
                where c.space_id = p_space and m.processing_status = 'ready' and m.media_type = 'photo'),
    'videos', (select count(*) from media_items m join channels c on c.id = m.channel_id
                where c.space_id = p_space and m.processing_status = 'ready' and m.media_type = 'video'));
end $$;
revoke all on function space_plan(uuid) from public, anon;
grant execute on function space_plan(uuid) to authenticated;

-- For whoever sends into an album: how long a video may be there.
create or replace function album_video_seconds(p_channel uuid)
returns int language sql stable security definer set search_path = public as $$
  select (space_entitlement_internal(c.space_id)->>'video_seconds')::int
  from channels c where c.id = p_channel;
$$;
revoke all on function album_video_seconds(uuid) from public, anon;
grant execute on function album_video_seconds(uuid) to authenticated;

-- Up to when a Frame gets photos (by upload time); null = no limit.
create or replace function frame_photos_until(p_frame uuid)
returns timestamptz language plpgsql stable security definer set search_path = public as $$
declare
  f frames;
  e jsonb;
  rank int;
begin
  select * into f from frames where id = p_frame;
  if not found then return now(); end if;
  e := space_entitlement_internal(f.space_id);
  if e->>'status' <> 'none' then
    select count(*) into rank from frames
     where space_id = f.space_id and lifecycle_state = 'active'
       and (coalesce(paired_at, 'infinity'), id) <= (coalesce(f.paired_at, 'infinity'), f.id);
    if rank <= (e->>'frames')::int then return null; end if;
    -- More Frames than the plan covers: the newest one gets nothing newer
    -- than when it was paired.
    return coalesce(f.paired_at, f.created_at);
  end if;
  return coalesce(
    (select max(ends_at) from space_plans where space_id = f.space_id and ends_at <= now()),
    f.paired_at, f.created_at);
end $$;
revoke all on function frame_photos_until(uuid) from public, anon, authenticated;
grant execute on function frame_photos_until(uuid) to service_role;

-- frame_media_page gets the cut-off (null = none).
drop function if exists frame_media_page(uuid, bigint, int);
create function frame_media_page(p_channel uuid, p_after bigint, p_limit int, p_until timestamptz default null)
returns table (
  media_item_id uuid,
  media_type text,
  storage_path_display text,
  storage_path_thumbnail text,
  sort_key bigint,
  sender_name text,
  caption text,
  taken_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select m.id, m.media_type, m.storage_path_display, m.storage_path_thumbnail,
         (extract(epoch from m.created_at) * 1000000)::bigint as sort_key,
         p.display_name,
         m.caption,
         coalesce(m.taken_at, m.created_at)
  from media_items m
  left join profiles p on p.user_id = m.sender_id
  where m.channel_id = p_channel
    and m.processing_status = 'ready'
    and m.storage_path_display is not null
    and (p_until is null or m.created_at <= p_until)
    and (p_after is null or (extract(epoch from m.created_at) * 1000000)::bigint > p_after)
  order by m.created_at, m.id
  limit p_limit;
$$;
revoke all on function frame_media_page(uuid, bigint, int, timestamptz) from public, anon, authenticated;
grant execute on function frame_media_page(uuid, bigint, int, timestamptz) to service_role;

-- --------------------------------------------------------------------------
-- Trial: starts when a Space's first Frame is paired, once per Space.
-- --------------------------------------------------------------------------
create or replace function start_trial_on_pairing()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.paired_at is not null and (tg_op = 'INSERT' or old.paired_at is null)
     and not exists (select 1 from space_plans where space_id = new.space_id) then
    insert into space_plans (space_id, source, frames, starts_at, ends_at)
    values (new.space_id, 'trial', 10000, now(), now() + interval '2 months');
  end if;
  return new;
end $$;
create trigger frames_start_trial after insert or update of paired_at on frames
  for each row execute function start_trial_on_pairing();

-- Spaces that already have a paired Frame start their trial today.
insert into space_plans (space_id, source, frames, starts_at, ends_at)
select distinct f.space_id, 'trial', 10000, now(), now() + interval '2 months'
from frames f join spaces s on s.id = f.space_id
where f.paired_at is not null and s.deleted_at is null;

-- --------------------------------------------------------------------------
-- Redeeming (called by the redeem-voucher Edge Function with the HMAC)
-- --------------------------------------------------------------------------
create or replace function redeem_voucher(p_hash text, p_space uuid, p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  c voucher_codes;
  b voucher_batches;
  fails int;
  start_at timestamptz;
  end_at timestamptz;
begin
  select count(*) into fails from voucher_attempts
   where user_id = p_user and not ok and at > now() - interval '1 hour';
  if fails >= 5 then return jsonb_build_object('error', 'rate_limited'); end if;

  if not exists (select 1 from spaces where id = p_space and owner_id = p_user and deleted_at is null)
     and not exists (select 1 from space_co_owners sco join spaces s on s.id = sco.space_id
                      where sco.space_id = p_space and sco.user_id = p_user and s.deleted_at is null) then
    return jsonb_build_object('error', 'not_space_manager');
  end if;

  -- Row lock: two people with the same code at the same moment -- one wins.
  select * into c from voucher_codes where code_hash = p_hash for update;
  if not found then
    insert into voucher_attempts (user_id, ok) values (p_user, false);
    return jsonb_build_object('error', 'not_found');
  end if;
  select * into b from voucher_batches where id = c.batch_id;
  if c.redeemed_at is not null then return jsonb_build_object('error', 'already_used'); end if;
  if c.blocked_at is not null or b.blocked_at is not null then return jsonb_build_object('error', 'blocked'); end if;
  if b.redeem_until < now() then return jsonb_build_object('error', 'expired'); end if;

  -- After whatever paid time the Space already has (Play or earlier codes).
  select greatest(now(), coalesce(max(ends_at), now())) into start_at
    from space_plans where space_id = p_space and source <> 'trial' and ends_at > now();
  end_at := start_at + make_interval(months => b.months);

  update voucher_codes set redeemed_at = now(), redeemed_space_id = p_space, redeemed_by = p_user where id = c.id;
  insert into space_plans (space_id, source, frames, starts_at, ends_at, voucher_code_id)
  values (p_space, 'voucher', b.frames, start_at, end_at, c.id);
  update space_plans set ends_at = now()
   where space_id = p_space and source = 'trial' and (ends_at is null or ends_at > now()) and starts_at < now();
  insert into voucher_attempts (user_id, ok) values (p_user, true);

  return jsonb_build_object('ok', true, 'frames', b.frames, 'months', b.months,
    'starts_at', start_at, 'ends_at', end_at, 'from', b.card_name);
end $$;
revoke all on function redeem_voucher(text, uuid, uuid) from public, anon, authenticated;
grant execute on function redeem_voucher(text, uuid, uuid) to service_role;

-- --------------------------------------------------------------------------
-- Reminders (health-check, hourly): the end of a Space's chain of plans,
-- 30 and 7 days before and once after. Each sent once (returned rows are
-- marked here).
-- --------------------------------------------------------------------------
create or replace function plan_reminders_due()
returns table (space_id uuid, space_name text, kind text, source text, ends_at timestamptz)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  return query
  with chain_end as (
    select p.* from space_plans p join spaces s on s.id = p.space_id
     where s.deleted_at is null and p.ends_at is not null
       and p.ends_at > now() - interval '2 days'
       and not exists (
         select 1 from space_plans q
          where q.space_id = p.space_id and q.id <> p.id and q.source <> 'trial'
            and q.starts_at <= p.ends_at and (q.ends_at is null or q.ends_at > p.ends_at))
  ), due as (
    select ce.id, ce.space_id, ce.source, ce.ends_at,
      case
        when ce.ends_at <= now() and ce.ended_notice_at is null then 'ended'
        when ce.ends_at > now() and ce.ends_at <= now() + interval '7 days' and ce.reminded_7_at is null then 'days7'
        when ce.ends_at > now() + interval '7 days' and ce.ends_at <= now() + interval '30 days'
             and ce.reminded_30_at is null and ce.source <> 'trial' then 'days30'
      end as kind
    from chain_end ce
  ), marked as (
    update space_plans sp set
      ended_notice_at = case when d.kind = 'ended' then now() else sp.ended_notice_at end,
      reminded_7_at = case when d.kind in ('days7', 'ended') then coalesce(sp.reminded_7_at, now()) else sp.reminded_7_at end,
      reminded_30_at = case when d.kind in ('days30', 'days7', 'ended') then coalesce(sp.reminded_30_at, now()) else sp.reminded_30_at end
    from due d where d.id = sp.id and d.kind is not null
    returning sp.space_id, d.kind, sp.source, sp.ends_at
  )
  select m.space_id, s.name, m.kind, m.source, m.ends_at
  from marked m join spaces s on s.id = m.space_id;
end $$;
revoke all on function plan_reminders_due() from public, anon, authenticated;
grant execute on function plan_reminders_due() to service_role;

-- Storage per Space with its limit (health-check's 80 / 95 % hints).
create or replace function space_storage_levels()
returns table (space_id uuid, space_name text, used_bytes bigint, limit_bytes bigint)
language sql stable security definer set search_path = public as $$
  select s.id, s.name, space_used_bytes(s.id),
         (space_entitlement_internal(s.id)->>'storage_bytes')::bigint
  from spaces s where s.deleted_at is null;
$$;
revoke all on function space_storage_levels() from public, anon, authenticated;
grant execute on function space_storage_levels() to service_role;
