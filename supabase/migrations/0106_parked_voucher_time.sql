-- Voucher time is set aside while a Google Play subscription runs
-- (2026-11-18, Ernst). Moving the next Google charge back by the voucher
-- time (0105, deferral) made every later tier switch fail at Google
-- ("Server error") -- live-tested: a switch works without deferral and
-- fails after deferring by even one day. So Google is never deferred again:
--
--   * buying while a voucher still runs: the subscription charges from
--     today, the rest of the voucher time is parked here and comes back
--     right after the subscription ends (cancelled, refunded, expired);
--   * buying during the trial ends the trial (nothing to give back);
--   * a voucher redeemed while a subscription renews is parked at once;
--   * taking the cancellation back parks the not yet started time again.
--
-- reconcile_play_cover() brings a Space into that shape; play-sync calls it
-- after every RevenueCat sync, health-check hourly for Spaces with parked
-- time. Parked time lives in its own table so every existing query on
-- space_plans (entitlement, reminders, cover) stays exactly as it was.

create table space_plans_parked (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references spaces(id) on delete cascade,
  source text not null check (source in ('voucher')),
  frames int not null check (frames between 1 and 10000),
  duration interval not null check (duration > interval '0'),
  voucher_code_id uuid references voucher_codes(id) on delete set null,
  parked_at timestamptz not null default now()
);
create index idx_space_plans_parked_space on space_plans_parked(space_id);
alter table space_plans_parked enable row level security;
-- No policies: only the functions below and the Edge Functions.

comment on column space_plans.deferred_at is
  'Obsolete since 0106 (Google is no longer deferred); kept for history.';

-- A renewing Play subscription of the Space right now, or null.
create or replace function space_renewing_play(p_space uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select id from space_plans
   where space_id = p_space and source = 'play' and coalesce(will_renew, true)
     and starts_at <= now() and ends_at > now()
   order by starts_at desc limit 1;
$$;
revoke all on function space_renewing_play(uuid) from public, anon, authenticated;
grant execute on function space_renewing_play(uuid) to service_role;

create or replace function reconcile_play_cover(p_space uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  r record;
  start_at timestamptz;
  parked int := 0;
  unparked int := 0;
begin
  -- Webhook and app sync can arrive at the same moment.
  perform pg_advisory_xact_lock(hashtext('reconcile_play_cover:' || p_space::text));

  if space_renewing_play(p_space) is not null then
    -- Set the voucher time aside: what has not been used yet.
    for r in select * from space_plans
              where space_id = p_space and source = 'voucher' and ends_at > now()
              order by starts_at loop
      insert into space_plans_parked (space_id, source, frames, duration, voucher_code_id)
      values (p_space, 'voucher', r.frames, r.ends_at - greatest(r.starts_at, now()), r.voucher_code_id);
      if r.starts_at < now() then
        -- Ends now; the reminders must not say "ended" about it.
        update space_plans set ends_at = now(),
          reminded_30_at = coalesce(reminded_30_at, now()),
          reminded_7_at = coalesce(reminded_7_at, now()),
          ended_notice_at = coalesce(ended_notice_at, now())
         where id = r.id;
      else
        delete from space_plans where id = r.id;
      end if;
      parked := parked + 1;
    end loop;
    -- The trial ends with the purchase.
    update space_plans set ends_at = greatest(now(), starts_at + interval '1 second'),
      reminded_30_at = coalesce(reminded_30_at, now()),
      reminded_7_at = coalesce(reminded_7_at, now()),
      ended_notice_at = coalesce(ended_notice_at, now())
     where space_id = p_space and source = 'trial' and ends_at > now();
  elsif exists (select 1 from space_plans_parked where space_id = p_space) then
    -- No renewing subscription: the parked time follows right after what
    -- still runs (a cancelled subscription until its end).
    select greatest(now(), coalesce(max(ends_at), now())) into start_at
      from space_plans where space_id = p_space and source <> 'trial' and ends_at > now();
    for r in select * from space_plans_parked where space_id = p_space order by parked_at, id loop
      insert into space_plans (space_id, source, frames, starts_at, ends_at, voucher_code_id)
      values (p_space, r.source, r.frames, start_at, start_at + r.duration, r.voucher_code_id);
      start_at := start_at + r.duration;
      delete from space_plans_parked where id = r.id;
      unparked := unparked + 1;
    end loop;
  end if;
  return jsonb_build_object('parked', parked, 'unparked', unparked);
end $$;
revoke all on function reconcile_play_cover(uuid) from public, anon, authenticated;
grant execute on function reconcile_play_cover(uuid) to service_role;

-- Spaces with parked time (health-check reconciles them hourly, in case a
-- webhook got lost).
create or replace function spaces_with_parked_time()
returns setof uuid language sql stable security definer set search_path = public as $$
  select distinct space_id from space_plans_parked;
$$;
revoke all on function spaces_with_parked_time() from public, anon, authenticated;
grant execute on function spaces_with_parked_time() to service_role;

-- Redeeming while a subscription renews: parked at once (would otherwise
-- overlap paid months). Otherwise as in 0104.
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

  update voucher_codes set redeemed_at = now(), redeemed_space_id = p_space, redeemed_by = p_user where id = c.id;
  insert into voucher_attempts (user_id, ok) values (p_user, true);

  if space_renewing_play(p_space) is not null then
    insert into space_plans_parked (space_id, source, frames, duration, voucher_code_id)
    values (p_space, 'voucher', b.frames, make_interval(months => b.months), c.id);
    return jsonb_build_object('ok', true, 'parked', true, 'frames', b.frames, 'months', b.months,
      'from', b.card_name);
  end if;

  -- After whatever the Space already has: the trial, Play or earlier codes.
  select greatest(now(), coalesce(max(ends_at), now())) into start_at
    from space_plans where space_id = p_space and ends_at > now();
  end_at := start_at + make_interval(months => b.months);
  insert into space_plans (space_id, source, frames, starts_at, ends_at, voucher_code_id)
  values (p_space, 'voucher', b.frames, start_at, end_at, c.id);

  return jsonb_build_object('ok', true, 'frames', b.frames, 'months', b.months,
    'starts_at', start_at, 'ends_at', end_at, 'from', b.card_name);
end $$;
revoke all on function redeem_voucher(text, uuid, uuid) from public, anon, authenticated;
grant execute on function redeem_voucher(text, uuid, uuid) to service_role;

-- space_plan(): what is parked, which kind of cover runs before buying,
-- and the voucher that follows a cancelled subscription.
create or replace function space_plan(p_space uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  e jsonb;
  covered jsonb;
  play space_plans;
  payer_name text;
  cover space_plans;
  parked_days int;
  parked_frames int;
  after_frames int;
  after_end timestamptz;
begin
  if not (is_space_owner(p_space) or is_staff()) then return null; end if;
  e := space_entitlement_internal(p_space);
  select coalesce(jsonb_agg(id), '[]'::jsonb) into covered from (
    select f.id from frames f
     where f.space_id = p_space and f.lifecycle_state = 'active'
     order by f.paired_at nulls last, f.id
     limit case when e->>'status' = 'none' then 0 else (e->>'frames')::int end
  ) x;

  select * into play from space_plans
   where space_id = p_space and source = 'play' and payer_id is not null
     and (ends_at is null or ends_at > now())
   order by starts_at desc limit 1;
  if found then
    select display_name into payer_name from profiles where user_id = play.payer_id;
  end if;

  -- Until when the Space is covered without Play (trial, codes, staff),
  -- and by what: buying now ends the trial / parks the voucher time.
  select * into cover from space_plans
   where space_id = p_space and source <> 'play' and ends_at > now()
   order by ends_at desc limit 1;

  select round(extract(epoch from sum(duration)) / 86400)::int, max(frames)
    into parked_days, parked_frames
    from space_plans_parked where space_id = p_space;

  -- A cancelled subscription: the voucher time that follows it.
  if play.id is not null and not coalesce(play.will_renew, true) then
    select max(frames), max(ends_at) into after_frames, after_end
      from space_plans where space_id = p_space and source = 'voucher' and starts_at >= play.ends_at - interval '1 minute';
  end if;

  return e || jsonb_build_object(
    'used_bytes', space_used_bytes(p_space),
    'covered_frames', covered,
    'photos', (select count(*) from media_items m join channels c on c.id = m.channel_id
                where c.space_id = p_space and m.processing_status = 'ready' and m.media_type = 'photo'),
    'videos', (select count(*) from media_items m join channels c on c.id = m.channel_id
                where c.space_id = p_space and m.processing_status = 'ready' and m.media_type = 'video'),
    'cover_ends_at', cover.ends_at,
    'cover_source', cover.source,
    'parked_days', parked_days,
    'parked_frames', parked_frames,
    'after_play_frames', after_frames,
    'after_play_ends_at', after_end,
    'payer_id', play.payer_id,
    'payer_name', payer_name,
    'payer_is_me', play.payer_id is not null and play.payer_id = auth.uid(),
    'play_product', case when play.payer_id = auth.uid() then play.store_product end,
    'play_frames', play.frames,
    'play_renews', case when play.payer_id = auth.uid() then play.will_renew end,
    'play_ends_at', case when play.payer_id = auth.uid() then play.ends_at end,
    'play_billing_issue', case when play.payer_id = auth.uid() then play.billing_issue end);
end $$;
revoke all on function space_plan(uuid) from public, anon;
grant execute on function space_plan(uuid) to authenticated;
