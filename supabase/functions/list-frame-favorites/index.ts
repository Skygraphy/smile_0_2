// A Frame's Lieblingsbilder for the app (migrations/0076, 2026-10-14):
// newest marked first, each with who marked it (the Frame itself or a
// manager) and when, plus the same media fields the album feed has, so the
// app shows and opens them like any photo. Only the Frame's managers
// (frames RLS), and only photos the Frame may still show (its albums now).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { guardedResponder, userIdFromToken, verifyUser } from "../_shared/fast-auth.ts";
import { fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SIGNED_URL_TTL_SECONDS = 60 * 60;

interface RequestBody {
  frame_id: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  // Read-only: session check and work at once (_shared/fast-auth.ts).
  const claimedUserId = userIdFromToken(authHeader);
  if (!claimedUserId) return jsonResponse({ error: "invalid_session" }, 401);
  const respond = guardedResponder(verifyUser(supabaseAsUser, claimedUserId), jsonResponse);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return await respond({ error: "invalid_json" }, 400);
  }
  if (!body.frame_id) return await respond({ error: "frame_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  // RLS (frames_select: the Space's Admin and Co-Admins) decides who may.
  const [{ data: frame }, { data: visibleRows }, { data: favoriteRows }] = await Promise.all([
    supabaseAsUser.from("frames").select("id").eq("id", body.frame_id).maybeSingle(),
    supabaseAdmin.rpc("frame_visible_channels", { p_frame: body.frame_id }),
    supabaseAdmin
      .from("frame_favorites")
      .select("media_item_id, added_by, created_at, media_items(*)")
      .eq("frame_id", body.frame_id)
      .order("created_at", { ascending: false }),
  ]);
  if (!frame) return await respond({ error: "frame_not_found" }, 404);

  const visible = new Set((visibleRows ?? []).map((r: { channel_id: string }) => r.channel_id));
  // deno-lint-ignore no-explicit-any
  const rows = (favoriteRows ?? []).filter((r: any) =>
    r.media_items && r.media_items.processing_status === "ready" && visible.has(r.media_items.channel_id)
  );

  // deno-lint-ignore no-explicit-any
  const media = rows.map((r: any) => r.media_items);
  const displayPaths = media.map((m: { storage_path_display: string | null }) => m.storage_path_display).filter((p): p is string => Boolean(p));
  const thumbPaths = media.map((m: { storage_path_thumbnail: string | null }) => m.storage_path_thumbnail).filter((p): p is string => Boolean(p));
  const [displaySigned, thumbSigned, profiles] = await Promise.all([
    displayPaths.length > 0
      ? supabaseAdmin.storage.from("media-display").createSignedUrls(displayPaths, SIGNED_URL_TTL_SECONDS)
      : Promise.resolve({ data: [] as { path: string | null; signedUrl: string }[] }),
    thumbPaths.length > 0
      ? supabaseAdmin.storage.from("media-thumbnails").createSignedUrls(thumbPaths, SIGNED_URL_TTL_SECONDS)
      : Promise.resolve({ data: [] as { path: string | null; signedUrl: string }[] }),
    fetchProfilesByUserId(supabaseAdmin, [
      // deno-lint-ignore no-explicit-any
      ...rows.map((r: any) => r.added_by).filter(Boolean),
      ...media.map((m: { sender_id: string }) => m.sender_id),
    ]),
  ]);
  const displayUrl = new Map((displaySigned.data ?? []).map((s) => [s.path, s.signedUrl]));
  const thumbUrl = new Map((thumbSigned.data ?? []).map((s) => [s.path, s.signedUrl]));

  // deno-lint-ignore no-explicit-any
  const items = rows.map((r: any) => {
    const m = r.media_items;
    const sender = profiles.get(m.sender_id);
    return {
      favorited_at: r.created_at,
      // Null: marked on the Frame itself.
      added_by: r.added_by,
      added_by_name: r.added_by ? profiles.get(r.added_by)?.display_name ?? null : null,
      media: {
        id: m.id,
        channel_id: m.channel_id,
        media_type: m.media_type,
        caption: m.caption,
        created_at: m.created_at,
        processing_status: m.processing_status,
        preview_data_url: m.preview_data_url,
        display_url: m.storage_path_display ? displayUrl.get(m.storage_path_display) ?? null : null,
        thumbnail_url: m.storage_path_thumbnail ? thumbUrl.get(m.storage_path_thumbnail) ?? null : null,
        width: m.width,
        height: m.height,
        sender_id: m.sender_id,
        sender_display_name: sender?.display_name ?? null,
        sender_avatar_url: sender?.avatar_url ?? null,
      },
    };
  });

  return await respond({ items });
});
