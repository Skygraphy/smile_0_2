-- Decision 2026-09-29 (architecture review, weakness 1): a share belongs to
-- the whole viewing household -- a new co-owner there sees shared-in
-- channels automatically -- BUT
--   (a) the channel's own side is told when that happens, and
--   (b) the channel's own side can end the share itself.
-- Until now only the viewing side could delete a channel_shares row, so
-- once Ernst had shared "Enkelkinder" with Davidopa, it stayed visible
-- there for as long as Davidopa wanted.

-- (b) The home Space's Administrator/co-owners may end a share too. The
-- viewing side keeps its unconditional right to walk away.
drop policy channel_shares_owner_delete on channel_shares;
create policy channel_shares_owner_delete on channel_shares
  for delete using (is_space_owner(space_id) or is_home_space_owner(channel_id) or is_staff());

-- (a) Server-side events. One place that hands a human-facing event to the
-- notify-event Edge Function via pg_net -- the visible-notification
-- counterpart of sync_notify()'s silent sync (0041). Same Vault secret as
-- sync-fanout; the URL is derived from sync_fanout_url so no second secret
-- has to be set up. Like sync_notify, it must never fail the write.
create or replace function emit_event(kind text, payload jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_url text;
  v_secret text;
begin
  select replace(decrypted_secret, '/sync-fanout', '/notify-event') into v_url
    from vault.decrypted_secrets where name = 'sync_fanout_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'sync_fanout_secret';
  if v_url is null or v_secret is null then
    return;
  end if;
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object('kind', kind, 'payload', payload),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-sync-secret', v_secret),
    timeout_milliseconds := 5000
  );
exception when others then
  raise warning 'emit_event(%) failed: %', kind, sqlerrm;
end;
$$;

-- A household with shares gained a co-owner -> every channel shared into
-- it has a new viewer; notify-event tells those channels' own side.
create or replace function handle_co_owner_added_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from channel_shares where space_id = new.space_id) then
    perform emit_event('co_owner_added', jsonb_build_object('space_id', new.space_id, 'user_id', new.user_id));
  end if;
  return new;
end;
$$;

drop trigger if exists on_co_owner_added_event on space_co_owners;
create trigger on_co_owner_added_event
  after insert on space_co_owners
  for each row execute function handle_co_owner_added_event();

-- A share ended by either side -> the other side is told. Skipped when the
-- channel or the Space itself is going away (a cascade): that deletion
-- announces itself.
create or replace function handle_share_ended_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from channels where id = old.channel_id)
     and exists (select 1 from spaces where id = old.space_id) then
    perform emit_event('share_ended', jsonb_build_object(
      'channel_id', old.channel_id, 'space_id', old.space_id, 'actor_id', auth.uid()));
  end if;
  return old;
end;
$$;

drop trigger if exists on_share_ended_event on channel_shares;
create trigger on_share_ended_event
  after delete on channel_shares
  for each row execute function handle_share_ended_event();
