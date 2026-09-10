// Called by a fresh Smile-Frame on first boot (UNPAIRED state). Creates a
// devices row with no Space yet and a one-time pairing code, which the
// Frame renders as text + QR (concept doc sect. 14: the FRAME displays the
// code, the Smile app scans it -- the reverse of smile_0_1's kiosk, which
// had its own code-entry screen).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { generatePairingCode } from "../_shared/device-secret.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const CODE_TTL_SECONDS = 15 * 60;

interface RequestBody {
  device_name?: string;
  android_id?: string;
  app_version?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const { data: device, error: deviceError } = await supabase
    .from("devices")
    .insert({
      space_id: null,
      name: body.device_name?.trim() || "Neues Frame",
      android_id: body.android_id ?? null,
      current_app_version: body.app_version ?? null,
      lifecycle_state: "pairing",
    })
    .select()
    .single();

  if (deviceError || !device) return jsonResponse({ error: "device_creation_failed" }, 500);

  const code = generatePairingCode();
  const expiresAt = new Date(Date.now() + CODE_TTL_SECONDS * 1000).toISOString();

  const { error: codeError } = await supabase.from("pairing_codes").insert({
    space_id: null,
    device_id: device.id,
    code,
    code_type: "device_provisioning",
    expires_at: expiresAt,
    max_uses: 1,
  });

  if (codeError) return jsonResponse({ error: "pairing_code_creation_failed" }, 500);

  return jsonResponse({
    device_id: device.id,
    code,
    expires_at: expiresAt,
    poll_interval_seconds: 3,
  });
});
