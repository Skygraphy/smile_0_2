-- "Niemals Leichen" (user decision 2026-10-06): whatever is deleted, on
-- whatever path, leaves nothing behind. Decisions: deleting an account
-- removes everything of that person; the 30-day trash stays (a deliberate
-- way back, not a leftover); unanswered invites/requests expire after 30
-- days.
--
-- 1. Files follow their rows. Storage doesn't cascade: a photo row deleted
--    by a cascade (album/Space purged, account deleted) used to leave its
--    three files behind. Now every media_items / profiles delete, however it
--    happens, queues its files for removal (outbox -> remove-storage-files).
--    The explicit removals in delete-media/purge-trash stay; removing an
--    already removed file is a no-op.
-- 2. A Frame that was created but never paired is gone once its pairing
--    code expired (hourly).
-- 3. Invites/requests nobody answered within 30 days expire (daily,
--    expire-requests tells the side that is waiting).

-- 1. Files ----------------------------------------------------------------
create or replace function queue_media_file_removal()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_files jsonb;
begin
  select coalesce(jsonb_agg(f), '[]'::jsonb) into v_files from (
    select jsonb_build_object('bucket', 'media-originals', 'path', o.storage_path_original) as f
      from old_rows o where o.storage_path_original is not null
    union all
    select jsonb_build_object('bucket', 'media-display', 'path', o.storage_path_display)
      from old_rows o where o.storage_path_display is not null
    union all
    select jsonb_build_object('bucket', 'media-thumbnails', 'path', o.storage_path_thumbnail)
      from old_rows o where o.storage_path_thumbnail is not null
  ) s;
  if jsonb_array_length(v_files) > 0 then
    perform invoke_internal('remove-storage-files', jsonb_build_object('files', v_files));
  end if;
  return null;
end;
$$;

drop trigger if exists on_media_items_deleted_remove_files on media_items;
create trigger on_media_items_deleted_remove_files
  after delete on media_items referencing old table as old_rows
  for each statement execute function queue_media_file_removal();

create or replace function queue_avatar_file_removal()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_files jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object('bucket', 'avatars', 'path', o.avatar_path)), '[]'::jsonb)
    into v_files
    from old_rows o where o.avatar_path is not null;
  if jsonb_array_length(v_files) > 0 then
    perform invoke_internal('remove-storage-files', jsonb_build_object('files', v_files));
  end if;
  return null;
end;
$$;

drop trigger if exists on_profiles_deleted_remove_avatar on profiles;
create trigger on_profiles_deleted_remove_avatar
  after delete on profiles referencing old table as old_rows
  for each statement execute function queue_avatar_file_removal();

-- 2. Frames that were never paired --------------------------------------------
select cron.schedule(
  'smile-purge-unpaired-frames',
  '7 * * * *',
  $cron$delete from frames where lifecycle_state = 'pending' and pairing_code_expires_at < now()$cron$
);

-- 3. Unanswered invites / requests ---------------------------------------------
select cron.schedule(
  'smile-expire-requests',
  '37 3 * * *',
  $cron$select invoke_internal('expire-requests', '{}'::jsonb)$cron$
);
