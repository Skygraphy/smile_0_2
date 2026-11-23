// Called proactively by a paired Frame (well before the current access
// token's 1h TTL expires) to trade its refresh secret for a new access
// token. Rotate-on-use: the presented secret is retired the moment it's
// spent, whether or not anything goes wrong afterward, so a leaked-but-
// unused secret has the shortest possible window.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { mintFrameAccessToken } from "../_shared/frame-jwt.ts";
import { generateRefreshSecret, hashSecret } from "../_shared/device-secret.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

interface RefreshRequest {
  frame_id: string;
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
  if (!body.frame_id || !body.refresh_secret) {
    return jsonResponse({ error: "frame_id_and_refresh_secret_required" }, 400);
  }

  const { data: frame } = await supabase
    .from("frames")
    .select("id, space_id, lifecycle_state, spaces(deleted_at)")
    .eq("id", body.frame_id)
    .maybeSingle();

  // Deleted (its Space was deleted) vs. merely revoked: a deleted Frame
  // has to go back to pairing, a revoked one just waits to be reactivated.
  if (!frame) return jsonResponse({ error: "frame_not_found" }, 403);
  // deno-lint-ignore no-explicit-any
  if (frame.lifecycle_state !== "active" || (frame.spaces as any)?.deleted_at) {
    return jsonResponse({ error: "frame_not_active" }, 403);
  }

  const providedHash = await hashSecret(body.refresh_secret);
  const newSecret = generateRefreshSecret();
  const newHash = await hashSecret(newSecret);

  // Two refreshes at the same moment (slideshow + push-triggered background
  // sync, 2026-11-23) both pass the check below; the guarded update lets
  // only one rotate, the other reads again and rotates after it -- before
  // it was turned away and the Frame could lock itself out.
  let newVersion = 0;
  for (let attempt = 0; ; attempt++) {
    const { data: credentials } = await supabase
      .from("frame_credentials")
      .select("*")
      .eq("frame_id", body.frame_id)
      .maybeSingle();

    if (!credentials || credentials.revoked_at) return jsonResponse({ error: "no_credentials" }, 403);

    // Valid: the current secret; the one before it (0078: the Frame missed
    // the answer that carried the current one); or any handed out since
    // the Frame last used the current one (0116: of two answers at the
    // same moment, the Frame may keep the older). Using the current one
    // proves the Frame has it, and retires all the others.
    const recent: string[] = credentials.recent_refresh_secret_hashes ?? [];
    const usesCurrent = providedHash === credentials.refresh_secret_hash;
    const usesOlder = !usesCurrent && (
      (!!credentials.previous_refresh_secret_hash && providedHash === credentials.previous_refresh_secret_hash) ||
      recent.includes(providedHash)
    );
    if (!usesCurrent && !usesOlder) {
      return jsonResponse({ error: "invalid_refresh_secret" }, 401);
    }

    newVersion = credentials.refresh_secret_version + 1;
    const { data: rotated, error: updateError } = await supabase
      .from("frame_credentials")
      .update({
        refresh_secret_hash: newHash,
        previous_refresh_secret_hash: usesCurrent ? credentials.refresh_secret_hash : credentials.previous_refresh_secret_hash,
        recent_refresh_secret_hashes: usesCurrent ? [] : [...recent, credentials.refresh_secret_hash].slice(-5),
        refresh_secret_version: newVersion,
        rotated_at: new Date().toISOString(),
      })
      // Guarded on the hash just read: a rotation in between makes this
      // match nothing, and the loop reads the new state.
      .eq("frame_id", body.frame_id)
      .eq("refresh_secret_hash", credentials.refresh_secret_hash)
      .select("frame_id")
      .maybeSingle();

    if (updateError) return jsonResponse({ error: "rotation_failed" }, 500);
    if (rotated) break;
    if (attempt >= 4) return jsonResponse({ error: "rotation_failed" }, 503);
  }

  const { token, expiresAt } = await mintFrameAccessToken({
    frame_id: frame.id,
    space_id: frame.space_id,
    credential_version: newVersion,
  });

  return jsonResponse({
    access_token: token,
    access_token_expires_at: expiresAt,
    refresh_secret: newSecret,
  });
});
