// Called by a Frame after it executes (or fails to execute) a remote
// command it received from submit-heartbeat or poll-device-pairing's
// FCM-triggered sibling. Same device-token self-verification pattern as
// the other device-facing functions.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { verifyDeviceAccessToken } from "../_shared/device-jwt.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

interface RequestBody {
  access_token: string;
  command_id: string;
  status: "acknowledged" | "completed" | "failed";
  result_detail?: Record<string, unknown>;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.access_token || !body.command_id || !body.status) {
    return jsonResponse({ error: "access_token_command_id_and_status_required" }, 400);
  }

  let claims;
  try {
    claims = await verifyDeviceAccessToken(body.access_token);
  } catch {
    return jsonResponse({ error: "invalid_or_expired_token" }, 401);
  }

  const { data: command } = await supabase
    .from("remote_commands")
    .select("id")
    .eq("id", body.command_id)
    .eq("device_id", claims.device_id)
    .maybeSingle();
  if (!command) return jsonResponse({ error: "command_not_found" }, 404);

  const isTerminal = body.status === "completed" || body.status === "failed";
  const { error: updateError } = await supabase
    .from("remote_commands")
    .update({
      status: body.status,
      completed_at: isTerminal ? new Date().toISOString() : null,
      result_detail: body.result_detail ?? null,
    })
    .eq("id", body.command_id);

  if (updateError) return jsonResponse({ error: "update_failed" }, 500);

  return jsonResponse({ status: "ok" });
});
