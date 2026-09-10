// Called periodically by a paired Frame (ComplianceWorker-equivalent,
// WorkManager background loop + in-app timer while foregrounded).
// Records telemetry (concept doc sect. 27) and hands back any pending
// remote_commands in the same round-trip, marking them 'delivered'.
// Same auth pattern as get-media-batch: unauthenticated at the gateway
// level, the device's own access token is verified here.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { verifyDeviceAccessToken } from "../_shared/device-jwt.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

interface RequestBody {
  access_token: string;
  compliance_state: "compliant" | "drift_detected" | "repaired" | "unknown";
  drift_details?: Record<string, unknown>;
  app_version?: string;
  os_version?: string;
  uptime_seconds?: number;
  storage_used_pct?: number;
  battery_level?: number;
  is_charging?: boolean;
  network_type?: string;
  last_sync_at?: string;
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
  if (!body.access_token || !body.compliance_state) {
    return jsonResponse({ error: "access_token_and_compliance_state_required" }, 400);
  }

  let claims;
  try {
    claims = await verifyDeviceAccessToken(body.access_token);
  } catch {
    return jsonResponse({ error: "invalid_or_expired_token" }, 401);
  }

  const { data: device } = await supabase
    .from("devices")
    .select("id, lifecycle_state, space_id")
    .eq("id", claims.device_id)
    .maybeSingle();
  if (!device || !["active", "offline"].includes(device.lifecycle_state)) {
    return jsonResponse({ error: "device_not_active" }, 403);
  }

  const { data: credentials } = await supabase
    .from("device_credentials")
    .select("refresh_secret_version")
    .eq("device_id", claims.device_id)
    .maybeSingle();
  if (!credentials || credentials.refresh_secret_version !== claims.credential_version) {
    return jsonResponse({ error: "stale_credential_version" }, 401);
  }

  await supabase.from("device_heartbeats").insert({
    device_id: claims.device_id,
    space_id: device.space_id,
    compliance_state: body.compliance_state,
    drift_details: body.drift_details ?? null,
    app_version: body.app_version ?? null,
    os_version: body.os_version ?? null,
    uptime_seconds: body.uptime_seconds ?? null,
    storage_used_pct: body.storage_used_pct ?? null,
    battery_level: body.battery_level ?? null,
    is_charging: body.is_charging ?? null,
    network_type: body.network_type ?? null,
    last_sync_at: body.last_sync_at ?? null,
  });

  await supabase
    .from("devices")
    .update({
      last_compliance_check_at: new Date().toISOString(),
      last_compliance_state: body.compliance_state,
      last_seen_at: new Date().toISOString(),
      ...(body.app_version ? { current_app_version: body.app_version } : {}),
      ...(body.battery_level !== undefined ? { battery_level: body.battery_level } : {}),
      ...(body.is_charging !== undefined ? { is_charging: body.is_charging } : {}),
    })
    .eq("id", claims.device_id);

  const { data: pendingCommands } = await supabase
    .from("remote_commands")
    .select("*")
    .eq("device_id", claims.device_id)
    .eq("status", "pending")
    .gt("expires_at", new Date().toISOString())
    .order("requested_at", { ascending: true });

  if (pendingCommands && pendingCommands.length > 0) {
    await supabase
      .from("remote_commands")
      .update({ status: "delivered", delivered_at: new Date().toISOString() })
      .in(
        "id",
        pendingCommands.map((c) => c.id),
      );
  }

  return jsonResponse({ status: "ok", commands: pendingCommands ?? [] });
});
