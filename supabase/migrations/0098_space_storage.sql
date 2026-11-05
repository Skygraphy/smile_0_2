-- What a Space holds (2026-11-05): for its Admin and Co-Admins on the
-- Space page ("Belegt 1,2 GB von 10 GB"), and for the health check's soft
-- 8 GB hint. Nothing is ever blocked by it.
create or replace function space_storage(p_space uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when not is_space_owner(p_space) then null else jsonb_build_object(
    'bytes', coalesce(sum(m.file_size_bytes), 0),
    'photos', count(*) filter (where m.media_type = 'photo'),
    'videos', count(*) filter (where m.media_type = 'video')
  ) end
  from media_items m join channels c on c.id = m.channel_id
  where c.space_id = p_space and m.processing_status = 'ready';
$$;
revoke all on function space_storage(uuid) from public, anon;
grant execute on function space_storage(uuid) to authenticated;
