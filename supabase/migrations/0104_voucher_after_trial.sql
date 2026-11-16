-- A voucher redeemed during the free trial starts when the trial ends,
-- instead of ending the trial early (Ernst 2026-11-16: the gift must not
-- eat up the rest of the trial). Paid time (Play or earlier codes) was
-- already stacked; the trial now counts the same way.
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

  -- After whatever the Space already has: the trial, Play or earlier codes.
  select greatest(now(), coalesce(max(ends_at), now())) into start_at
    from space_plans where space_id = p_space and ends_at > now();
  end_at := start_at + make_interval(months => b.months);

  update voucher_codes set redeemed_at = now(), redeemed_space_id = p_space, redeemed_by = p_user where id = c.id;
  insert into space_plans (space_id, source, frames, starts_at, ends_at, voucher_code_id)
  values (p_space, 'voucher', b.frames, start_at, end_at, c.id);
  insert into voucher_attempts (user_id, ok) values (p_user, true);

  return jsonb_build_object('ok', true, 'frames', b.frames, 'months', b.months,
    'starts_at', start_at, 'ends_at', end_at, 'from', b.card_name);
end $$;
revoke all on function redeem_voucher(text, uuid, uuid) from public, anon, authenticated;
grant execute on function redeem_voucher(text, uuid, uuid) to service_role;
