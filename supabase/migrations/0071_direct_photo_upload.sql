-- Photos straight from the phone, no Edge Function in between (decided
-- 2026-10-10: "der Upload muss viel schneller gehen"). Each Edge Function
-- call (create-upload, complete-upload) cost ~1-1.6 s regardless of size;
-- now the phone
--   1. picks the photo's id itself and uploads the prepared photo and its
--      thumbnail straight to media-display / media-thumbnails with its own
--      session -- allowed only into albums it is a member of, only under
--      the fixed names below, never overwriting;
--   2. inserts the media_items rows as 'ready' in one request -- checked
--      here: both files must exist, be its own, and match the row;
--   3. the database announces them (push) on its own.
-- Videos and photos the phone couldn't prepare keep the old way.

-- 1. Storage: members put prepared photos into their albums -------------
drop policy if exists media_direct_insert on storage.objects;
create policy media_direct_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('media-display', 'media-thumbnails')
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}_(display|thumb)\.jpg$'
    and public.access_is_channel_member(auth.uid(), ((storage.foldername(name))[1])::uuid)
  );

-- ...and may take back their own file of a photo that didn't make it.
drop policy if exists media_direct_delete_own on storage.objects;
create policy media_direct_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('media-display', 'media-thumbnails')
    and owner_id = auth.uid()::text
    and not exists (
      select 1 from public.media_items m
      where m.storage_path_display = storage.objects.name or m.storage_path_thumbnail = storage.objects.name
    )
  );

-- 2. A 'ready' row from the phone must match its files -----------------
create or replace function check_direct_media_item()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- Service role (Edge Functions) and the classic flow ('uploaded') as before.
  if auth.uid() is null or new.processing_status is distinct from 'ready' then
    return new;
  end if;
  if new.media_type <> 'photo'
     or new.sender_id is distinct from auth.uid()
     or new.storage_path_display is distinct from new.channel_id || '/' || new.id || '_display.jpg'
     or new.storage_path_thumbnail is distinct from new.channel_id || '/' || new.id || '_thumb.jpg'
     or not exists (select 1 from storage.objects o
                    where o.bucket_id = 'media-display' and o.name = new.storage_path_display
                      and o.owner_id = auth.uid()::text)
     or not exists (select 1 from storage.objects o
                    where o.bucket_id = 'media-thumbnails' and o.name = new.storage_path_thumbnail
                      and o.owner_id = auth.uid()::text) then
    raise exception 'direct_upload_invalid' using errcode = 'P0001';
  end if;
  -- One INSERT for a whole selection: clock_timestamp() (not now(), which
  -- is the same for every row) keeps the order they were picked in.
  new.created_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists check_direct_media_item on media_items;
create trigger check_direct_media_item
  before insert on media_items
  for each row execute function check_direct_media_item();

-- 3. Announce: one push per album and statement (the batch counts itself,
-- _shared/media-fanout.ts) -------------------------------------------------
create or replace function announce_direct_media_items()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  if auth.uid() is null then
    return null;
  end if;
  for r in
    select distinct on (channel_id) channel_id, id
    from inserted
    where processing_status = 'ready'
    order by channel_id, created_at desc
  loop
    perform emit_event('media_ready', jsonb_build_object('media_item_id', r.id, 'channel_id', r.channel_id));
  end loop;
  return null;
end;
$$;

drop trigger if exists announce_direct_media_items on media_items;
create trigger announce_direct_media_items
  after insert on media_items
  referencing new table as inserted
  for each statement execute function announce_direct_media_items();
