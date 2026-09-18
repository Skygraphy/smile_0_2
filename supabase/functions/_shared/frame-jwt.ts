// Mints and verifies short-lived access tokens for Smile-Frame devices.
//
// Frames never get a normal Supabase Auth user account, and (architecture
// reset, see migrations/0031_architecture_reset.sql) no longer authenticate
// directly against PostgREST/RLS at all -- every Frame-initiated read/write
// goes through a service-role Edge Function instead. This token exists
// purely so those functions (claim-frame-pairing, refresh-frame-token,
// submit-heartbeat, get-media-batch) can tell "this really is the Frame
// that was paired with frame_id X, on credential version Y" apart from
// anyone who merely knows the frame_id, without a full Supabase Auth
// session for a row that has no auth.users entry.
//
// Short-lived (1h) and meant to be proactively renewed via
// refresh-frame-token well before expiry, unlike the smile_0_1 prototype's
// 5-year token (no refresh mechanism at all).
import { create, verify, getNumericDate, type Payload } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

// Named DEVICE_JWT_SECRET (not FRAME_JWT_SECRET) -- kept from before the
// architecture reset on purpose, so this doesn't need a new Supabase
// project secret set before Phase 2 can deploy. Value is the project's
// Legacy JWT Secret (Dashboard -> Project Settings -> API -> JWT Keys).
const JWT_SECRET = Deno.env.get("DEVICE_JWT_SECRET") ?? "";
const ACCESS_TOKEN_TTL_SECONDS = 60 * 60; // 1 hour.

let cachedKey: CryptoKey | null = null;

async function getKey(): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  if (!JWT_SECRET) {
    throw new Error("DEVICE_JWT_SECRET is not set for this Edge Function.");
  }
  cachedKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(JWT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  return cachedKey;
}

export interface FrameClaims {
  frame_id: string;
  space_id: string;
  credential_version: number;
}

export async function mintFrameAccessToken(
  claims: FrameClaims,
): Promise<{ token: string; expiresAt: string }> {
  const key = await getKey();
  const exp = getNumericDate(ACCESS_TOKEN_TTL_SECONDS);
  const payload: Payload = {
    role: "authenticated",
    // This token is never sent to PostgREST any more (see header comment),
    // only verified here by our own code -- sub/aud/iss are cosmetic at
    // this point, kept for shape-compatibility with the pre-reset token.
    sub: claims.frame_id,
    aud: "authenticated",
    iss: "supabase",
    frame_id: claims.frame_id,
    space_id: claims.space_id,
    credential_version: claims.credential_version,
    iat: getNumericDate(0),
    exp,
  };
  const token = await create({ alg: "HS256", typ: "JWT" }, payload, key);
  return { token, expiresAt: new Date(exp * 1000).toISOString() };
}

export async function verifyFrameAccessToken(token: string): Promise<FrameClaims> {
  const key = await getKey();
  const payload = await verify(token, key);
  if (!payload.frame_id || !payload.space_id) {
    throw new Error("Token is missing frame_id/space_id claims.");
  }
  return {
    frame_id: String(payload.frame_id),
    space_id: String(payload.space_id),
    credential_version: Number(payload.credential_version ?? 1),
  };
}
