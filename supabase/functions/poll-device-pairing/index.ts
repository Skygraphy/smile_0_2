// Polled repeatedly by a pairing Smile-Frame (unauthenticated -- the
// device_id + code pair, known only to that Frame and whoever it showed
// the QR to, is the authorization). Returns "pending" until a Space Owner
// has claimed the code (claim-device-pairing); the first poll to observe
// the claim performs the actual activation and mints this device's own
// credentials, handed back in this same response and never relayed
// through the claiming phone.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { mintDeviceAccessToken } from "../_shared/device-jwt.ts";
import { generateRefreshSecret, hashSecret } from "../_shared/device-secret.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

interface PollRequest {
  device_id: string;
  code: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: PollRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.device_id || !body.code) return jsonResponse({ error: "device_id_and_code_required" }, 400);

  const { data: pairingCode, error: codeError } = await supabase
    .from("pairing_codes")
    .select("*")
    .eq("code", body.code)
    .eq("device_id", body.device_id)
    .eq("code_type", "device_provisioning")
    .single();

  if (codeError || !pairingCode) return jsonResponse({ error: "invalid_code" }, 404);
  if (new Date(pairingCode.expires_at) < new Date()) return jsonResponse({ error: "code_expired" }, 410);

  if (!pairingCode.space_id) {
    return jsonResponse({ status: "pending" });
  }

  if (pairingCode.use_count < pairingCode.max_uses) {
    // Guarded update: only the poll that actually flips use_count gets to
    // activate. A concurrent duplicate poll (e.g. a retried request that
    // wasn't actually dropped) falls through to the "already active"
    // branch below instead of minting a second, wasted credential set.
    const { data: claimedRow, error: claimError } = await supabase
      .from("pairing_codes")
      .update({ use_count: pairingCode.use_count + 1 })
      .eq("id", pairingCode.id)
      .lt("use_count", pairingCode.max_uses)
      .select()
      .maybeSingle();

    if (claimError) return jsonResponse({ error: "activation_failed" }, 500);
    if (claimedRow) {
      return await activateDevice(
        pairingCode.device_id,
        pairingCode.space_id,
        pairingCode.claimed_by_user_id,
        pairingCode.replace_device_id,
      );
    }
  }

  const { data: device } = await supabase
    .from("devices")
    .select("lifecycle_state")
    .eq("id", body.device_id)
    .maybeSingle();

  if (device && (device.lifecycle_state === "active" || device.lifecycle_state === "offline")) {
    // Retry after a dropped response: mint a fresh credential set. Safe
    // because only whoever still holds the not-yet-expired code could
    // reach this branch, and the exposure window is that code's short TTL.
    return await activateDevice(
      pairingCode.device_id,
      pairingCode.space_id,
      pairingCode.claimed_by_user_id,
      pairingCode.replace_device_id,
    );
  }

  return jsonResponse({ status: "pending" });
});

async function activateDevice(
  deviceId: string,
  spaceId: string,
  pairedByUserId: string | null,
  replaceDeviceId: string | null,
): Promise<Response> {
  await supabase
    .from("devices")
    .update({
      space_id: spaceId,
      lifecycle_state: "active",
      last_seen_at: new Date().toISOString(),
      paired_by_user_id: pairedByUserId,
    })
    .eq("id", deviceId);

  const { data: existingPolicy } = await supabase
    .from("device_policies")
    .select("*")
    .eq("device_id", deviceId)
    .maybeSingle();

  let policy = existingPolicy;
  if (!policy) {
    // "Gerät ersetzen" (migrations/0023_replace_device_on_pairing.sql):
    // carry the old device's settings over instead of a bare default, so
    // switching hardware doesn't quietly reset Channel-Wechsel/display
    // preferences. Best-effort -- a missing/failed copy still leaves a
    // perfectly usable default policy, never blocks pairing.
    const replacementPolicy = replaceDeviceId
      ? (await supabase.from("device_policies").select("*").eq("device_id", replaceDeviceId).maybeSingle()).data
      : null;
    const { data: newPolicy, error: policyError } = await supabase
      .from("device_policies")
      .insert({
        device_id: deviceId,
        ...(replacementPolicy
          ? {
              display_mode: replacementPolicy.display_mode,
              slideshow_interval_seconds: replacementPolicy.slideshow_interval_seconds,
              compliance_check_interval_minutes: replacementPolicy.compliance_check_interval_minutes,
              channel_switch_enabled: replacementPolicy.channel_switch_enabled,
              max_local_cache_gb: replacementPolicy.max_local_cache_gb,
            }
          : {}),
      })
      .select()
      .single();
    if (policyError || !newPolicy) return jsonResponse({ error: "policy_creation_failed" }, 500);
    policy = newPolicy;
  }

  if (replaceDeviceId) {
    await migrateFromReplacedDevice(deviceId, replaceDeviceId);
  }

  const { data: existingCredentials } = await supabase
    .from("device_credentials")
    .select("refresh_secret_version")
    .eq("device_id", deviceId)
    .maybeSingle();

  const nextVersion = (existingCredentials?.refresh_secret_version ?? 0) + 1;
  const refreshSecret = generateRefreshSecret();
  const refreshSecretHash = await hashSecret(refreshSecret);

  const { error: credError } = await supabase.from("device_credentials").upsert({
    device_id: deviceId,
    refresh_secret_hash: refreshSecretHash,
    refresh_secret_version: nextVersion,
    rotated_at: new Date().toISOString(),
  });
  if (credError) return jsonResponse({ error: "credential_creation_failed" }, 500);

  const { token, expiresAt } = await mintDeviceAccessToken({
    device_id: deviceId,
    space_id: spaceId,
    credential_version: nextVersion,
  });

  return jsonResponse({
    status: "paired",
    device_id: deviceId,
    space_id: spaceId,
    access_token: token,
    access_token_expires_at: expiresAt,
    refresh_secret: refreshSecret,
    policy,
  });
}

// "Gerät ersetzen": carries channel assignments and the photo backlog over
// from an old Frame to its replacement, then retires the old one.
// Best-effort throughout (logged via console.error, never thrown) --
// a partial migration is still far better than blocking this device's
// credential minting entirely, and is safe to re-run by hand if needed.
async function migrateFromReplacedDevice(newDeviceId: string, oldDeviceId: string): Promise<void> {
  try {
    const { data: oldAssignments } = await supabase
      .from("channel_memberships")
      .select("channel_id, sort_order")
      .eq("device_id", oldDeviceId)
      .eq("role", "device");

    if (oldAssignments && oldAssignments.length > 0) {
      await supabase.from("channel_memberships").insert(
        oldAssignments.map((a) => ({
          device_id: newDeviceId,
          channel_id: a.channel_id,
          role: "device",
          sort_order: a.sort_order,
        })),
      );
    }

    const { data: oldRecipients } = await supabase
      .from("media_recipients")
      .select("media_item_id, channel_id, sort_order, delivered_at, viewed_at, hidden_at")
      .eq("device_id", oldDeviceId);

    if (oldRecipients && oldRecipients.length > 0) {
      await supabase.from("media_recipients").upsert(
        oldRecipients.map((r) => ({ ...r, device_id: newDeviceId })),
        { onConflict: "media_item_id,device_id", ignoreDuplicates: true },
      );
    }

    await supabase.from("devices").update({ lifecycle_state: "retired" }).eq("id", oldDeviceId);
  } catch (err) {
    console.error("migrateFromReplacedDevice failed", oldDeviceId, "->", newDeviceId, err);
  }
}
