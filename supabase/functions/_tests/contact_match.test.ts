// "Aus Kontakten", stage 1 (migrations/0082): hashed email addresses from
// the phone book find exactly the matching Smile accounts -- never oneself,
// never for signed-out callers.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  asUser,
  accessTokenFor,
  createThrowawayUser,
  deleteUser,
  ensureProfile,
  req,
  requireEnv,
} from "./helpers.ts";

async function sha256(text: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const match = (token: string, hashes: string[]) =>
  asUser("rpc/match_contact_emails", token, { method: "POST", body: JSON.stringify({ hashes }) });

Deno.test("contact match: hashed emails find accounts, nothing else", async () => {
  const a = await createThrowawayUser("cma");
  const b = await createThrowawayUser("cmb");
  try {
    await ensureProfile(a.id, "Contact A");
    await ensureProfile(b.id, "Contact B");
    const ta = (await accessTokenFor(a.email)).accessToken;

    const hb = await sha256(b.email.trim().toLowerCase());
    const ha = await sha256(a.email.trim().toLowerCase());
    const unknown = await sha256(`nobody-${crypto.randomUUID()}@example.com`);

    const found = await match(ta, [hb, ha, unknown, "not-a-hash"]);
    assertEquals(found.status, 200, JSON.stringify(found.body));
    // Only B: not oneself, not the unknown address.
    assertEquals(found.body.length, 1, JSON.stringify(found.body));
    assertEquals(found.body[0].user_id, b.id);
    assertEquals(found.body[0].email_hash, hb);
    assertEquals(found.body[0].display_name, "Contact B");
    // Upper-case hex is the same hash.
    assertEquals((await match(ta, [hb.toUpperCase()])).body.length, 1);
    assertEquals((await match(ta, [])).body.length, 0);

    const { url, anonKey } = requireEnv();
    const anon = await req(`${url}/rest/v1/rpc/match_contact_emails`, {
      method: "POST",
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
      body: JSON.stringify({ hashes: [hb] }),
    });
    assert(anon.status >= 400, "anon may match");
  } finally {
    await deleteUser(a.id);
    await deleteUser(b.id);
  }
});
