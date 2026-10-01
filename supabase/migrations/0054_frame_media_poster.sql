-- Videos on the Frame (2026-10-01, V4): besides the playable MP4, a Frame
-- also caches each video's poster frame (made by the media worker) for its
-- grid view. frame_media_page (0049) now returns the thumbnail path too.
-- The return type changes, so the function is dropped and recreated.
drop function if exists frame_media_page(uuid, bigint, int);

create function frame_media_page(p_channel uuid, p_after bigint, p_limit int)
returns table (
  media_item_id uuid,
  media_type text,
  storage_path_display text,
  storage_path_thumbnail text,
  sort_key bigint
)
language sql stable security definer set search_path = public as $$
  select id, media_type, storage_path_display, storage_path_thumbnail,
         (extract(epoch from created_at) * 1000000)::bigint as sort_key
  from media_items
  where channel_id = p_channel
    and processing_status = 'ready'
    and storage_path_display is not null
    and (p_after is null or (extract(epoch from created_at) * 1000000)::bigint > p_after)
  order by created_at, id
  limit p_limit;
$$;

revoke all on function frame_media_page(uuid, bigint, int) from public, anon, authenticated;
grant execute on function frame_media_page(uuid, bigint, int) to service_role;
