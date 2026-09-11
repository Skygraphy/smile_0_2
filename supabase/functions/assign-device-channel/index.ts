// Called from smile-app's device_settings_screen.dart ("Channel zuweisen").
// A bare client-side insert into channel_memberships was the original
// implementation, but that only makes a device eligible to *see* a channel
// going forward -- media_recipients (the table get-media-batch actually
// reads, see _shared/media-fanout.ts) is only ever populated at
// upload/processing-ready time, for whichever devices were *already*
// assigned then. A device assigned to a channel with existing ready photos
// therefore showed nothing until its next upload -- this function does the
// assignment AND backfills media_recipients for that channel's existing
// ready items in one step, exactly mirroring fanOutToDevices' own
// sort_order convention (the item's created_at, epoch ms), so a newly
// assigned device is never missing anything a device assigned earlier
// would already have.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { pushSyncNowToDevices } from "../_shared/push-devices.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  device_id: string;
  channel_id: string;
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

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.device_id || !body.channel_id) return jsonResponse({ error: "device_id_and_channel_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: device } = await supabaseAdmin.from("devices").select("space_id").eq("id", body.device_id).maybeSingle();
  if (!device) return jsonResponse({ error: "device_not_found" }, 404);

  const { data: channel } = await supabaseAdmin.from("channels").select("space_id").eq("id", body.channel_id).maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);
  // A Frame conceptually belongs to one Space -- refuse a cross-Space
  // assignment even though nothing else would technically stop it.
  if (channel.space_id !== device.space_id) return jsonResponse({ error: "channel_not_in_device_space" }, 400);

  if (!isStaff) {
    const { data: ownerRow } = await supabaseAdmin
      .from("space_owners")
      .select("id")
      .eq("space_id", device.space_id)
      .eq("user_id", userId)
      .maybeSingle();
    if (!ownerRow) return jsonResponse({ error: "not_space_owner" }, 403);
  }

  const { data: existingAssignments } = await supabaseAdmin
    .from("channel_memberships")
    .select("id")
    .eq("device_id", body.device_id)
    .eq("role", "device");
  const sortOrder = existingAssignments?.length ?? 0;

  const { error: insertError } = await supabaseAdmin
    .from("channel_memberships")
    .insert({ channel_id: body.channel_id, device_id: body.device_id, role: "device", sort_order: sortOrder });
  if (insertError) return jsonResponse({ error: "assign_failed", detail: insertError.message }, 500);

  const { data: readyItems } = await supabaseAdmin
    .from("media_items")
    .select("id, created_at")
    .eq("channel_id", body.channel_id)
    .eq("processing_status", "ready");

  if (readyItems && readyItems.length > 0) {
    await supabaseAdmin.from("media_recipients").upsert(
      readyItems.map((item) => ({
        media_item_id: item.id,
        device_id: body.device_id,
        channel_id: body.channel_id,
        sort_order: new Date(item.created_at).getTime(),
      })),
      { onConflict: "media_item_id,device_id", ignoreDuplicates: true },
    );
  }

  await pushSyncNowToDevices(supabaseAdmin, [body.device_id]);

  return jsonResponse({ status: "assigned", backfilled_items: readyItems?.length ?? 0 });
});
