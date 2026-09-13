// Called by the Smile app when a Space Owner enters/scans a
// channel_space_share code shown by an admin of the channel being shared
// (see pairing_codes, channel_members_screen.dart's "Mit anderem Space
// teilen"). Structurally a copy of claim-channel-invite's redemption flow
// (same optimistic-concurrency retry on use_count), but the *effect* of
// redeeming is different: it links the caller's own chosen Space to the
// channel (space_channels), not a personal channel_memberships row --
// see 0030_multi_space_channels.sql for the schema this powers.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const MAX_CLAIM_ATTEMPTS = 3;

interface ClaimRequest {
  code: string;
  space_id: string;
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
  if (!body.code || !body.space_id) return jsonResponse({ error: "code_and_space_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);

  const { data: ownerRow } = await supabaseAdmin
    .from("space_owners")
    .select("id")
    .eq("space_id", body.space_id)
    .eq("user_id", userId)
    .maybeSingle();
  if (!isStaff && !ownerRow) return jsonResponse({ error: "not_space_owner" }, 403);

  for (let attempt = 0; attempt < MAX_CLAIM_ATTEMPTS; attempt++) {
    const { data: pairingCode, error: codeError } = await supabaseAdmin
      .from("pairing_codes")
      .select("*, channels(name)")
      .eq("code", body.code.trim().toUpperCase())
      .eq("code_type", "channel_space_share")
      .maybeSingle();

    if (codeError) return jsonResponse({ error: "lookup_failed" }, 500);
    if (!pairingCode) return jsonResponse({ error: "invalid_code" }, 404);
    if (new Date(pairingCode.expires_at) < new Date()) return jsonResponse({ error: "code_expired" }, 410);
    if (pairingCode.use_count >= pairingCode.max_uses) return jsonResponse({ error: "code_already_used" }, 410);

    const channelId = pairingCode.channel_id as string;
    const channelRecord = pairingCode.channels as { name: string } | null;
    const channelName = channelRecord?.name ?? "";

    const { data: existingLink } = await supabaseAdmin
      .from("space_channels")
      .select("space_id")
      .eq("channel_id", channelId)
      .eq("space_id", body.space_id)
      .maybeSingle();
    if (existingLink) {
      return jsonResponse({ status: "linked", channel_id: channelId, channel_name: channelName });
    }

    const { error: insertError } = await supabaseAdmin
      .from("space_channels")
      .insert({ channel_id: channelId, space_id: body.space_id });
    if (insertError) return jsonResponse({ error: "link_failed", detail: insertError.message }, 500);

    // Optimistic guard against a concurrent redemption of the same code --
    // if another request already bumped use_count since we read it, retry
    // the whole lookup rather than silently under-counting uses (same
    // pattern as claim-channel-invite).
    const { data: updated } = await supabaseAdmin
      .from("pairing_codes")
      .update({ use_count: pairingCode.use_count + 1 })
      .eq("id", pairingCode.id)
      .eq("use_count", pairingCode.use_count)
      .select()
      .maybeSingle();

    if (updated) {
      return jsonResponse({ status: "linked", channel_id: channelId, channel_name: channelName });
    }
    // Lost the race on use_count -- the link is already inserted though,
    // so don't retry that; just retry validating/counting the code.
  }

  return jsonResponse({ error: "code_already_used" }, 410);
});
