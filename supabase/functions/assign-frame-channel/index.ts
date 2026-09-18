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
import { pushSyncNowToFrames } from "../_shared/push-frames.ts";
import { resolveChannelAccess } from "../_shared/channel-access.ts";

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

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: frame } = await supabaseAdmin.from("frames").select("id, space_id").eq("id", body.frame_id).maybeSingle();
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 404);

  const { data: spaceRow } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", frame.space_id).maybeSingle();
  if (!spaceRow) return jsonResponse({ error: "space_not_found" }, 404);
  if (!isStaff && spaceRow.owner_id !== userId) return jsonResponse({ error: "not_space_owner" }, 403);

  // A Frame may show any channel its own Space can view -- its home
  // Space's own channels, or a channel shared into that Space
  // (channel_shares). Reuses the same view-access check RLS itself makes
  // (can_view_channel), just evaluated for the Frame's Space owner instead
  // of the caller (they may differ if staff is doing this on someone's
  // behalf).
  const access = await resolveChannelAccess(supabaseAdmin, body.channel_id, spaceRow.owner_id as string);
  if (!access.exists) return jsonResponse({ error: "channel_not_found" }, 404);
  if (!access.canView) return jsonResponse({ error: "channel_not_visible_to_frame_space" }, 400);

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

  await pushSyncNowToFrames(supabaseAdmin, [body.frame_id]);

  return jsonResponse({ status: "assigned", backfilled_items: readyItems?.length ?? 0 });
});
