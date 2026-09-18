// Called periodically by a paired Frame as a lightweight "I'm alive" ping,
// independent of a full get-media-batch sync. Architecture reset
// (migrations/0031_architecture_reset.sql) dropped all MDM/compliance
// machinery (remote_commands, device_policies enforcement, compliance
// history) -- this now only records plain operational telemetry
// (last_seen_at/battery/app_version), the same fields get-media-batch
// already opportunistically updates on every poll. Same auth pattern as
// get-media-batch: unauthenticated at the gateway level, the Frame's own
// access token is verified here.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { verifyFrameAccessToken } from "../_shared/frame-jwt.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

interface RequestBody {
  access_token: string;
  app_version?: string;
  battery_level?: number;
  is_charging?: boolean;
  fcm_token?: string;
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
  if (!body.access_token) return jsonResponse({ error: "access_token_required" }, 400);

  let claims;
  try {
    claims = await verifyFrameAccessToken(body.access_token);
  } catch {
    return jsonResponse({ error: "invalid_or_expired_token" }, 401);
  }

  const { data: frame } = await supabase
    .from("frames")
    .select("id, lifecycle_state")
    .eq("id", claims.frame_id)
    .maybeSingle();
  if (!frame || frame.lifecycle_state !== "active") {
    return jsonResponse({ error: "frame_not_active" }, 403);
  }

  const { data: credentials } = await supabase
    .from("frame_credentials")
    .select("refresh_secret_version")
    .eq("frame_id", claims.frame_id)
    .maybeSingle();
  if (!credentials || credentials.refresh_secret_version !== claims.credential_version) {
    return jsonResponse({ error: "stale_credential_version" }, 401);
  }

  await supabase
    .from("frames")
    .update({
      last_seen_at: new Date().toISOString(),
      ...(body.app_version ? { current_app_version: body.app_version } : {}),
      ...(body.battery_level !== undefined ? { battery_level: body.battery_level } : {}),
      ...(body.is_charging !== undefined ? { is_charging: body.is_charging } : {}),
      ...(body.fcm_token ? { fcm_token: body.fcm_token } : {}),
    })
    .eq("id", claims.frame_id);

  return jsonResponse({ status: "ok" });
});
