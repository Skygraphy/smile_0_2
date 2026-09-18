// Best-effort push to wake a Frame for an immediate sync, bypassing the
// periodic poll interval. Authenticated as the caller's own session (real
// Supabase Auth JWT) -- the frames_select RLS policy (is_space_owner or
// staff, see migrations/0031_architecture_reset.sql) is reused directly to
// authorize the read instead of re-implementing the same ownership check
// here. Failure here is never fatal -- the normal poll cycle
// (submit-heartbeat, get-media-batch) remains the real delivery guarantee.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { sendDataMessage } from "../_shared/fcm.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  frame_id: string;
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
  if (!body.frame_id) return jsonResponse({ error: "frame_id_required" }, 400);

  // RLS (frames_select: is_space_owner or staff) does the authorization --
  // a caller who doesn't own this Frame's Space simply gets no row back.
  const { data: frame } = await supabaseAsUser.from("frames").select("id, fcm_token").eq("id", body.frame_id).maybeSingle();
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 404);

  if (!frame.fcm_token) {
    return jsonResponse({ status: "no_fcm_token" });
  }

  try {
    await sendDataMessage(frame.fcm_token, { type: "sync_now" });
    return jsonResponse({ status: "sent" });
  } catch (e) {
    return jsonResponse({ status: "send_failed", detail: String(e) });
  }
});
