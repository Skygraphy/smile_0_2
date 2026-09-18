// Called by the physical Smile-Frame hardware itself (unauthenticated --
// the code alone, typed in by whoever is standing in front of the Frame,
// is the authorization, exactly like the code a Space Owner already saw
// when create-frame made this record) to bind to the pre-created frame row
// and receive its own credentials directly -- never relayed through the
// owner's phone. `frames.pairing_code` is globally unique
// (migrations/0031_architecture_reset.sql), so the code alone identifies
// the row; no frame_id needed. Much simpler than the pre-reset schema's
// three-step request/claim/poll dance (see that migration's header
// comment): reversing creation order means the row -- and its space_id --
// already exists by the time any device is involved, so there's no
// separate "owner claims the code" step to wait for any more.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { mintFrameAccessToken } from "../_shared/frame-jwt.ts";
import { generateRefreshSecret, hashSecret } from "../_shared/device-secret.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

interface ClaimRequest {
  code: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  let body: ClaimRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.code) return jsonResponse({ error: "code_required" }, 400);
  const code = body.code.trim().toUpperCase();

  const { data: frame, error: frameError } = await supabase
    .from("frames")
    .select("id, space_id, lifecycle_state, pairing_code_expires_at")
    .eq("pairing_code", code)
    .maybeSingle();

  if (frameError || !frame) return jsonResponse({ error: "invalid_code" }, 404);
  if (frame.lifecycle_state === "revoked") return jsonResponse({ error: "frame_revoked" }, 410);

  if (frame.lifecycle_state === "active") {
    // Retry after a dropped response: whoever still holds the pairing
    // code (already consumed once) can safely re-claim and get a fresh
    // credential set.
    return await mintAndReturn(frame.id, frame.space_id);
  }

  if (!frame.pairing_code_expires_at || new Date(frame.pairing_code_expires_at) < new Date()) {
    return jsonResponse({ error: "code_expired" }, 410);
  }

  // Guarded update: only the claim that actually flips lifecycle_state
  // gets to activate -- a concurrent duplicate claim falls through to the
  // "already active" branch above instead of racing the credential mint.
  const { data: activated, error: activateError } = await supabase
    .from("frames")
    .update({ lifecycle_state: "active", paired_at: new Date().toISOString() })
    .eq("id", frame.id)
    .eq("lifecycle_state", "pending")
    .select()
    .maybeSingle();

  if (activateError) return jsonResponse({ error: "activation_failed" }, 500);
  if (!activated) return jsonResponse({ error: "already_paired" }, 410);

  return await mintAndReturn(frame.id, frame.space_id);
});

async function mintAndReturn(frameId: string, spaceId: string): Promise<Response> {
  const { data: existingCredentials } = await supabase
    .from("frame_credentials")
    .select("refresh_secret_version")
    .eq("frame_id", frameId)
    .maybeSingle();

  const nextVersion = (existingCredentials?.refresh_secret_version ?? 0) + 1;
  const refreshSecret = generateRefreshSecret();
  const refreshSecretHash = await hashSecret(refreshSecret);

  const { error: credError } = await supabase.from("frame_credentials").upsert({
    frame_id: frameId,
    refresh_secret_hash: refreshSecretHash,
    refresh_secret_version: nextVersion,
    rotated_at: new Date().toISOString(),
  });
  if (credError) return jsonResponse({ error: "credential_creation_failed" }, 500);

  const { token, expiresAt } = await mintFrameAccessToken({
    frame_id: frameId,
    space_id: spaceId,
    credential_version: nextVersion,
  });

  return jsonResponse({
    status: "paired",
    frame_id: frameId,
    space_id: spaceId,
    access_token: token,
    access_token_expires_at: expiresAt,
    refresh_secret: refreshSecret,
  });
}
