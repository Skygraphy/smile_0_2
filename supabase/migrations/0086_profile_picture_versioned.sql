-- A changed profile picture kept showing the old one (test suite, chapter 1,
-- 2026-10-20): every upload went to the same file users/<id>, so phones
-- showed the copy they had cached under that address. Like the pictures of
-- Spaces, albums and Frames (0066/0067), each upload now gets its own file
-- users/<id>/<time>; the database removes the previous one.

-- The own folder may be written too (the old single file stays allowed for
-- app versions that still use it).
drop policy if exists avatars_user_write on storage.objects;
create policy avatars_user_write on storage.objects
  for all using (
    bucket_id = 'avatars'
    and (name = 'users/' || auth.uid()::text or name like 'users/' || auth.uid()::text || '/%')
  )
  with check (
    bucket_id = 'avatars'
    and (name = 'users/' || auth.uid()::text or name like 'users/' || auth.uid()::text || '/%')
  );

-- The previous file goes when the picture changes or is removed (a deleted
-- profile is handled by on_profiles_deleted_remove_avatar, 0062).
drop trigger if exists on_profile_picture_file on profiles;
create trigger on_profile_picture_file
  after update of avatar_path on profiles
  for each row execute function queue_object_picture_removal();
