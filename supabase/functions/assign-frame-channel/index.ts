// Called from smile-app's frame settings screen ("Channel zuweisen"). A
// bare client-side insert into frame_channels was possible (RLS's
// frame_channels_owner_write already allows exactly this), but that only
// makes a Frame eligible to *see* a channel going forward --
// media_recipients (the table get-media-batch actually reads, see
// _shared/media-fanout.ts) is only ever populated at upload/processing-
// ready time, for whichever Frames were *already* assigned then. A Frame
// assigned to a channel with existing ready photos would therefore show
// nothing until the next upload -- this function does the assignment AND
// backfills media_recipients for that channel's existing ready items in
// one step, mirroring fanOutToFrames' own sort_order convention (the
// item's created_at, epoch ms).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { spaceCanViewChannel } from "../_shared/channel-access.ts";
import { resolveSpaceAccess } from "../_shared/space-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  frame_id: string;
  channel_id: string;
  sort_order?: number;
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
  if (!body.frame_id || !body.channel_id) return jsonResponse({ error: "frame_id_and_channel_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: frame } = await supabaseAdmin.from("frames").select("id, space_id").eq("id", body.frame_id).maybeSingle();
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 404);

  const space = await resolveSpaceAccess(supabaseAdmin, frame.space_id, userId);
  if (!space.exists) return jsonResponse({ error: "space_not_found" }, 404);
  if (!space.isStaff && !space.manages) return jsonResponse({ error: "not_space_owner" }, 403);

  // A Frame may show what its HOUSEHOLD can see -- the Space's own
  // channels or ones shared into it. Not what the person assigning it (or
  // the Administrator) can see personally: before 0047 this asked the
  // Administrator's own view, so a channel they merely post in elsewhere
  // could end up on the household Frame.
  const { data: channel } = await supabaseAdmin.from("channels").select("id").eq("id", body.channel_id).maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);
  if (!(await spaceCanViewChannel(supabaseAdmin, frame.space_id, body.channel_id))) {
    return jsonResponse({ error: "channel_not_visible_to_frame_space" }, 400);
  }

  const { error: insertError } = await supabaseAdmin
    .from("frame_channels")
    .upsert(
      { frame_id: body.frame_id, channel_id: body.channel_id, sort_order: body.sort_order ?? 0 },
      { onConflict: "frame_id,channel_id" },
    );
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
        frame_id: body.frame_id,
        channel_id: body.channel_id,
        sort_order: new Date(item.created_at).getTime(),
      })),
      { onConflict: "media_item_id,frame_id", ignoreDuplicates: true },
    );
  }

  // No explicit push needed: the frame_channels insert above fires
  // sync_notify(), which pushes this Frame (migrations/0041_fcm_sync.sql).

  return jsonResponse({ status: "assigned", backfilled_items: readyItems?.length ?? 0 });
});
