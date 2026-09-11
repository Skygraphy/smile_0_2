// Called by the Smile app when an already-logged-in user (not yet a member
// of the target channel) enters or scans a channel_invite code shown by an
// existing member (see pairing_codes, channel_members_screen.dart's
// "Einladungscode zeigen"). Deliberately a code/QR flow rather than the
// concept doc's literal email-invite text -- see the plan under
// C:\Users\ernst\.claude\plans\swift-riding-snail.md for why -- but reuses
// the exact same pairing_codes table and OAuth-device-grant-style
// "redemption always goes through an Edge Function" convention as
// claim-device-pairing.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { pushNotificationToUsers } from "../_shared/push-users.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const MAX_CLAIM_ATTEMPTS = 3;

interface ClaimRequest {
  code: string;
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

  let body: ClaimRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.code) return jsonResponse({ error: "code_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  for (let attempt = 0; attempt < MAX_CLAIM_ATTEMPTS; attempt++) {
    const { data: pairingCode, error: codeError } = await supabaseAdmin
      .from("pairing_codes")
      .select("*, channels(name, space_id)")
      .eq("code", body.code.trim().toUpperCase())
      .eq("code_type", "channel_invite")
      .maybeSingle();

    if (codeError) return jsonResponse({ error: "lookup_failed" }, 500);
    if (!pairingCode) return jsonResponse({ error: "invalid_code" }, 404);
    if (new Date(pairingCode.expires_at) < new Date()) return jsonResponse({ error: "code_expired" }, 410);
    if (pairingCode.use_count >= pairingCode.max_uses) return jsonResponse({ error: "code_already_used" }, 410);

    const channelId = pairingCode.channel_id as string;
    const channelRecord = pairingCode.channels as { name: string; space_id: string } | null;
    const channelName = channelRecord?.name ?? "";

    const { data: existingMembership } = await supabaseAdmin
      .from("channel_memberships")
      .select("id")
      .eq("channel_id", channelId)
      .eq("user_id", userId)
      .maybeSingle();
    if (existingMembership) {
      return jsonResponse({ status: "already_member", channel_id: channelId, channel_name: channelName });
    }

    // Phase 6c: a code can require approval instead of joining outright --
    // stage a pending request (decide-channel-join-request applies it
    // later) rather than inserting channel_memberships or bumping
    // use_count now (a request isn't a "use" of the code until approved).
    if (pairingCode.requires_approval) {
      const { error: requestError } = await supabaseAdmin.from("channel_join_requests").upsert(
        {
          channel_id: channelId,
          user_id: userId,
          pairing_code_id: pairingCode.id,
          status: "pending",
          requested_at: new Date().toISOString(),
          decided_at: null,
          decided_by: null,
        },
        { onConflict: "channel_id,user_id" },
      );
      if (requestError) return jsonResponse({ error: "request_failed", detail: requestError.message }, 500);

      // Best-effort: nudge whoever can actually approve this (channel
      // admins + the Space Owner) so it doesn't just sit unnoticed until
      // someone happens to open the channel's Mitglieder screen.
      if (channelRecord) {
        const [{ data: admins }, { data: owners }] = await Promise.all([
          supabaseAdmin.from("channel_memberships").select("user_id").eq("channel_id", channelId).eq(
            "role",
            "channel_admin",
          ),
          supabaseAdmin.from("space_owners").select("user_id").eq("space_id", channelRecord.space_id),
        ]);
        const recipientIds = [
          ...new Set([...(admins ?? []).map((a) => a.user_id), ...(owners ?? []).map((o) => o.user_id)]),
        ];
        await pushNotificationToUsers(
          supabaseAdmin,
          recipientIds,
          { title: "Neue Beitrittsanfrage", body: `Jemand möchte "${channelName}" beitreten.` },
          { type: "join_request", channel_id: channelId, channel_name: channelName },
        );
      }

      return jsonResponse({ status: "pending_approval", channel_id: channelId, channel_name: channelName });
    }

    const { error: insertError } = await supabaseAdmin
      .from("channel_memberships")
      .insert({ channel_id: channelId, user_id: userId, role: "contributor" });
    if (insertError) return jsonResponse({ error: "join_failed", detail: insertError.message }, 500);

    // Optimistic guard against a concurrent redemption of the same code --
    // if another request already bumped use_count since we read it, retry
    // the whole lookup (the freshly re-read use_count/max_uses may still
    // allow it) rather than silently under-counting uses.
    const { data: updated } = await supabaseAdmin
      .from("pairing_codes")
      .update({ use_count: pairingCode.use_count + 1 })
      .eq("id", pairingCode.id)
      .eq("use_count", pairingCode.use_count)
      .select()
      .maybeSingle();

    if (updated) {
      return jsonResponse({ status: "joined", channel_id: channelId, channel_name: channelName });
    }
    // Lost the race on use_count -- membership row already exists though,
    // so don't retry the insert; just retry validating/counting the code.
  }

  return jsonResponse({ error: "code_already_used" }, 410);
});
