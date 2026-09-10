// Two-tier delete, WhatsApp-style: only the sender or a channel admin/staff
// member may delete a photo at all (see migrations/0018_media_delete.sql).
// "for_everyone" soft-deletes the row (media_items.deleted_at) -- it
// disappears from every other member's feed and every Smile-Frame
// immediately, but the sender still sees it in their own feed (as a
// tombstone tile client-side) since get-signed-media-urls carves out an
// exception for sender_id = caller. "for_me" only ever affects the caller's
// own feed (media_item_hides), leaving the photo untouched for everyone
// else including the original sender if someone else (e.g. an admin) is
// the one hiding it.
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
  scope: "for_me" | "for_everyone";
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
  if (!["for_me", "for_everyone"].includes(body.scope)) {
    return jsonResponse({ error: "invalid_scope" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: items, error: itemsError } = await supabaseAdmin
    .from("media_items")
    .select("id, sender_id, channel_id")
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

  const foundIds = new Set((items ?? []).map((item) => item.id));
  const deleted: string[] = [];
  const denied: string[] = [];
  const notFound = body.media_item_ids.filter((id) => !foundIds.has(id));

  const allowedIds: string[] = [];
  for (const item of items ?? []) {
    const allowed = item.sender_id === userId || adminChannelIds.has(item.channel_id) || isStaff;
    if (allowed) {
      allowedIds.push(item.id);
    } else {
      denied.push(item.id);
    }
  }

  if (allowedIds.length > 0) {
    if (body.scope === "for_everyone") {
      const { error: updateError } = await supabaseAdmin
        .from("media_items")
        .update({ deleted_at: new Date().toISOString() })
        .in("id", allowedIds);
      if (updateError) return jsonResponse({ error: "delete_failed", detail: updateError.message }, 500);

      // "for everyone" is the only scope a frame ever needs to hear about --
      // "for me" is a personal hide that never touches what a frame shows.
      const affectedChannelIds = [...new Set((items ?? []).filter((i) => allowedIds.includes(i.id)).map((i) => i.channel_id))];
      const { data: deviceMemberships } = await supabaseAdmin
        .from("channel_memberships")
        .select("device_id")
        .in("channel_id", affectedChannelIds)
        .eq("role", "device");
      const deviceIds = (deviceMemberships ?? [])
        .map((m: { device_id: string | null }) => m.device_id)
        .filter((id: string | null): id is string => Boolean(id));
      await pushSyncNowToDevices(supabaseAdmin, deviceIds);
    } else {
      const { error: hideError } = await supabaseAdmin
        .from("media_item_hides")
        .upsert(
          allowedIds.map((id) => ({ media_item_id: id, user_id: userId })),
          { onConflict: "media_item_id,user_id", ignoreDuplicates: true },
        );
      if (hideError) return jsonResponse({ error: "hide_failed", detail: hideError.message }, 500);
    }
    deleted.push(...allowedIds);
  }

  return jsonResponse({ deleted, denied, not_found: notFound });
});
