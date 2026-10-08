-- 0066's storage policy denied every Frame picture upload ("new row violates
-- row-level security policy"): its frames branch queried public.frames
-- directly inside a storage.objects policy, where the caller's RLS on frames
-- and storage's search_path apply. A SECURITY DEFINER helper with a fixed
-- search_path answers the question the same way the spaces and channels
-- branches already do; all names are schema-qualified.

create or replace function public.can_manage_frame(p_frame uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from frames f where f.id = p_frame and access_manages_space(auth.uid(), f.space_id)
  );
$$;

drop policy if exists avatars_object_managers_write on storage.objects;
create policy avatars_object_managers_write on storage.objects
  for all
  using (
    bucket_id = 'avatars' and (
      ((storage.foldername(name))[1] = 'spaces' and public.is_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'channels' and public.is_home_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'frames' and public.can_manage_frame(((storage.foldername(name))[2])::uuid))
    )
  )
  with check (
    bucket_id = 'avatars' and (
      ((storage.foldername(name))[1] = 'spaces' and public.is_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'channels' and public.is_home_space_owner(((storage.foldername(name))[2])::uuid))
      or ((storage.foldername(name))[1] = 'frames' and public.can_manage_frame(((storage.foldername(name))[2])::uuid))
    )
  );
