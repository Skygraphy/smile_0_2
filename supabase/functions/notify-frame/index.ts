// Best-effort push to wake a Frame for an immediate sync/compliance check,
// bypassing the periodic poll interval. Authenticated as the caller's own
// session (real Supabase Auth JWT, unlike the device-facing functions);
// manually checks is_space_owner-equivalent so a caller can only nudge
// devices in a Space they own. Failure here is never fatal -- the normal
// poll cycle (submit-heartbeat, get-media-batch) remains the real delivery
// guarantee, matching smile_0_1's notify-device.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { sendDataMessage } from "../_shared/fcm.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  device_id: string;
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

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.device_id) return jsonResponse({ error: "device_id_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: device } = await supabaseAdmin
    .from("devices")
    .select("id, space_id, fcm_token")
    .eq("id", body.device_id)
    .maybeSingle();
  if (!device) return jsonResponse({ error: "device_not_found" }, 404);

  const { data: ownerRow } = await supabaseAdmin
    .from("space_owners")
    .select("id")
    .eq("space_id", device.space_id)
    .eq("user_id", userData.user.id)
    .maybeSingle();
  if (!ownerRow) return jsonResponse({ error: "not_space_owner" }, 403);

  if (!device.fcm_token) {
    return jsonResponse({ status: "no_fcm_token" });
  }

  try {
    await sendDataMessage(device.fcm_token, { type: "sync_now" });
    return jsonResponse({ status: "sent" });
  } catch (e) {
    return jsonResponse({ status: "send_failed", detail: String(e) });
  }
});
