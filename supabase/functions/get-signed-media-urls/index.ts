// Called by the Smile app to render a channel's feed. Metadata (which
// items exist) the client could read directly via RLS, but the actual
// bytes are always behind a signed URL minted here -- storage.objects has
// no client-facing RLS policies at all.
//
// Keyset pagination (Phase 5a, replaces the Phase 3 fixed MAX_ITEMS cap):
// items are ordered by created_at desc, and a page's next_cursor is the
// created_at of its last item -- passing that back as `cursor` fetches the
// next older page (`created_at < cursor`). next_cursor is null once a page
// comes back shorter than the requested limit, meaning there's nothing
// older left.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";
import { resolveChannelAccess } from "../_shared/channel-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SIGNED_URL_TTL_SECONDS = 60 * 60;
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

interface RequestBody {
  channel_id: string;
  cursor?: string;
  limit?: number;
  // When true, return *only* the caller's own hidden-for-me items in this
  // channel (powers the Smile-App "Ausgeblendet" view) instead of the
  // normal feed. See delete-media's "hide"/"unhide" actions.
  only_hidden?: boolean;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);

  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.channel_id) return jsonResponse({ error: "channel_id_required" }, 400);
  const limit = Math.min(Math.max(body.limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  // A shared-into Space's owner can view the feed too (channel_shares is
  // view-only but that includes seeing photos, a deliberate behavior
  // change from the pre-reset schema -- see can_view_channel()'s comment
  // in migrations/0031_architecture_reset.sql), so this checks the same
  // broader "can view" condition RLS itself would, not just channel_members.
  const access = await resolveChannelAccess(supabaseAdmin, body.channel_id, userData.user.id);
  if (!access.canView) return jsonResponse({ error: "not_a_channel_member" }, 403);

  // A "hide" (migrations/0018_media_delete.sql, delete-media's "hide"
  // action) only ever affects the caller's own feed -- fetch it before the
  // main query. Normally these ids are excluded; `only_hidden` flips that
  // to power the Smile-App "Ausgeblendet" view. A "delete" (delete-media's
  // "delete" action) removes the row outright, so it needs no filter here
  // at all -- it's simply gone, in both views.
  const { data: hiddenRows } = await supabaseAdmin
    .from("media_item_hides")
    .select("media_item_id")
    .eq("user_id", userData.user.id);
  const hiddenIds = (hiddenRows ?? []).map((r) => r.media_item_id);

  if (body.only_hidden && hiddenIds.length === 0) {
    return jsonResponse({ items: [], next_cursor: null });
  }

  // No `processing_status = 'ready'` filter here anymore: a not-yet-ready
  // row is still returned (with its preview_data_url, no display/thumbnail
  // URL) so other channel members' feeds can show an instant blurry
  // placeholder while the upload/processing pipeline is still running,
  // WhatsApp-style. media_items_select RLS already allows any channel
  // member to see any row in their channel regardless of status.
  let query = supabaseAdmin
    .from("media_items")
    .select("*")
    .eq("channel_id", body.channel_id)
    .neq("processing_status", "failed")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (body.cursor) query = query.lt("created_at", body.cursor);
  query = body.only_hidden
    ? query.in("id", hiddenIds)
    : hiddenIds.length > 0
    ? query.not("id", "in", `(${hiddenIds.join(",")})`)
    : query;

  const { data: items, error: itemsError } = await query;
  if (itemsError) return jsonResponse({ error: "fetch_failed" }, 500);

  // Batch-sign per bucket (one round trip each) instead of one signed-URL
  // call per item -- with N items that was 2N sequential round trips and
  // dominated the feed's load time (~1.2s for just 5 photos). Only
  // ready items have a display/thumbnail path to sign at all.
  const displayPaths = (items ?? [])
    .map((item) => item.storage_path_display)
    .filter((path): path is string => Boolean(path));
  const thumbnailPaths = (items ?? [])
    .map((item) => item.storage_path_thumbnail)
    .filter((path): path is string => Boolean(path));

  const [displaySigned, thumbnailSigned] = await Promise.all([
    displayPaths.length > 0
      ? supabaseAdmin.storage.from("media-display").createSignedUrls(displayPaths, SIGNED_URL_TTL_SECONDS)
      : Promise.resolve({ data: [] as { path: string | null; signedUrl: string }[] }),
    thumbnailPaths.length > 0
      ? supabaseAdmin.storage.from("media-thumbnails").createSignedUrls(thumbnailPaths, SIGNED_URL_TTL_SECONDS)
      : Promise.resolve({ data: [] as { path: string | null; signedUrl: string }[] }),
  ]);

  const displayUrlByPath = new Map((displaySigned.data ?? []).map((s) => [s.path, s.signedUrl]));
  const thumbnailUrlByPath = new Map((thumbnailSigned.data ?? []).map((s) => [s.path, s.signedUrl]));

  // Powers the chat-style feed's left/right + avatar+name layout
  // (channel_feed_screen.dart) -- who sent each photo, resolved the same
  // way every other roster already resolves a member's name/avatar.
  const profilesBySenderId = await fetchProfilesByUserId(supabaseAdmin, (items ?? []).map((item) => item.sender_id as string));

  const results = (items ?? []).map((item) => {
    const profile = profilesBySenderId.get(item.sender_id as string);
    return {
      id: item.id,
      media_type: item.media_type,
      caption: item.caption,
      created_at: item.created_at,
      processing_status: item.processing_status,
      preview_data_url: item.preview_data_url,
      display_url: item.storage_path_display ? displayUrlByPath.get(item.storage_path_display) ?? null : null,
      thumbnail_url: item.storage_path_thumbnail ? thumbnailUrlByPath.get(item.storage_path_thumbnail) ?? null : null,
      width: item.width,
      height: item.height,
      sender_id: item.sender_id,
      sender_display_name: profile?.display_name ?? null,
      sender_avatar_url: profile?.avatar_url ?? null,
    };
  });

  const nextCursor = results.length === limit ? results[results.length - 1].created_at : null;

  return jsonResponse({ items: results, next_cursor: nextCursor });
});
