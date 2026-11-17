-- Frame plans bought in Google Play via RevenueCat (2026-11-17, Ernst).
--
-- RevenueCat knows the buyer as their Smile user id. Which Space a purchase
-- is for comes from play_links: right before buying, the app tells the
-- server "this product is for that Space" (play-subscription, action
-- prepare). Google allows each product only once per Google account, so
-- (user, product) -> Space is unambiguous.
--
-- Each Play subscription is one space_plans row (source 'play'), keyed by
-- external_ref = 'rc:<user>:<product>', kept up to date from RevenueCat's
-- subscriber data whenever a webhook arrives or the app has just bought.
--
-- Rules (Ernst 2026-11-04): one payer per Space; only the payer changes the
-- tier or cancels; a payer leaving / handing over / deleting their account
-- gets a hint to cancel in Google Play (the subscription is not ours to stop).

create table play_links (
  user_id uuid not null references auth.users(id) on delete cascade,
  product text not null check (product ~ '^smile_frames_[0-9]+$'),
  space_id uuid not null references spaces(id) on delete cascade,
  updated_at timestamptz not null default now(),
  primary key (user_id, product)
);
alter table play_links enable row level security;
-- No policies: only the Edge Functions touch it.

alter table space_plans
  add column payer_id uuid references auth.users(id) on delete set null,
  -- Google product with base plan, e.g. 'smile_frames_3:monthly'.
  add column store_product text,
  -- false once the payer has cancelled (runs until ends_at).
  add column will_renew boolean,
  -- Payment problem at Google (grace period): still active, payer is told.
  add column billing_issue boolean not null default false,
  -- The next charge was moved past the trial / voucher once (see sync).
  add column deferred_at timestamptz;

create unique index uq_space_plans_external_ref on space_plans(external_ref) where external_ref is not null;

-- The paying person of a Space right now (a running Play subscription
-- that has not ended yet), or null.
create or replace function space_payer(p_space uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select payer_id from space_plans
   where space_id = p_space and source = 'play' and payer_id is not null
     and (ends_at is null or ends_at > now())
   order by starts_at desc limit 1;
$$;
revoke all on function space_payer(uuid) from public, anon, authenticated;
grant execute on function space_payer(uuid) to service_role;

-- space_plan() gets who pays and, for the payer, what they have in Play.
create or replace function space_plan(p_space uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  e jsonb;
  covered jsonb;
  play space_plans;
  payer_name text;
  cover_end timestamptz;
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

  -- Until when the Space is covered without Play (trial, codes, staff):
  -- buying now moves the second charge past this.
  select max(ends_at) into cover_end from space_plans
   where space_id = p_space and source <> 'play' and ends_at > now();

  return e || jsonb_build_object(
    'used_bytes', space_used_bytes(p_space),
    'covered_frames', covered,
    'photos', (select count(*) from media_items m join channels c on c.id = m.channel_id
                where c.space_id = p_space and m.processing_status = 'ready' and m.media_type = 'photo'),
    'videos', (select count(*) from media_items m join channels c on c.id = m.channel_id
                where c.space_id = p_space and m.processing_status = 'ready' and m.media_type = 'video'),
    'cover_ends_at', cover_end,
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

-- The Spaces I am paying for in Google Play and that will renew: for the
-- hints when leaving / handing over a Space and deleting the account.
create or replace function my_play_payments()
returns table (space_id uuid, space_name text)
language sql stable security definer set search_path = public as $$
  select distinct sp.space_id, s.name
  from space_plans sp join spaces s on s.id = sp.space_id
  where sp.source = 'play' and sp.payer_id = auth.uid()
    and coalesce(sp.will_renew, true) and (sp.ends_at is null or sp.ends_at > now());
$$;
revoke all on function my_play_payments() from public, anon;
grant execute on function my_play_payments() to authenticated;

-- Reminders: a Play subscription that renews never "ends" -- no "ends in
-- 7 days" every month. Only a cancelled one is reminded about, and a
-- renewing one covers whatever ends before it (trial, codes).
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
       and not (p.source = 'play' and coalesce(p.will_renew, true))
       and not exists (
         select 1 from space_plans q
          where q.space_id = p.space_id and q.id <> p.id and q.source <> 'trial'
            and q.starts_at <= p.ends_at
            and (q.ends_at is null or q.ends_at > p.ends_at
                 or (q.source = 'play' and coalesce(q.will_renew, true) and q.ends_at > now())))
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
