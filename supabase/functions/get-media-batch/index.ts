// The kiosk sync endpoint. Unauthenticated at the gateway level
// (--no-verify-jwt) -- the Frame presents its own access token in the
// body, verified here with our own HS256 secret (see _shared/frame-jwt.ts
// and migrations/0031_architecture_reset.sql's header comment on why
// Frames never hit PostgREST/RLS directly any more). Re-checks
// lifecycle_state and credential_version against the DB on every call --
// a still-unexpired token from before a credential rotation (or a revoked
// Frame) is rejected here.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { verifyFrameAccessToken } from "../_shared/frame-jwt.ts";
import { frameSettings } from "../_shared/frame-settings.ts";
import { spaceManagerIds } from "../_shared/space-access.ts";
import { frameAdminIds } from "../_shared/frame-admin.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const SIGNED_URL_TTL_SECONDS = 60 * 60;
const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 200;

interface RequestBody {
  access_token: string;
  // The album of the pages being continued (with cursor); on a first page
  // only from Frame builds older than migrations/0069 (their local pick).
  channel_id?: string;
  // A switch made on the Frame itself (Personal Mode) -- stored as the
  // Frame's current album (0069).
  select_channel_id?: string;
  // Any other album of this Frame, fetched for the offline cache only --
  // doesn't change what the Frame shows (2026-10-09: all albums cached).
  fetch_channel_id?: string;
  cursor?: number;
  limit?: number;
  fcm_token?: string;
  battery_level?: number;
  is_charging?: boolean;
  // A change made on the Frame itself (2026-10-14) -- only what its
  // controls allow: "duration" the display time, "playback" the rest.
  set_settings?: Record<string, unknown>;
  // A Lieblingsbild marked (on: true) or taken back on the Frame (0076).
  favorite?: { media_item_id: string; on: boolean };
  // The round the Frame plays right now (0077): "newest", "favorites" or
  // null for none -- only sent when it changed.
  playing_round?: string | null;
  // Unlocked on the Frame with its code (Kindersperre, migrations/0089):
  // the code's hash -- then every control counts as allowed.
  unlock_proof?: string;
  // The tablet was just switched on (Frame app start soon after boot).
  just_booted?: boolean;
}

const FRAME_COLUMNS =
  "id, lifecycle_state, space_id, display_mode, slideshow_interval_seconds, channel_switch_enabled, video_sound, " +
  "max_local_cache_gb, current_channel_id, control_level, controls, content_mode, recent_count, play_order, " +
  "end_behavior, show_new_immediately, show_clock, show_sender, quiet_from, quiet_to, playing_round, video_length, fill_mode, slow_zoom, rotate_with_device, show_captions, unlock_code_hash, new_sound, new_sound_reminder, new_hint, easy_stop, pause_zoom, on_this_day, language, spaces(name, deleted_at)";

// What the Frame may change itself, by the control that allows it, and
// what each value may be.
const SETTABLE: Record<string, { control: string; ok: (v: unknown) => boolean }> = {
  slideshow_interval_seconds: { control: "duration", ok: (v) => typeof v === "number" && v >= 3 && v <= 600 },
  play_order: { control: "playback", ok: (v) => ["newest", "oldest", "shuffle"].includes(v as string) },
  end_behavior: { control: "playback", ok: (v) => ["loop", "overview"].includes(v as string) },
  content_mode: { control: "playback", ok: (v) => ["album", "rotate", "recent", "favorites"].includes(v as string) },
  video_sound: { control: "playback", ok: (v) => typeof v === "boolean" },
  show_clock: { control: "playback", ok: (v) => typeof v === "boolean" },
  show_sender: { control: "playback", ok: (v) => typeof v === "boolean" },
  video_length: { control: "playback", ok: (v) => ["full", "photo", "none"].includes(v as string) },
  fill_mode: { control: "playback", ok: (v) => ["fit", "auto", "fill"].includes(v as string) },
  slow_zoom: { control: "playback", ok: (v) => typeof v === "boolean" },
  // 2026-10-17: the rest of the playback settings on level 5 too.
  recent_count: { control: "playback", ok: (v) => Number.isInteger(v) && (v as number) >= 5 && (v as number) <= 500 },
  show_new_immediately: { control: "playback", ok: (v) => typeof v === "boolean" },
  rotate_with_device: { control: "playback", ok: (v) => typeof v === "boolean" },
  quiet_from: { control: "playback", ok: (v) => v === null || (typeof v === "string" && /^\d{2}:\d{2}(:\d{2})?$/.test(v)) },
  quiet_to: { control: "playback", ok: (v) => v === null || (typeof v === "string" && /^\d{2}:\d{2}(:\d{2})?$/.test(v)) },
  // The Frame's own "Titel" button (level 4) -- and on level 5 in Wiedergabe.
  show_captions: { control: "captions", ok: (v) => typeof v === "boolean" },
  // Noticing new photos (migrations/0093) -- in Wiedergabe on level 5.
  new_sound: { control: "playback", ok: (v) => typeof v === "boolean" },
  new_sound_reminder: { control: "playback", ok: (v) => typeof v === "boolean" },
  new_hint: { control: "playback", ok: (v) => typeof v === "boolean" },
  pause_zoom: { control: "playback", ok: (v) => typeof v === "boolean" },
  on_this_day: { control: "playback", ok: (v) => typeof v === "boolean" },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.access_token) return jsonResponse({ error: "access_token_required" }, 400);

  let claims;
  try {
    claims = await verifyFrameAccessToken(body.access_token);
  } catch {
    return jsonResponse({ error: "invalid_or_expired_token" }, 401);
  }

  // deno-lint-ignore no-explicit-any
  let { data: frame } = await supabase.from("frames").select(FRAME_COLUMNS).eq("id", claims.frame_id).maybeSingle() as { data: any };
  // Deleted (its Space was deleted) vs. merely revoked: a deleted Frame
  // has to go back to pairing, a revoked one just waits to be reactivated.
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 403);
  // Revoked, or its whole Space is in the trash (migrations/0048): the
  // Frame wipes its photos and waits -- a restore brings it straight back.
  // deno-lint-ignore no-explicit-any
  if (frame.lifecycle_state !== "active" || (frame.spaces as any)?.deleted_at) {
    return jsonResponse({ error: "frame_not_active" }, 403);
  }
  // deno-lint-ignore no-explicit-any
  const spaceName = (frame.spaces as any)?.name ?? null;

  const { data: credentials } = await supabase
    .from("frame_credentials")
    .select("refresh_secret_version")
    .eq("frame_id", claims.frame_id)
    .maybeSingle();
  if (!credentials || credentials.refresh_secret_version !== claims.credential_version) {
    return jsonResponse({ error: "stale_credential_version" }, 401);
  }

  // A change made on the Frame: only what its controls allow, the rest is
  // ignored. Saved before answering, so the answer already carries it.
  const unlocked = !!frame.unlock_code_hash && body.unlock_proof === frame.unlock_code_hash;
  const allowed = (control: string) => unlocked || ((frame.controls ?? {}) as Record<string, boolean>)[control] === true;
  if (body.set_settings && typeof body.set_settings === "object") {
    const update: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(body.set_settings)) {
      const rule = SETTABLE[key];
      if (rule && allowed(rule.control) && rule.ok(value)) update[key] = value;
    }
    if (Object.keys(update).length > 0) {
      await supabase.from("frames").update(update).eq("id", claims.frame_id);
      frame = { ...frame, ...update };
    }
  }

  const settings = frameSettings(frame);

  if (body.fcm_token || body.battery_level !== undefined || body.is_charging !== undefined) {
    await supabase
      .from("frames")
      .update({
        ...(body.fcm_token ? { fcm_token: body.fcm_token } : {}),
        ...(body.battery_level !== undefined ? { battery_level: body.battery_level } : {}),
        ...(body.is_charging !== undefined ? { is_charging: body.is_charging } : {}),
        last_seen_at: new Date().toISOString(),
      })
      .eq("id", claims.frame_id);
  }

  // Computed live on every poll (migrations/0049) -- no stored per-Frame
  // copy to keep in step: the assigned channels the household can see
  // right now (trash, revoked shares and all, via the single source), and
  // the ready photos in the chosen one.
  const { data: visibleRows, error: visibleError } = await supabase.rpc("frame_visible_channels", { p_frame: claims.frame_id });
  if (visibleError) return jsonResponse({ error: "fetch_failed" }, 500);
  let assignedChannels = (visibleRows ?? []).map((r: { channel_id: string; name: string; sort_order: number }) => ({
    channel_id: r.channel_id,
    name: r.name,
    sort_order: r.sort_order,
  }));

  const isAssigned = (id: string | null | undefined) =>
    !!id && assignedChannels.some((a: { channel_id: string }) => a.channel_id === id);

  // Which album (migrations/0069): a switch on the Frame itself, else the
  // album of the pages being continued, else the server's current album
  // (set from the app or by an earlier switch), else an old Frame build's
  // local pick, else the first album.
  const firstPage = body.cursor === undefined || body.cursor === null;

  // "Frame läuft wieder" (2026-11-05): just switched on again -> its
  // managers and Frame-Admins hear so, with the hint to pin it again.
  if (firstPage && body.just_booted === true) {
    const { data: row } = await supabase
      .from("frames")
      .select("name, space_id, boot_notice_at, spaces(name)")
      .eq("id", claims.frame_id)
      .maybeSingle();
    const last = row?.boot_notice_at ? new Date(row.boot_notice_at as string).getTime() : 0;
    if (row && Date.now() - last > 30 * 60 * 1000) {
      await supabase.from("frames").update({ boot_notice_at: new Date().toISOString() }).eq("id", claims.frame_id);
      const [managers, admins] = await Promise.all([
        spaceManagerIds(supabase, row.space_id as string),
        frameAdminIds(supabase, claims.frame_id),
      ]);
      // deno-lint-ignore no-explicit-any
      const spaceName = (row.spaces as any)?.name ?? "";
      await pushNotificationToUsers(
        supabase,
        [...new Set([...managers, ...admins])],
        (t) => t.frameRunsAgain({ frame: row.name as string }),
        { type: "frame_changed", space_id: row.space_id as string, space_name: spaceName, frame_name: row.name as string },
      );
    }
  }
  let channelId: string | undefined;
  if (body.fetch_channel_id) {
    if (!isAssigned(body.fetch_channel_id)) return jsonResponse({ error: "frame_not_assigned_to_channel" }, 403);
    channelId = body.fetch_channel_id;
  } else if (body.select_channel_id) {
    if (!isAssigned(body.select_channel_id)) return jsonResponse({ error: "frame_not_assigned_to_channel" }, 403);
    channelId = body.select_channel_id;
  } else if (!firstPage && body.channel_id) {
    channelId = body.channel_id;
  } else if (isAssigned(frame.current_channel_id)) {
    channelId = frame.current_channel_id as string;
  } else if (isAssigned(body.channel_id)) {
    channelId = body.channel_id;
  } else {
    channelId = assignedChannels[0]?.channel_id;
  }
  // Remember what the Frame shows, so the app can show it too. Only on a
  // first page: a continued page may still be the album from before a
  // switch made meanwhile in the app.
  if (!body.fetch_channel_id && firstPage && (channelId ?? null) !== (frame.current_channel_id ?? null)) {
    let update = supabase.from("frames").update({ current_channel_id: channelId ?? null }).eq("id", claims.frame_id);
    // Only over what was read above, unless picked on the Frame itself: an
    // album set meanwhile in the app wins (Fund 34, 2026-10-26: a Frame
    // pairing while Anna added albums and tapped Jetzt zeigen wrote its
    // first album over hers).
    if (!body.select_channel_id) {
      update = frame.current_channel_id == null
        ? update.is("current_channel_id", null)
        : update.eq("current_channel_id", frame.current_channel_id);
    }
    const { data: updated } = await update.select("id");
    if ((updated ?? []).length === 0) {
      const { data: fresh } = await supabase.from("frames").select("current_channel_id").eq("id", claims.frame_id).maybeSingle();
      const { data: freshRows } = await supabase.rpc("frame_visible_channels", { p_frame: claims.frame_id });
      const freshChannels = (freshRows ?? []).map((r: { channel_id: string; name: string; sort_order: number }) => ({
        channel_id: r.channel_id,
        name: r.name,
        sort_order: r.sort_order,
      }));
      if (fresh?.current_channel_id && freshChannels.some((a: { channel_id: string }) => a.channel_id === fresh.current_channel_id)) {
        assignedChannels = freshChannels;
        channelId = fresh.current_channel_id as string;
      }
    }
  }
  // Picking an album on the Frame means: show this one (2026-10-14) -- also
  // when it played all albums in turn or the newest.
  if (body.select_channel_id && frame.content_mode !== "album" && allowed("album")) {
    await supabase.from("frames").update({ content_mode: "album" }).eq("id", claims.frame_id);
    settings.content_mode = "album";
  }

  // What it plays right now beyond its settings (0077), for the app.
  if ("playing_round" in body && firstPage && !body.fetch_channel_id) {
    const round = body.playing_round === "newest" || body.playing_round === "favorites" ? body.playing_round : null;
    if (round !== (frame.playing_round ?? null)) {
      await supabase.from("frames").update({ playing_round: round }).eq("id", claims.frame_id);
    }
  }

  // Lieblingsbilder (migrations/0076): marked on the Frame -- only when its
  // controls allow it, and only photos of its own albums. The list goes
  // with every first page (the Frame filters by what it has cached).
  let favorites: string[] | undefined;
  if (firstPage && !body.fetch_channel_id) {
    const mark = body.favorite;
    if (mark && typeof mark.media_item_id === "string" && allowed("favorite")) {
      if (mark.on) {
        const { data: media } = await supabase
          .from("media_items")
          // No channels(...) embed here: media_items reaches channels twice
          // (channel_id and channels.cover_media_id), so it is ambiguous and
          // the whole read fails -- the mark was lost (2026-11-05).
          .select("channel_id, sender_id, media_type")
          .eq("id", mark.media_item_id)
          .maybeSingle();
        if (media && isAssigned(media.channel_id)) {
          const { data: added } = await supabase
            .from("frame_favorites")
            .upsert({ frame_id: claims.frame_id, media_item_id: mark.media_item_id, added_by: null }, {
              onConflict: "frame_id,media_item_id",
              ignoreDuplicates: true,
            })
            .select("frame_id");
          // Marked on the Frame for the first time: whoever sent it hears so
          // (2026-11-05) -- the Frame's way to say "I like this one".
          if ((added ?? []).length > 0 && media.sender_id) {
            const [{ data: frameRow }, { data: channelRow }] = await Promise.all([
              supabase.from("frames").select("name").eq("id", claims.frame_id).maybeSingle(),
              supabase.from("channels").select("name").eq("id", media.channel_id).maybeSingle(),
            ]);
            const channelName = (channelRow?.name as string | undefined) ?? "";
            await pushNotificationToUsers(
              supabase,
              [media.sender_id as string],
              (t) => t.frameFavorite({ frame: (frameRow?.name as string | undefined) ?? null, video: media.media_type === "video", album: channelName }),
              { type: "frame_favorite", channel_id: media.channel_id as string, channel_name: channelName },
            );
          }
        }
      } else {
        await supabase.from("frame_favorites").delete().eq("frame_id", claims.frame_id).eq(
          "media_item_id",
          mark.media_item_id,
        );
      }
    }
    const { data: favoriteRows } = await supabase
      .from("frame_favorites")
      .select("media_item_id")
      .eq("frame_id", claims.frame_id)
      .order("created_at", { ascending: false });
    favorites = (favoriteRows ?? []).map((r: { media_item_id: string }) => r.media_item_id);
  }

  if (!channelId) {
    return jsonResponse({
      channel_id: null,
      items: [],
      next_cursor: null,
      settings,
      assigned_channels: assignedChannels,
      space_name: spaceName,
      favorites,
    });
  }

  if (!assignedChannels.some((a: { channel_id: string }) => a.channel_id === channelId)) {
    return jsonResponse({ error: "frame_not_assigned_to_channel" }, 403);
  }

  const limit = Math.min(Math.max(body.limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);
  // Frame subscription (2026-11-11, migrations/0102): without cover the
  // Frame keeps what it has and gets nothing uploaded after the cut-off.
  const { data: until } = await supabase.rpc("frame_photos_until", { p_frame: claims.frame_id });
  const { data: page, error: pageError } = await supabase.rpc("frame_media_page", {
    p_channel: channelId,
    p_after: body.cursor ?? null,
    p_limit: limit,
    p_until: until ?? null,
  });
  if (pageError) return jsonResponse({ error: "fetch_failed" }, 500);
  const rows = (page ?? []) as {
    media_item_id: string;
    media_type: string;
    storage_path_display: string;
    storage_path_thumbnail: string | null;
    sort_key: number;
    sender_name: string | null;
    caption: string | null;
    taken_at: string | null;
  }[];

  // Signed in one call per bucket instead of one per photo: with every
  // album of a Frame synced (2026-10-09), per-photo calls made a sync slow.
  const signAll = async (bucket: string, paths: string[]) => {
    const urls = new Map<string, string>();
    if (paths.length === 0) return urls;
    const { data } = await supabase.storage.from(bucket).createSignedUrls(paths, SIGNED_URL_TTL_SECONDS);
    for (const entry of data ?? []) {
      if (entry.path && entry.signedUrl) urls.set(entry.path, entry.signedUrl);
    }
    return urls;
  };
  const displayUrls = await signAll("media-display", rows.map((r) => r.storage_path_display));
  // A video's display file is the MP4; its poster frame is what the
  // Frame's grid view shows (0054).
  const posterUrls = await signAll(
    "media-thumbnails",
    rows.filter((r) => r.media_type === "video" && r.storage_path_thumbnail).map((r) => r.storage_path_thumbnail as string),
  );
  const items = rows.map((row) => ({
    media_item_id: row.media_item_id,
    media_type: row.media_type,
    sort_order: row.sort_key,
    sender_name: row.sender_name ?? null,
    caption: row.caption ?? null,
    // When it was taken, else sent ("Heute vor einem Jahr", 0100).
    taken_at: row.taken_at ?? null,
    display_url: displayUrls.get(row.storage_path_display) ?? null,
    poster_url: row.media_type === "video" && row.storage_path_thumbnail
      ? posterUrls.get(row.storage_path_thumbnail) ?? null
      : null,
  }));
  const nextCursor = rows.length === limit ? rows[rows.length - 1].sort_key : null;

  return jsonResponse({
    channel_id: channelId,
    items,
    next_cursor: nextCursor,
    settings,
    assigned_channels: assignedChannels,
    space_name: spaceName,
    favorites,
  });
});
