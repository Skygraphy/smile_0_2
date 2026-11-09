-- "Heute vor einem Jahr" (Ernst 2026-11-09): a Frame plays first the photos
-- and videos taken on this day in earlier years. For that a media item keeps
-- when it was taken (EXIF / video metadata, read on the phone before
-- shrinking drops it); null for everything sent before -- then the day it
-- was sent counts.
alter table media_items add column if not exists taken_at timestamptz;

-- Per Frame, on by default, next to Easy Stopping and the new-photo sound.
alter table frames add column if not exists on_this_day boolean not null default true;

-- The Frame gets the date with every item.
drop function if exists frame_media_page(uuid, bigint, int);
create function frame_media_page(p_channel uuid, p_after bigint, p_limit int)
returns table (
  media_item_id uuid,
  media_type text,
  storage_path_display text,
  storage_path_thumbnail text,
  sort_key bigint,
  sender_name text,
  caption text,
  taken_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select m.id, m.media_type, m.storage_path_display, m.storage_path_thumbnail,
         (extract(epoch from m.created_at) * 1000000)::bigint as sort_key,
         p.display_name,
         m.caption,
         coalesce(m.taken_at, m.created_at)
  from media_items m
  left join profiles p on p.user_id = m.sender_id
  where m.channel_id = p_channel
    and m.processing_status = 'ready'
    and m.storage_path_display is not null
    and (p_after is null or (extract(epoch from m.created_at) * 1000000)::bigint > p_after)
  order by m.created_at, m.id
  limit p_limit;
$$;
revoke all on function frame_media_page(uuid, bigint, int) from public, anon, authenticated;
grant execute on function frame_media_page(uuid, bigint, int) to service_role;
