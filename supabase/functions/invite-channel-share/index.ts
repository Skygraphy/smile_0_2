// Called by a channel's SCO to invite a known person (by email) to view
// -share the channel into whichever of their own Spaces they choose
// (channel_share_requests, direction='invite', space_id left null until
// accepted -- see migrations/0031_architecture_reset.sql). The invitee
// accepts via a plain RLS-governed PATCH that supplies space_id in the
// same call (channel_share_requests_decide's WITH CHECK verifies they can
// only pick a Space they themselves own) -- this function's only job is
// the email->user_id lookup and the direction='invite' insert itself.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { findUserIdByEmail } from "../_shared/find-user.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  channel_id: string;
  email: string;
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
  if (!body.channel_id || !body.email) return jsonResponse({ error: "channel_id_and_email_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: channel } = await supabaseAdmin.from("channels").select("id, name, space_id").eq("id", body.channel_id).maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);

  const { data: spaceRow } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", channel.space_id).maybeSingle();
  if (!isStaff && spaceRow?.owner_id !== userId) return jsonResponse({ error: "not_channel_sco" }, 403);

  const inviteeId = await findUserIdByEmail(supabaseAdmin, body.email);
  if (!inviteeId) return jsonResponse({ error: "user_not_found" }, 404);

  const { data: request, error: insertError } = await supabaseAdmin
    .from("channel_share_requests")
    .insert({ channel_id: body.channel_id, target_user_id: inviteeId, direction: "invite", space_id: null })
    .select()
    .maybeSingle();
  if (insertError) {
    if (insertError.message.includes("uq_channel_share_requests_pending_invite")) {
      return jsonResponse({ error: "request_already_pending" }, 409);
    }
    return jsonResponse({ error: "invite_failed", detail: insertError.message }, 500);
  }

  await pushNotificationToUsers(
    supabaseAdmin,
    [inviteeId],
    { title: "Channel-Freigabe angeboten", body: `Du wurdest eingeladen, "${channel.name}" mit deinem Space zu teilen.` },
    { type: "channel_share_invite", channel_id: body.channel_id, channel_name: channel.name },
  );

  return jsonResponse({ status: "invited", request_id: request?.id });
});
