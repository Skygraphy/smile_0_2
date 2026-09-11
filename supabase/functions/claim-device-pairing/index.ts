// Called by the Smile app when a Space Owner scans (or types) the code
// shown on a Frame's screen. Stages the claim onto the pairing_codes row
// (space_id) but deliberately does NOT touch devices/device_credentials --
// activation and credential minting happen only when the FRAME ITSELF next
// polls (poll-device-pairing), so the device always ends up holding its
// own credentials directly, never relayed through the claiming phone
// (mirrors the OAuth 2.0 Device Authorization Grant handoff pattern).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface ClaimRequest {
  code: string;
  space_id: string;
  // "Gerät ersetzen": the old Frame this new one is meant to take over
  // for (see migrations/0023_replace_device_on_pairing.sql). Staged here,
  // applied at activation time (poll-device-pairing) -- same handoff
  // claimed_by_user_id already uses.
  replace_device_id?: string;
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

  // Caller must own the target Space (concept doc sect. 16: Device
  // Association binds a Frame to a Space, done by that Space's Owner).
  const { data: ownerRow } = await supabaseAdmin
    .from("space_owners")
    .select("id")
    .eq("space_id", body.space_id)
    .eq("user_id", userId)
    .maybeSingle();
  if (!ownerRow) return jsonResponse({ error: "not_space_owner" }, 403);

  if (body.replace_device_id) {
    const { data: replaceTarget } = await supabaseAdmin
      .from("devices")
      .select("space_id")
      .eq("id", body.replace_device_id)
      .maybeSingle();
    if (!replaceTarget || replaceTarget.space_id !== body.space_id) {
      return jsonResponse({ error: "replace_device_id_not_in_space" }, 400);
    }
  }

  const { data: pairingCode, error: codeError } = await supabaseAdmin
    .from("pairing_codes")
    .select("*")
    .eq("code", body.code)
    .eq("code_type", "device_provisioning")
    .single();

  if (codeError || !pairingCode) return jsonResponse({ error: "invalid_code" }, 404);
  if (new Date(pairingCode.expires_at) < new Date()) return jsonResponse({ error: "code_expired" }, 410);
  if (pairingCode.use_count >= pairingCode.max_uses) return jsonResponse({ error: "code_already_used" }, 410);
  if (pairingCode.space_id) return jsonResponse({ error: "code_already_claimed" }, 410);

  // Guarded update (.is("space_id", null)) makes this atomic against a
  // concurrent claim of the same code -- only one request's WHERE clause
  // still matches once the first has landed.
  const { data: updated, error: updateError } = await supabaseAdmin
    .from("pairing_codes")
    .update({
      space_id: body.space_id,
      claimed_by_user_id: userId,
      replace_device_id: body.replace_device_id ?? null,
    })
    .eq("id", pairingCode.id)
    .is("space_id", null)
    .select()
    .maybeSingle();

  if (updateError) return jsonResponse({ error: "claim_failed" }, 500);
  if (!updated) return jsonResponse({ error: "code_already_claimed" }, 410);

  return jsonResponse({ status: "claimed", device_id: pairingCode.device_id });
});
