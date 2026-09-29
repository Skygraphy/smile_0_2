// Deletes a whole Channel or a whole Space, permanently, for everyone.
//
// Why an Edge Function and not a plain RLS delete: the rows would cascade
// away fine on their own (channels -> media_items/members/shares/requests/
// frame_channels; spaces -> channels/frames/co-owners/...), but the photo
// FILES in Storage don't -- they'd be orphaned forever. So this collects
// every affected media_item's storage paths first, removes the files, and
// only then deletes the row. Everyone affected (members, shared-in Spaces,
// the Frames) learns about it through the ordinary sync_notify() triggers
// the cascade fires (migrations/0041_fcm_sync.sql).
//
// Who may:
// - a Channel: its home Space's Administrator or a co-owner -- the same
//   people who already manage everything else about it.
// - a Space: ONLY its Administrator (spaces.owner_id). Co-owners are equal
//   in what they can do inside the Space, but never get to end it -- same
//   line as "only the Administrator manages the co-owner list" (0037).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { isSpaceOwnerOrCoOwner, resolveSpaceAccess } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  kind: "channel" | "space";
  id: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if ((body.kind !== "channel" && body.kind !== "space") || !body.id) {
    return jsonResponse({ error: "kind_and_id_required" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  let channelIds: string[];
  if (body.kind === "channel") {
    const { data: channel } = await supabaseAdmin.from("channels").select("id, space_id").eq("id", body.id).maybeSingle();
    if (!channel) return jsonResponse({ error: "not_found" }, 404);
    if (!(await isSpaceOwnerOrCoOwner(supabaseAdmin, channel.space_id as string, userId))) {
      return jsonResponse({ error: "forbidden" }, 403);
    }
    channelIds = [channel.id as string];
  } else {
    const space = await resolveSpaceAccess(supabaseAdmin, body.id, userId);
    if (!space.exists) return jsonResponse({ error: "not_found" }, 404);
    if (!space.isAdmin) return jsonResponse({ error: "only_administrator" }, 403);
    const { data: channels } = await supabaseAdmin.from("channels").select("id").eq("space_id", body.id);
    channelIds = (channels ?? []).map((c: { id: string }) => c.id);
  }

  // Storage first, best-effort (same rule as delete-media): a file that's
  // already missing must never block deleting the rows.
  if (channelIds.length > 0) {
    const { data: items } = await supabaseAdmin
      .from("media_items")
      .select("storage_path_original, storage_path_display, storage_path_thumbnail")
      .in("channel_id", channelIds);
    const byBucket: Record<string, string[]> = { "media-originals": [], "media-display": [], "media-thumbnails": [] };
    for (const item of items ?? []) {
      if (item.storage_path_original) byBucket["media-originals"].push(item.storage_path_original);
      if (item.storage_path_display) byBucket["media-display"].push(item.storage_path_display);
      if (item.storage_path_thumbnail) byBucket["media-thumbnails"].push(item.storage_path_thumbnail);
    }
    for (const [bucket, paths] of Object.entries(byBucket)) {
      for (let i = 0; i < paths.length; i += 100) {
        await supabaseAdmin.storage.from(bucket).remove(paths.slice(i, i + 100));
      }
    }
  }

  const { error: deleteError } = await supabaseAdmin
    .from(body.kind === "channel" ? "channels" : "spaces")
    .delete()
    .eq("id", body.id);
  if (deleteError) return jsonResponse({ error: "delete_failed", detail: deleteError.message }, 500);

  return jsonResponse({ status: "deleted" });
});
