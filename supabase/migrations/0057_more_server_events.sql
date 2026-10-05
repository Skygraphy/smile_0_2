-- "Everything interactive" (user decision 2026-10-05): four events that
-- changed things for someone without them hearing about it now raise a
-- server event, and notify-event turns each into a visible push:
--   1. request_created  -- someone asks to join an album, or to see it with
--      their own Space -> the album's managers (Admin + Co-Admins).
--   2. member_removed   -- a person left an album (-> its managers) or was
--      removed from it (-> that person).
--   3. co_admin_removed -- a Co-Admin stepped down (-> the Admin) or was
--      removed by the Admin (-> that person).
-- Same outbox path as every other event (emit_event, migrations/0048/0050).
-- Cascades (album/Space purged, account deleted) are skipped: those either
-- announce themselves or have nobody left to tell.

-- 1. A new request (never an invite: invites already push from their
-- Edge Function) ---------------------------------------------------------
create or replace function handle_request_created_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.direction = 'request' and new.status = 'pending' then
    perform emit_event('request_created', jsonb_build_object('table', tg_table_name, 'id', new.id));
  end if;
  return new;
end;
$$;

drop trigger if exists on_request_created_event on channel_membership_requests;
create trigger on_request_created_event
  after insert on channel_membership_requests
  for each row execute function handle_request_created_event();
drop trigger if exists on_request_created_event on channel_share_requests;
create trigger on_request_created_event
  after insert on channel_share_requests
  for each row execute function handle_request_created_event();

-- 2. Someone is no longer a member of an album -----------------------------
create or replace function handle_member_removed_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from channels where id = old.channel_id and deleted_at is null)
     and exists (select 1 from auth.users where id = old.user_id) then
    perform emit_event('member_removed', jsonb_build_object(
      'channel_id', old.channel_id, 'user_id', old.user_id, 'actor_id', auth.uid()));
  end if;
  return old;
end;
$$;

drop trigger if exists on_member_removed_event on channel_members;
create trigger on_member_removed_event
  after delete on channel_members
  for each row execute function handle_member_removed_event();

-- 3. Someone is no longer a Co-Admin of a Space ----------------------------
create or replace function handle_co_admin_removed_event()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from spaces where id = old.space_id and deleted_at is null)
     and exists (select 1 from auth.users where id = old.user_id) then
    perform emit_event('co_admin_removed', jsonb_build_object(
      'space_id', old.space_id, 'user_id', old.user_id, 'actor_id', auth.uid()));
  end if;
  return old;
end;
$$;

drop trigger if exists on_co_admin_removed_event on space_co_owners;
create trigger on_co_admin_removed_event
  after delete on space_co_owners
  for each row execute function handle_co_admin_removed_event();
