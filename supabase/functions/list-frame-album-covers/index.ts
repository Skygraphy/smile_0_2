// The covers of every album a Frame may show (its Space's own and those
// shared into it) -- for a Frame-Admin (migrations/0089), who chooses among
// them without being a member of each: list-my-channels only knows the
// caller's own albums (Ernst 2026-11-05: on Lisa's phone only "Enkelkinder"
// had a picture). Same cover rule as list-my-channels: an uploaded picture,
// else the chosen photo, else the newest ready one.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { avatarPublicUrl } from "../_shared/profiles.ts";
import { resolveSpaceAccess } from "../_shared/space-access.ts";
import { isFrameAdmin } from "../_shared/frame-admin.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  let body: { frame_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.frame_id) return jsonResponse({ error: "frame_id_required" }, 400);

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: frame } = await admin.from("frames").select("id, space_id").eq("id", body.frame_id).maybeSingle();
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 404);
  const access = await resolveSpaceAccess(admin, frame.space_id, userId);
  if (!access.manages && !access.isStaff && !(await isFrameAdmin(admin, frame.id, userId))) {
    return jsonResponse({ error: "forbidden" }, 403);
  }

  const [{ data: own }, { data: shares }] = await Promise.all([
    admin.from("channels").select("id, name, created_at, cover_path, cover_media_id, deleted_at").eq("space_id", frame.space_id),
    admin.from("channel_shares").select("channels(id, name, created_at, cover_path, cover_media_id, deleted_at)").eq("space_id", frame.space_id),
  ]);
  // deno-lint-ignore no-explicit-any
  const channels: any[] = [...(own ?? []), ...(shares ?? []).map((s: any) => s.channels).filter(Boolean)]
    .filter((c) => !c.deleted_at);
  if (channels.length === 0) return jsonResponse({ channels: [] });

  const ids = channels.map((c) => c.id as string);
  const { data: media } = await admin
    .from("media_items")
    .select("id, channel_id, storage_path_thumbnail, created_at")
    .in("channel_id", ids)
    .eq("processing_status", "ready")
    .not("storage_path_thumbnail", "is", null)
    .order("created_at", { ascending: false })
    .limit(2000);

  const cover = new Map<string, { mediaId: string; path: string }>();
  for (const m of media ?? []) {
    if (!cover.has(m.channel_id)) cover.set(m.channel_id, { mediaId: m.id, path: m.storage_path_thumbnail });
  }
  for (const c of channels) {
    const chosen = c.cover_media_id ? (media ?? []).find((m) => m.id === c.cover_media_id) : null;
    if (chosen) cover.set(c.id, { mediaId: chosen.id, path: chosen.storage_path_thumbnail });
  }
  const paths = [...cover.values()].map((c) => c.path);
  const signed = new Map<string, string>();
  if (paths.length > 0) {
    const { data } = await admin.storage.from("media-thumbnails").createSignedUrls(paths, 3600);
    // deno-lint-ignore no-explicit-any
    for (const s of (data ?? []) as any[]) if (s.path && s.signedUrl) signed.set(s.path, s.signedUrl);
  }

  return jsonResponse({
    channels: channels.map((c) => {
      const cv = cover.get(c.id);
      const url = cv ? signed.get(cv.path) : undefined;
      return {
        channel_id: c.id,
        channel_name: c.name,
        spaces: [],
        is_member: false,
        last_activity_at: c.created_at,
        cover: c.cover_path
          ? { media_id: null, thumbnail_url: avatarPublicUrl(c.cover_path), custom: true }
          : cv && url
          ? { media_id: cv.mediaId, thumbnail_url: url, custom: Boolean(c.cover_media_id) }
          : null,
      };
    }),
  });
});
