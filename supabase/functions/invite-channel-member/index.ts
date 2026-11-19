// Called by a channel's SCO to invite a known person (by email) to become
// a posting member (channel_membership_requests, direction='invite' --
// see migrations/0031_architecture_reset.sql). The invitee then accepts or
// declines themselves via a plain RLS-governed PATCH
// (channel_membership_requests_decide already allows exactly that) --
// this function's only job is the email->user_id lookup no client-facing
// RLS can ever do, and the direction='invite' insert itself, which
// requires is_home_space_owner(channel_id) same as the RLS policy would.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { findUserIdByEmail } from "../_shared/find-user.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";
import { isStaff as checkStaff } from "../_shared/space-access.ts";
import { resolveChannelAccess } from "../_shared/channel-access.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  channel_id: string;
  email?: string;
  // By name (2026-10-11): a person from known_people() instead of an email.
  user_id?: string;
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
  if (!body.channel_id || (!body.email && !body.user_id)) return jsonResponse({ error: "channel_id_and_email_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const isStaff = await checkStaff(supabaseAdmin, userId);

  const { data: channel } = await supabaseAdmin.from("channels").select("id, name, space_id").eq("id", body.channel_id).maybeSingle();
  if (!channel) return jsonResponse({ error: "channel_not_found" }, 404);

  // The Space's managers, or the album's creator (migrations/0109).
  const access = await resolveChannelAccess(supabaseAdmin, channel.id, userId);
  if (!isStaff && !access.isSco) {
    return jsonResponse({ error: "not_channel_sco" }, 403);
  }

  const inviteeId = body.user_id ?? (await findUserIdByEmail(supabaseAdmin, body.email!));
  if (!inviteeId) return jsonResponse({ error: "user_not_found" }, 404);

  const { data: existingMembership } = await supabaseAdmin
    .from("channel_members")
    .select("user_id")
    .eq("channel_id", body.channel_id)
    .eq("user_id", inviteeId)
    .maybeSingle();
  if (existingMembership) return jsonResponse({ status: "already_member" });

  // An album creator brings in only people already in the Space; anyone
  // else becomes a proposal the managers decide (migrations/0111).
  if (!isStaff && !access.managesSpace) {
    const { data: anchored } = await supabaseAdmin.rpc("access_is_anchored", { p_user: inviteeId, p_space: channel.space_id });
    if (anchored !== true) {
      const { error: proposeError } = await supabaseAdmin
        .from("channel_invite_proposals")
        .insert({ channel_id: channel.id, invitee_user_id: inviteeId, proposed_by: userId });
      if (proposeError && !proposeError.message.includes("uq_invite_proposals_pending")) {
        return jsonResponse({ error: "invite_failed", detail: proposeError.message }, 500);
      }
      if (!proposeError) {
        const [{ data: me }, { data: person }] = await Promise.all([
          supabaseAdmin.from("profiles").select("display_name").eq("user_id", userId).maybeSingle(),
          supabaseAdmin.from("profiles").select("display_name").eq("user_id", inviteeId).maybeSingle(),
        ]);
        const { data: space } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", channel.space_id).maybeSingle();
        const { data: coOwners } = await supabaseAdmin.from("space_co_owners").select("user_id").eq("space_id", channel.space_id);
        const managers = [space?.owner_id, ...(coOwners ?? []).map((c: { user_id: string }) => c.user_id)].filter(Boolean) as string[];
        await pushNotificationToUsers(
          supabaseAdmin,
          managers,
          (t) => t.inviteProposal({ actor: me?.display_name ?? null, person: person?.display_name ?? null, album: channel.name }),
          { type: "invite_proposal", channel_id: channel.id, channel_name: channel.name },
        );
      }
      return jsonResponse({ status: "proposed" });
    }
  }

  const { data: request, error: insertError } = await supabaseAdmin
    .from("channel_membership_requests")
    .insert({ channel_id: body.channel_id, user_id: inviteeId, direction: "invite" })
    .select()
    .maybeSingle();
  if (insertError) {
    if (insertError.message.includes("uq_channel_membership_requests_pending")) {
      return jsonResponse({ error: "request_already_pending" }, 409);
    }
    return jsonResponse({ error: "invite_failed", detail: insertError.message }, 500);
  }

  await pushNotificationToUsers(
    supabaseAdmin,
    [inviteeId],
    (t) => t.memberInvite({ album: channel.name }),
    { type: "channel_membership_invite", channel_id: body.channel_id, channel_name: channel.name },
  );

  return jsonResponse({ status: "invited", request_id: request?.id });
});
