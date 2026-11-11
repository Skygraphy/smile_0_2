// Voucher codes (2026-11-11, migrations/0102): SMILE-XXXX-XXXX, 8 characters
// from 31 that can't be mixed up (no 0/O, 1/I/L). Upper/lower case and
// dashes don't matter. Only an HMAC with a secret pepper is stored, so a
// leaked table can't be tried offline.

const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
const LENGTH = 8;

/** The 8 characters of a typed/scanned code or link, else null. */
export function normalizeCode(input: string): string | null {
  let text = input.trim().toUpperCase();
  const link = text.match(/\/G\/([A-Z0-9-]+)/);
  if (link) text = link[1];
  text = text.replace(/[^A-Z0-9]/g, "");
  if (text.startsWith("SMILE") && text.length === LENGTH + 5) text = text.slice(5);
  if (text.length !== LENGTH) return null;
  // 0/O/1/I/L never occur in a code: with one of them it can't be right.
  for (const ch of text) if (!ALPHABET.includes(ch)) return null;
  return text;
}

export function newCode(): string {
  const bytes = new Uint8Array(LENGTH);
  let out = "";
  while (out.length < LENGTH) {
    crypto.getRandomValues(bytes);
    for (const b of bytes) {
      // 31 * 8 = 248: drop 248..255 so every character is equally likely.
      if (b < 248 && out.length < LENGTH) out += ALPHABET[b % 31];
    }
  }
  return out;
}

/** SMILE-K7P4-2QXM */
export function displayCode(code: string): string {
  return `SMILE-${code.slice(0, 4)}-${code.slice(4)}`;
}

export async function codeHash(code: string): Promise<string> {
  const pepper = Deno.env.get("VOUCHER_PEPPER") ?? "";
  if (!pepper) throw new Error("VOUCHER_PEPPER missing");
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(pepper), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(code));
  return Array.from(new Uint8Array(sig), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** A random token for a partner's link. */
export function newToken(): string {
  const bytes = new Uint8Array(18);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
