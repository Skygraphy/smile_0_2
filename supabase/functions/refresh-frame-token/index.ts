// Called proactively by a paired Frame (ComplianceWorker and the in-app
// sync loop, both well before the current access token's 1h TTL expires)
// to trade its refresh secret for a new access token. Rotate-on-use: the
// presented secret is retired the moment it's spent, whether or not
// anything goes wrong afterward, so a leaked-but-unused secret has the
// shortest possible window. Fixes the smile_0_1 prototype's documented gap
// (no rotation mechanism at all -> worked around with a 5-year token that
// still went silently stale if a kiosk ran long enough without a refresh
// call anywhere).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { mintDeviceAccessToken } from "../_shared/device-jwt.ts";
import { generateRefreshSecret, hashSecret } from "../_shared/device-secret.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

interface RefreshRequest {
  device_id: string;
  refresh_secret: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: RefreshRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.device_id || !body.refresh_secret) {
    return jsonResponse({ error: "device_id_and_refresh_secret_required" }, 400);
  }

  const { data: device } = await supabase
    .from("devices")
    .select("id, space_id, lifecycle_state")
    .eq("id", body.device_id)
    .maybeSingle();

  if (!device || !device.space_id || !["active", "offline"].includes(device.lifecycle_state)) {
    return jsonResponse({ error: "device_not_active" }, 403);
  }

  const { data: credentials } = await supabase
    .from("device_credentials")
    .select("*")
    .eq("device_id", body.device_id)
    .maybeSingle();

  if (!credentials || credentials.revoked_at) return jsonResponse({ error: "no_credentials" }, 403);

  const providedHash = await hashSecret(body.refresh_secret);
  if (providedHash !== credentials.refresh_secret_hash) {
    return jsonResponse({ error: "invalid_refresh_secret" }, 401);
  }

  const newSecret = generateRefreshSecret();
  const newHash = await hashSecret(newSecret);
  const newVersion = credentials.refresh_secret_version + 1;

  // Guarded on the hash we just verified: if two refresh calls race on the
  // same (still-valid-at-read-time) secret, only the first update matches
  // and wins the rotation; the loser's WITH-verified secret is now stale.
  const { data: rotated, error: updateError } = await supabase
    .from("device_credentials")
    .update({
      refresh_secret_hash: newHash,
      refresh_secret_version: newVersion,
      rotated_at: new Date().toISOString(),
    })
    .eq("device_id", body.device_id)
    .eq("refresh_secret_hash", credentials.refresh_secret_hash)
    .select()
    .maybeSingle();

  if (updateError) return jsonResponse({ error: "rotation_failed" }, 500);
  if (!rotated) return jsonResponse({ error: "invalid_refresh_secret" }, 401);

  const { token, expiresAt } = await mintDeviceAccessToken({
    device_id: device.id,
    space_id: device.space_id,
    credential_version: newVersion,
  });

  return jsonResponse({
    access_token: token,
    access_token_expires_at: expiresAt,
    refresh_secret: newSecret,
  });
});
