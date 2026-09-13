// Approve/reject one channel_join_request (see claim-channel-invite's
// requires_approval branch). Only a channel admin/space owner/staff of the
// request's own channel may decide it.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  request_id: string;
  decision: "approve" | "reject";
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
  if (!body.request_id || !["approve", "reject"].includes(body.decision)) {
    return jsonResponse({ error: "request_id_and_decision_required" }, 400);
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: joinRequest } = await supabaseAdmin
    .from("channel_join_requests")
    .select("*")
    .eq("id", body.request_id)
    .maybeSingle();
  if (!joinRequest) return jsonResponse({ error: "request_not_found" }, 404);
  if (joinRequest.status !== "pending") return jsonResponse({ error: "request_already_decided" }, 410);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: channel } = await supabaseAdmin
    .from("channels")
    .select("name")
    .eq("id", joinRequest.channel_id)
    .maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);

  // A channel can be linked to more than one Space now -- an owner of
  // *any* linked Space may decide join requests, same as any other
  // channel-admin-equivalent action.
  const { data: spaceLinks } = await supabaseAdmin
    .from("space_channels")
    .select("space_id")
    .eq("channel_id", joinRequest.channel_id);
  const linkedSpaceIds = (spaceLinks ?? []).map((l) => l.space_id as string);

  const { data: ownerRows } = linkedSpaceIds.length > 0
    ? await supabaseAdmin.from("space_owners").select("id").in("space_id", linkedSpaceIds).eq("user_id", userId)
    : { data: [] as { id: string }[] };
  const ownerRow = (ownerRows ?? []).length > 0 ? ownerRows![0] : null;

  const { data: membership } = await supabaseAdmin
    .from("channel_memberships")
    .select("role")
    .eq("channel_id", joinRequest.channel_id)
    .eq("user_id", userId)
    .maybeSingle();

  const isChannelAdmin = isStaff || Boolean(ownerRow) || membership?.role === "channel_admin";
  if (!isChannelAdmin) return jsonResponse({ error: "not_a_channel_admin" }, 403);

  if (body.decision === "approve") {
    const { error: insertError } = await supabaseAdmin
      .from("channel_memberships")
      .upsert(
        { channel_id: joinRequest.channel_id, user_id: joinRequest.user_id, role: "contributor" },
        { onConflict: "channel_id,user_id", ignoreDuplicates: true },
      );
    if (insertError) return jsonResponse({ error: "approve_failed", detail: insertError.message }, 500);

    // Best-effort: the code that originated this request now counts as
    // used. A deleted/missing code, or losing the optimistic race, is
    // never fatal to approving the person -- see claim-channel-invite for
    // the same guarded-increment pattern.
    if (joinRequest.pairing_code_id) {
      const { data: code } = await supabaseAdmin
        .from("pairing_codes")
        .select("id, use_count")
        .eq("id", joinRequest.pairing_code_id)
        .maybeSingle();
      if (code) {
        await supabaseAdmin
          .from("pairing_codes")
          .update({ use_count: code.use_count + 1 })
          .eq("id", code.id)
          .eq("use_count", code.use_count);
      }
    }
    await pushNotificationToUsers(
      supabaseAdmin,
      [joinRequest.user_id],
      { title: "Beitritt bestätigt", body: `Du bist jetzt Mitglied von "${channel.name}".` },
      { type: "join_request_approved", channel_id: joinRequest.channel_id, channel_name: channel.name },
    );
  }

  const { error: decideError } = await supabaseAdmin
    .from("channel_join_requests")
    .update({
      status: body.decision === "approve" ? "approved" : "rejected",
      decided_at: new Date().toISOString(),
      decided_by: userId,
    })
    .eq("id", body.request_id);
  if (decideError) return jsonResponse({ error: "decide_failed", detail: decideError.message }, 500);

  return jsonResponse({ status: body.decision === "approve" ? "approved" : "rejected" });
});
