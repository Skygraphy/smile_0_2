// Mints and verifies short-lived access tokens for Smile-Frame devices.
//
// Devices never get a normal Supabase Auth user account. Instead they hold
// a custom JWT (signed with the project's own JWT secret, so PostgREST/RLS
// accepts it exactly like a regular session token) carrying `device_id`,
// `space_id` and `credential_version` claims. RLS policies check these via
// the `is_own_device()` helper (see supabase/migrations/0009 and 0015).
//
// Unlike the smile_0_1 prototype (which minted a 5-year token because it
// never built a refresh mechanism), this token is short-lived (1h) and is
// meant to be proactively renewed via refresh-device-token well before
// expiry -- see plan Phase 2.
import { create, verify, getNumericDate, type Payload } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

// Named DEVICE_JWT_SECRET (not SUPABASE_JWT_SECRET) because the Supabase
// CLI reserves every secret name starting with SUPABASE_ for its own
// auto-injected variables and silently refuses to set anything under that
// prefix. Value is the project's Legacy JWT Secret (Dashboard -> Project
// Settings -> API -> JWT Keys -> Legacy JWT Secret).
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

export interface DeviceClaims {
  device_id: string;
  space_id: string;
  credential_version: number;
}

export async function mintDeviceAccessToken(
  claims: DeviceClaims,
): Promise<{ token: string; expiresAt: string }> {
  const key = await getKey();
  const exp = getNumericDate(ACCESS_TOKEN_TTL_SECONDS);
  const payload: Payload = {
    role: "authenticated",
    // PostgREST (unlike the Edge Functions gateway) rejects tokens missing
    // `sub`/`aud` with a 401 -- there's no real auth.users row for a
    // device, so `sub` is just the device's own id, which is fine since
    // every RLS policy for device-scoped tables checks the device_id
    // claim directly via is_own_device(), never auth.uid().
    sub: claims.device_id,
    aud: "authenticated",
    iss: "supabase",
    device_id: claims.device_id,
    space_id: claims.space_id,
    credential_version: claims.credential_version,
    iat: getNumericDate(0),
    exp,
  };
  const token = await create({ alg: "HS256", typ: "JWT" }, payload, key);
  return { token, expiresAt: new Date(exp * 1000).toISOString() };
}

export async function verifyDeviceAccessToken(token: string): Promise<DeviceClaims> {
  const key = await getKey();
  const payload = await verify(token, key);
  if (!payload.device_id || !payload.space_id) {
    throw new Error("Token is missing device_id/space_id claims.");
  }
  return {
    device_id: String(payload.device_id),
    space_id: String(payload.space_id),
    credential_version: Number(payload.credential_version ?? 1),
  };
}
