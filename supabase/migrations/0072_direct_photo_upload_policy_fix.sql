-- 0071's storage policy called access_is_channel_member(), which signed-in
-- users may not execute (revoked in 0047) -- every direct upload was
-- refused. is_channel_member() is the one meant for policies (it asks for
-- auth.uid() itself).
drop policy if exists media_direct_insert on storage.objects;
create policy media_direct_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('media-display', 'media-thumbnails')
    and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}_(display|thumb)\.jpg$'
    and public.is_channel_member(((storage.foldername(name))[1])::uuid)
  );
