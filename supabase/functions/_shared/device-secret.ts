// Generates and hashes Frame refresh secrets, and generates pairing
// codes. Only the SHA-256 hash of a refresh secret is ever persisted
// (frame_credentials.refresh_secret_hash) -- the raw secret exists only
// transiently, in the single HTTP response body of the Frame that just
// (re)claimed it.

export function generateRefreshSecret(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

export async function hashSecret(secret: string): Promise<string> {
  const data = new TextEncoder().encode(secret);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return toHex(new Uint8Array(digest));
}

// Unambiguous charset (no 0/O, 1/I/L) -- meant to be readable off a Frame's
// screen and typed as a fallback to scanning its QR code.
const PAIRING_CODE_CHARSET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export function generatePairingCode(): string {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => PAIRING_CODE_CHARSET[b % PAIRING_CODE_CHARSET.length]).join("");
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}
