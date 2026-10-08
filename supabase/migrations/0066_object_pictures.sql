-- Own pictures for Space, Album and Frame (decided 2026-10-08, preview
-- "Eigene Bilder"): like a person's profile picture, set by the object's
-- managers (Admin + Co-Admins) via a camera badge; an album can also take
-- one of its own photos as cover ("Als Titelbild"). Without one, lists keep
-- showing the automatic picture (newest photo / two letters).
--
-- Files live in the existing public `avatars` bucket under
-- spaces/<id>/<stamp>, channels/<id>/<stamp>, frames/<id>/<stamp> -- a new
-- name per upload, so no device keeps showing a cached old picture; the old
-- file is removed by trigger (no leftovers), as is the file of a deleted
-- object. Every change pushes to the people affected (notify-event
-- 'picture_changed').

alter table spaces add column avatar_path text;
alter table frames add column avatar_path text;
-- An album's cover is either an uploaded picture or one of its photos;
-- setting one clears the other (the app writes both columns together).
alter table channels add column cover_path text;
alter table channels add column cover_media_id uuid references media_items(id) on delete set null;

-- Managers may write their objects' pictures --------------------------------
drop policy if exists avatars_object_managers_write on storage.objects;
create policy avatars_object_managers_write on storage.objects
  for all
  using (
    bucket_id = 'avatars' and (
      ((storage.foldername(name))[1] = 'spaces' and is_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'channels' and is_home_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'frames' and exists (
            select 1 from frames f where f.id = ((storage.foldername(name))[2])::uuid and is_space_owner(f.space_id)))
    )
  )
  with check (
    bucket_id = 'avatars' and (
      ((storage.foldername(name))[1] = 'spaces' and is_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'channels' and is_home_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'frames' and exists (
            select 1 from frames f where f.id = ((storage.foldername(name))[2])::uuid and is_space_owner(f.space_id)))
    )
  );

-- Old / orphaned picture files go -------------------------------------------
create or replace function queue_object_picture_removal()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_old text;
  v_new text;
begin
  v_old := case tg_table_name when 'channels' then old.cover_path else old.avatar_path end;
  v_new := case when tg_op = 'DELETE' then null
                when tg_table_name = 'channels' then new.cover_path else new.avatar_path end;
  if v_old is not null and v_old is distinct from v_new then
    perform invoke_internal('remove-storage-files', jsonb_build_object(
      'files', jsonb_build_array(jsonb_build_object('bucket', 'avatars', 'path', v_old))));
  end if;
  return null;
end;
$$;

drop trigger if exists on_space_picture_file on spaces;
create trigger on_space_picture_file after update or delete on spaces
  for each row execute function queue_object_picture_removal();
drop trigger if exists on_channel_picture_file on channels;
create trigger on_channel_picture_file after update or delete on channels
  for each row execute function queue_object_picture_removal();
drop trigger if exists on_frame_picture_file on frames;
create trigger on_frame_picture_file after update or delete on frames
  for each row execute function queue_object_picture_removal();

-- Tell the people affected ----------------------------------------------------
create or replace function handle_picture_changed_event()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_changed boolean;
  v_removed boolean;
begin
  if auth.uid() is null then
    return new;
  end if;
  if tg_table_name = 'channels' then
    v_changed := new.cover_path is distinct from old.cover_path or new.cover_media_id is distinct from old.cover_media_id;
    v_removed := new.cover_path is null and new.cover_media_id is null;
  else
    v_changed := new.avatar_path is distinct from old.avatar_path;
    v_removed := new.avatar_path is null;
  end if;
  if v_changed then
    perform emit_event('picture_changed', jsonb_build_object(
      'kind', case tg_table_name when 'spaces' then 'space' when 'channels' then 'album' else 'frame' end,
      'id', new.id, 'actor_id', auth.uid(), 'removed', v_removed));
  end if;
  return new;
end;
$$;

drop trigger if exists on_space_picture_changed on spaces;
create trigger on_space_picture_changed after update on spaces
  for each row execute function handle_picture_changed_event();
drop trigger if exists on_channel_picture_changed on channels;
create trigger on_channel_picture_changed after update on channels
  for each row execute function handle_picture_changed_event();
drop trigger if exists on_frame_picture_changed on frames;
create trigger on_frame_picture_changed after update on frames
  for each row execute function handle_picture_changed_event();
