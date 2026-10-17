// Smile names (migrations/0080, 2026-10-17): unique, set by oneself, found
// only by typing them exactly; the web page learns just the display name.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  asUser,
  accessTokenFor,
  createChannel,
  createSpace,
  createThrowawayUser,
  deleteSpace,
  deleteUser,
  ensureProfile,
  requireEnv,
  req,
} from "./helpers.ts";

const rpc = (fn: string, token: string, args: unknown) =>
  asUser(`rpc/${fn}`, token, { method: "POST", body: JSON.stringify(args) });
const setHandle = (token: string, userId: string, handle: string | null) =>
  asUser(`profiles?user_id=eq.${userId}`, token, { method: "PATCH", body: JSON.stringify({ handle }) });

Deno.test("smile names: unique, exact search only, card page", async () => {
  const a = await createThrowawayUser("hdla");
  const b = await createThrowawayUser("hdlb");
  let space: string | undefined;
  const tag = crypto.randomUUID().slice(0, 6);
  const name = `test.${tag}`;
  try {
    await ensureProfile(a.id, "Handle A");
    await ensureProfile(b.id, "Handle B");
    const ta = (await accessTokenFor(a.email)).accessToken;
    const tb = (await accessTokenFor(b.email)).accessToken;

    // Wrong shapes and kept-back names are refused.
    for (const bad of ["ab", "Test.Upper", ".dot", "dot.", "a..b", "smile", "with space", "x".repeat(25)]) {
      const r = await setHandle(ta, a.id, bad);
      assert(r.status >= 400, `${bad} accepted`);
    }
    assertEquals((await rpc("handle_available", ta, { raw: name })).body, true);
    assertEquals((await setHandle(ta, a.id, name)).status, 204);
    // The own name counts as free for oneself, taken for everyone else.
    assertEquals((await rpc("handle_available", ta, { raw: name })).body, true);
    assertEquals((await rpc("handle_available", tb, { raw: `@${name.toUpperCase()}` })).body, false);
    assert((await setHandle(tb, b.id, name)).status >= 400, "duplicate accepted");

    // Exact (with "@" and any case) finds one; a part finds nobody; oneself neither.
    const found = await rpc("find_person_by_handle", tb, { raw: ` @${name.toUpperCase()} ` });
    assertEquals(found.body.length, 1, JSON.stringify(found.body));
    assertEquals(found.body[0].user_id, a.id);
    assertEquals(found.body[0].display_name, "Handle A");
    assertEquals(found.body[0].manages_a_space, false);
    assertEquals((await rpc("find_person_by_handle", tb, { raw: `test.${tag.slice(0, 3)}` })).body.length, 0);
    assertEquals((await rpc("find_person_by_handle", ta, { raw: name })).body.length, 0);

    // Not for signed-out callers.
    const { url, anonKey } = requireEnv();
    const anon = await req(`${url}/rest/v1/rpc/find_person_by_handle`, {
      method: "POST",
      headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
      body: JSON.stringify({ raw: name }),
    });
    assert(anon.status >= 400, "anon may search");

    // The card page: the display name, nothing else.
    const page = await req(`${url}/functions/v1/invite-preview?handle=${encodeURIComponent("@" + name)}`);
    assertEquals(page.body, { status: "ok", kind: "person", name: "Handle A", handle: name });
    assertEquals((await req(`${url}/functions/v1/invite-preview?handle=nobody.${tag}`)).body.status, "invalid");

    // Albums to invite into: only those of Spaces one manages.
    space = await createSpace(ta, "Handle Space");
    const album = await createChannel(ta, space, "Handle Album");
    const mine = await rpc("albums_i_can_invite_to", ta, {});
    assertEquals(mine.body.map((r: { channel_id: string }) => r.channel_id), [album]);
    assertEquals((await rpc("albums_i_can_invite_to", tb, {})).body.length, 0);
    assertEquals((await rpc("find_person_by_handle", tb, { raw: name })).body[0].manages_a_space, true);

    // Clearing frees the name.
    assertEquals((await setHandle(ta, a.id, null)).status, 204);
    assertEquals((await rpc("handle_available", tb, { raw: name })).body, true);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(a.id);
    await deleteUser(b.id);
  }
});
