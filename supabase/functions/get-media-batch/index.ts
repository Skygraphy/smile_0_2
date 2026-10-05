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

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const SIGNED_URL_TTL_SECONDS = 60 * 60;
const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 200;

interface RequestBody {
  access_token: string;
  channel_id?: string;
  cursor?: number;
  limit?: number;
  fcm_token?: string;
  battery_level?: number;
  is_charging?: boolean;
}

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

  const { data: frame } = await supabase
    .from("frames")
    .select("id, lifecycle_state, space_id, display_mode, slideshow_interval_seconds, channel_switch_enabled, video_sound, max_local_cache_gb, spaces(name, deleted_at)")
    .eq("id", claims.frame_id)
    .maybeSingle();
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
  const settings = {
    display_mode: frame.display_mode,
    slideshow_interval_seconds: frame.slideshow_interval_seconds,
    channel_switch_enabled: frame.channel_switch_enabled,
    video_sound: frame.video_sound,
    max_local_cache_gb: frame.max_local_cache_gb,
  };

  const { data: credentials } = await supabase
    .from("frame_credentials")
    .select("refresh_secret_version")
    .eq("frame_id", claims.frame_id)
    .maybeSingle();
  if (!credentials || credentials.refresh_secret_version !== claims.credential_version) {
    return jsonResponse({ error: "stale_credential_version" }, 401);
  }

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
  const assignedChannels = (visibleRows ?? []).map((r: { channel_id: string; name: string; sort_order: number }) => ({
    channel_id: r.channel_id,
    name: r.name,
    sort_order: r.sort_order,
  }));

  let channelId = body.channel_id;
  if (!channelId) channelId = assignedChannels[0]?.channel_id;

  if (!channelId) {
    return jsonResponse({
      channel_id: null,
      items: [],
      next_cursor: null,
      settings,
      assigned_channels: assignedChannels,
      space_name: spaceName,
    });
  }

  if (!assignedChannels.some((a: { channel_id: string }) => a.channel_id === channelId)) {
    return jsonResponse({ error: "frame_not_assigned_to_channel" }, 403);
  }

  const limit = Math.min(Math.max(body.limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);
  const { data: page, error: pageError } = await supabase.rpc("frame_media_page", {
    p_channel: channelId,
    p_after: body.cursor ?? null,
    p_limit: limit,
  });
  if (pageError) return jsonResponse({ error: "fetch_failed" }, 500);
  const rows = (page ?? []) as {
    media_item_id: string;
    media_type: string;
    storage_path_display: string;
    storage_path_thumbnail: string | null;
    sort_key: number;
  }[];

  const items = [];
  for (const row of rows) {
    const { data: signed } = await supabase.storage
      .from("media-display")
      .createSignedUrl(row.storage_path_display, SIGNED_URL_TTL_SECONDS);
    // A video's display file is the MP4; its poster frame is what the
    // Frame's grid view shows (0054).
    let posterUrl: string | null = null;
    if (row.media_type === "video" && row.storage_path_thumbnail) {
      const { data: poster } = await supabase.storage
        .from("media-thumbnails")
        .createSignedUrl(row.storage_path_thumbnail, SIGNED_URL_TTL_SECONDS);
      posterUrl = poster?.signedUrl ?? null;
    }
    items.push({
      media_item_id: row.media_item_id,
      media_type: row.media_type,
      sort_order: row.sort_key,
      display_url: signed?.signedUrl ?? null,
      poster_url: posterUrl,
    });
  }
  const nextCursor = rows.length === limit ? rows[rows.length - 1].sort_key : null;

  return jsonResponse({
    channel_id: channelId,
    items,
    next_cursor: nextCursor,
    settings,
    assigned_channels: assignedChannels,
    space_name: spaceName,
  });
});
