// The kiosk sync endpoint. Unauthenticated at the gateway level
// (--no-verify-jwt) -- the device presents its own access token in the
// body, verified here with our own HS256 secret (see _shared/device-jwt.ts
// and the Phase 3 note on why devices never hit PostgREST directly with
// this token). Re-checks lifecycle_state and credential_version against the
// DB on every call, mirroring what is_own_device() enforces for RLS-backed
// access -- a still-unexpired token from before a credential rotation is
// rejected here exactly like it would be at the RLS layer.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { verifyDeviceAccessToken } from "../_shared/device-jwt.ts";

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
    claims = await verifyDeviceAccessToken(body.access_token);
  } catch {
    return jsonResponse({ error: "invalid_or_expired_token" }, 401);
  }

  const { data: device } = await supabase
    .from("devices")
    .select("id, lifecycle_state, space_id, spaces(name)")
    .eq("id", claims.device_id)
    .maybeSingle();
  if (!device || !["active", "offline"].includes(device.lifecycle_state)) {
    return jsonResponse({ error: "device_not_active" }, 403);
  }
  // deno-lint-ignore no-explicit-any
  const spaceName = (device.spaces as any)?.name ?? null;

  const { data: credentials } = await supabase
    .from("device_credentials")
    .select("refresh_secret_version")
    .eq("device_id", claims.device_id)
    .maybeSingle();
  if (!credentials || credentials.refresh_secret_version !== claims.credential_version) {
    return jsonResponse({ error: "stale_credential_version" }, 401);
  }

  if (body.fcm_token || body.battery_level !== undefined || body.is_charging !== undefined) {
    await supabase
      .from("devices")
      .update({
        ...(body.fcm_token ? { fcm_token: body.fcm_token } : {}),
        ...(body.battery_level !== undefined ? { battery_level: body.battery_level } : {}),
        ...(body.is_charging !== undefined ? { is_charging: body.is_charging } : {}),
        last_seen_at: new Date().toISOString(),
      })
      .eq("id", claims.device_id);
  }

  let channelId = body.channel_id;
  if (!channelId) {
    const { data: firstAssignment } = await supabase
      .from("channel_memberships")
      .select("channel_id")
      .eq("device_id", claims.device_id)
      .eq("role", "device")
      .order("sort_order", { ascending: true, nullsFirst: false })
      .limit(1)
      .maybeSingle();
    channelId = firstAssignment?.channel_id;
  }

  const { data: policy } = await supabase
    .from("device_policies")
    .select("*")
    .eq("device_id", claims.device_id)
    .maybeSingle();

  const { data: assignedChannelsRaw } = await supabase
    .from("channel_memberships")
    .select("channel_id, sort_order, channels(name)")
    .eq("device_id", claims.device_id)
    .eq("role", "device")
    .order("sort_order", { ascending: true });

  const assignedChannels = (assignedChannelsRaw ?? []).map((a) => ({
    channel_id: a.channel_id,
    // deno-lint-ignore no-explicit-any
    name: (a.channels as any)?.name ?? null,
    sort_order: a.sort_order,
  }));

  if (!channelId) {
    return jsonResponse({
      channel_id: null,
      items: [],
      next_cursor: null,
      policy,
      assigned_channels: assignedChannels,
      space_name: spaceName,
    });
  }

  const { data: assignment } = await supabase
    .from("channel_memberships")
    .select("id")
    .eq("channel_id", channelId)
    .eq("device_id", claims.device_id)
    .eq("role", "device")
    .maybeSingle();
  if (!assignment) return jsonResponse({ error: "device_not_assigned_to_channel" }, 403);

  const limit = Math.min(Math.max(body.limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);

  let recipientsQuery = supabase
    .from("media_recipients")
    .select("id, sort_order, media_items(id, media_type, processing_status, storage_path_display)")
    .eq("device_id", claims.device_id)
    .eq("channel_id", channelId)
    .is("hidden_at", null)
    .order("sort_order", { ascending: true })
    .limit(limit);
  if (body.cursor !== undefined) recipientsQuery = recipientsQuery.gt("sort_order", body.cursor);

  const { data: recipients } = await recipientsQuery;

  const items = [];
  for (const r of recipients ?? []) {
    // deno-lint-ignore no-explicit-any
    const mi = r.media_items as any;
    // A "for everyone" delete (delete-media) removes the media_items row
    // outright (cascading to media_recipients), so a deleted photo simply
    // won't join here any more -- nothing extra to filter for it.
    if (!mi || mi.processing_status !== "ready" || !mi.storage_path_display) continue;
    const { data: signed } = await supabase.storage
      .from("media-display")
      .createSignedUrl(mi.storage_path_display, SIGNED_URL_TTL_SECONDS);
    items.push({
      media_recipient_id: r.id,
      media_item_id: mi.id,
      media_type: mi.media_type,
      sort_order: r.sort_order,
      display_url: signed?.signedUrl ?? null,
    });
  }

  // Based on the recipients page (not the post-filter items count): a full
  // page of recipients can still yield fewer ready items, but there may
  // still be more recipients beyond this page's cursor.
  const recipientsCount = recipients?.length ?? 0;
  const nextCursor = recipientsCount === limit ? recipients![recipientsCount - 1].sort_order : null;

  return jsonResponse({
    channel_id: channelId,
    items,
    next_cursor: nextCursor,
    policy,
    assigned_channels: assignedChannels,
    space_name: spaceName,
  });
});
