-- Frame control levels and playback settings (decided with the user
-- 2026-10-14, preview "Frame-Bedienstufen"). The app always controls a
-- Frame completely; the level only decides which big buttons the person in
-- front of it gets:
--   1 Nur zuschauen  -- nothing, touches are ignored
--   2 Blättern       -- next, pause
--   3 Einfach        -- + back, newest photos
--   4 Komfort        -- + overview, switch album, display time
--   5 Alles selbst   -- + all playback settings on the Frame itself
-- control_level null = "Eigene Auswahl": a single switch was changed.
-- `controls` always holds the effective switches (the Frame only reads
-- those); channel_switch_enabled stays in step with controls.album for the
-- code that already reads it.

alter table frames
  add column if not exists control_level int check (control_level between 1 and 5),
  add column if not exists controls jsonb not null default
    '{"next": true, "back": true, "pause": true, "newest": true, "overview": false, "album": false, "duration": false, "playback": false}'::jsonb,
  -- What it plays: one album, all its albums in turn, or the newest photos
  -- of all its albums.
  add column if not exists content_mode text not null default 'album'
    check (content_mode in ('album', 'rotate', 'recent')),
  add column if not exists recent_count int not null default 20 check (recent_count between 5 and 500),
  add column if not exists play_order text not null default 'oldest'
    check (play_order in ('newest', 'oldest', 'shuffle')),
  add column if not exists end_behavior text not null default 'loop'
    check (end_behavior in ('loop', 'overview')),
  add column if not exists show_new_immediately boolean not null default true,
  add column if not exists show_clock boolean not null default false,
  add column if not exists show_sender boolean not null default true,
  -- Nachtruhe: dark between these times (Frame's local time); both null = off.
  add column if not exists quiet_from time,
  add column if not exists quiet_to time;

alter table frames alter column control_level set default 3;

-- Existing Frames: level 4 where switching albums was allowed (it showed
-- the overview button too), else level 3.
update frames set
  control_level = case when channel_switch_enabled then 4 else 3 end,
  controls = case when channel_switch_enabled then
    '{"next": true, "back": true, "pause": true, "newest": true, "overview": true, "album": true, "duration": true, "playback": false}'::jsonb
  else
    '{"next": true, "back": true, "pause": true, "newest": true, "overview": false, "album": false, "duration": false, "playback": false}'::jsonb
  end
where control_level is null;

-- Who sent each photo, for "Neu von Roman" and the sender caption on the
-- Frame. The return type changes, so the function is dropped and recreated.
drop function if exists frame_media_page(uuid, bigint, int);

create function frame_media_page(p_channel uuid, p_after bigint, p_limit int)
returns table (
  media_item_id uuid,
  media_type text,
  storage_path_display text,
  storage_path_thumbnail text,
  sort_key bigint,
  sender_name text
)
language sql stable security definer set search_path = public as $$
  select m.id, m.media_type, m.storage_path_display, m.storage_path_thumbnail,
         (extract(epoch from m.created_at) * 1000000)::bigint as sort_key,
         p.display_name
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
