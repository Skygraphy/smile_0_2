-- Titles for photos and videos (decided 2026-10-17): an optional short text
-- per item ("Schau Oma, da waren wir schon einmal ..."), written when
-- sending, changed later by the sender or the album's admins, shown in the
-- album, the phone's slideshow and on Frames. media_items.caption exists
-- since 0031; this adds the limit, the editing, the Frame side and the
-- Frame switch.

-- At most 200 characters; empty means none. NOT VALID: older rows are
-- not checked (there are none with a caption).
alter table media_items add constraint media_items_caption_length
  check (caption is null or (length(caption) between 1 and 200)) not valid;

-- Change or remove the title: the sender or someone who manages the album.
-- An empty text removes it. The update wakes phones and Frames (sync_notify).
create or replace function public.set_media_caption(p_media_item_id uuid, p_caption text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_channel uuid;
  v_sender uuid;
  v_caption text := nullif(btrim(coalesce(p_caption, '')), '');
begin
  select channel_id, sender_id into v_channel, v_sender from media_items where id = p_media_item_id;
  if v_channel is null then
    raise exception 'media_not_found' using errcode = 'P0002';
  end if;
  if v_sender <> auth.uid() and not access_manages_channel(auth.uid(), v_channel) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if v_caption is not null and length(v_caption) > 200 then
    v_caption := left(v_caption, 200);
  end if;
  update media_items set caption = v_caption where id = p_media_item_id;
end;
$$;

revoke all on function public.set_media_caption(uuid, text) from public, anon;
grant execute on function public.set_media_caption(uuid, text) to authenticated;

-- The Frame learns each item's title along with its sender.
drop function if exists frame_media_page(uuid, bigint, int);

create function frame_media_page(p_channel uuid, p_after bigint, p_limit int)
returns table (
  media_item_id uuid,
  media_type text,
  storage_path_display text,
  storage_path_thumbnail text,
  sort_key bigint,
  sender_name text,
  caption text
)
language sql stable security definer set search_path = public as $$
  select m.id, m.media_type, m.storage_path_display, m.storage_path_thumbnail,
         (extract(epoch from m.created_at) * 1000000)::bigint as sort_key,
         p.display_name,
         m.caption
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

-- "Titel anzeigen" on a Frame (on by default), and the Frame's own
-- "Titel" button from level 4 "Komfort" (controls.captions).
alter table frames add column show_captions boolean not null default true;

update frames
set controls = controls || jsonb_build_object(
  'captions',
  case
    when control_level is not null then control_level >= 4
    else coalesce((controls->>'album')::boolean, false)
  end)
where not (controls ? 'captions');

-- New Frames start on level 3: no Titel button.
alter table frames alter column controls set default
  '{"next": true, "back": true, "pause": true, "newest": true, "favorite": true, "favorites": true, "overview": false, "album": false, "duration": false, "playback": false, "captions": false}'::jsonb;
