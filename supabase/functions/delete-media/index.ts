// Two independent features share this endpoint because they share the same
// "check per-id permission, apply, report partial success" shape -- they
// are NOT two flavors of the same action:
//
// "delete" is destructive and permanent: only the sender or a channel
// admin/staff member may do it. Once confirmed it's an immediate, real
// delete -- the media_items row (cascading to media_recipients and
// media_item_hides) and every storage object
// (media-originals/media-display/media-thumbnails) are removed outright.
// Gone from every Smile-App client, every Smile-Frame (get-media-batch
// simply won't find it any more, and the frame's existing sync-diff evicts
// the local cache file the same way it already handles any other removed
// photo), the DB, and every cache -- no placeholder, no second
// confirmation, no delay beyond the automatic push-triggered sync (see
// push-devices.ts) nudging frames to notice immediately instead of on
// their next poll.
//
// "hide"/"unhide" are non-destructive and personal: ANY member of the
// item's channel (any role, not just sender/admin) may hide or re-show an
// individual photo for their own Smile-App view only (media_item_hides).
// The photo is completely untouched for everyone else, and Smile-Frame
// never hears about this at all -- a Frame has no per-viewer identity to
// hide anything *for*.
//
// Bulk (multi-select) input: each id is checked and applied independently,
// so one denied item in a batch doesn't block the rest -- the response
// reports per-item outcome instead of failing the whole call.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { pushSyncNowToDevices } from "../_shared/push-devices.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const MAX_IDS_PER_REQUEST = 200;

interface DeleteMediaRequest {
  media_item_ids: string[];
  action: "delete" | "hide" | "unhide";
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
  const userId = userData.user.id;

  let body: DeleteMediaRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!Array.isArray(body.media_item_ids) || body.media_item_ids.length === 0) {
    return jsonResponse({ error: "media_item_ids_required" }, 400);
  }
  if (body.media_item_ids.length > MAX_IDS_PER_REQUEST) {
    return jsonResponse({ error: "too_many_ids" }, 400);
  }
  if (!["delete", "hide", "unhide"].includes(body.action)) {
    return jsonResponse({ error: "invalid_action" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: items, error: itemsError } = await supabaseAdmin
    .from("media_items")
    .select("id, sender_id, channel_id, storage_path_original, storage_path_display, storage_path_thumbnail")
    .in("id", body.media_item_ids);
  if (itemsError) return jsonResponse({ error: "fetch_failed" }, 500);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const channelIds = [...new Set((items ?? []).map((item) => item.channel_id))];
  const { data: memberships } = await supabaseAdmin
    .from("channel_memberships")
    .select("channel_id, role")
    .eq("user_id", userId)
    .in("channel_id", channelIds);
  const adminChannelIds = new Set(
    (memberships ?? []).filter((m) => m.role === "channel_admin").map((m) => m.channel_id),
  );
  // hide/unhide just needs *some* membership in the item's channel --
  // any role, including plain viewer/contributor.
  const memberChannelIds = new Set((memberships ?? []).map((m) => m.channel_id));

  const foundIds = new Set((items ?? []).map((item) => item.id));
  const applied: string[] = [];
  const denied: string[] = [];
  const notFound = body.media_item_ids.filter((id) => !foundIds.has(id));

  const allowedIds: string[] = [];
  for (const item of items ?? []) {
    const allowed = body.action === "delete"
      ? item.sender_id === userId || adminChannelIds.has(item.channel_id) || isStaff
      : memberChannelIds.has(item.channel_id);
    if (allowed) {
      allowedIds.push(item.id);
    } else {
      denied.push(item.id);
    }
  }

  if (allowedIds.length > 0) {
    if (body.action === "delete") {
      const allowedItemsById = new Map((items ?? []).map((item) => [item.id, item]));

      // Storage removal is best-effort -- a missing object (e.g. the photo
      // never finished processing) shouldn't block deleting the row, since
      // there's nothing left to clean up for it either way.
      for (const id of allowedIds) {
        const item = allowedItemsById.get(id)!;
        const paths: Record<string, string | null> = {
          "media-originals": item.storage_path_original,
          "media-display": item.storage_path_display,
          "media-thumbnails": item.storage_path_thumbnail,
        };
        await Promise.all(
          Object.entries(paths)
            .filter((entry): entry is [string, string] => Boolean(entry[1]))
            .map(([bucket, path]) => supabaseAdmin.storage.from(bucket).remove([path])),
        );
      }

      const { error: deleteError } = await supabaseAdmin.from("media_items").delete().in("id", allowedIds);
      if (deleteError) return jsonResponse({ error: "delete_failed", detail: deleteError.message }, 500);

      // Only a real delete needs to reach a frame -- hide/unhide are a
      // personal Smile-App view preference that never changes what a
      // frame shows.
      const affectedChannelIds = [...new Set(allowedIds.map((id) => allowedItemsById.get(id)!.channel_id))];
      const { data: deviceMemberships } = await supabaseAdmin
        .from("channel_memberships")
        .select("device_id")
        .in("channel_id", affectedChannelIds)
        .eq("role", "device");
      const deviceIds = (deviceMemberships ?? [])
        .map((m: { device_id: string | null }) => m.device_id)
        .filter((id: string | null): id is string => Boolean(id));
      await pushSyncNowToDevices(supabaseAdmin, deviceIds);
    } else if (body.action === "hide") {
      const { error: hideError } = await supabaseAdmin
        .from("media_item_hides")
        .upsert(
          allowedIds.map((id) => ({ media_item_id: id, user_id: userId })),
          { onConflict: "media_item_id,user_id", ignoreDuplicates: true },
        );
      if (hideError) return jsonResponse({ error: "hide_failed", detail: hideError.message }, 500);
    } else {
      const { error: unhideError } = await supabaseAdmin
        .from("media_item_hides")
        .delete()
        .eq("user_id", userId)
        .in("media_item_id", allowedIds);
      if (unhideError) return jsonResponse({ error: "unhide_failed", detail: unhideError.message }, 500);
    }
    applied.push(...allowedIds);
  }

  return jsonResponse({ applied, denied, not_found: notFound });
});
