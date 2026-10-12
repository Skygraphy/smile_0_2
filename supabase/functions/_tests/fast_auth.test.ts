// Session check and work at once (_shared/fast-auth.ts, 2026-10-12): a
// token that names a real user but isn't signed by the server gets nothing
// -- not the data, not even "not a member".
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  invoke,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
  createChannel,
} from "./helpers.ts";

Deno.test("forged tokens get nothing from the fast read functions", async () => {
  const owner = await createThrowawayUser("faown");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "FA Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "FA Space");
    const album = await createChannel(accessToken, space, "FA Album");

    // Same claims, broken signature.
    const [header, payload] = accessToken.split(".");
    const forged = `${header}.${payload}.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`;

    const calls: [string, Record<string, unknown>][] = [
      ["get-signed-media-urls", { channel_id: album }],
      ["list-channel-members", { channel_id: album }],
      ["list-space-co-owners", { space_id: space }],
      ["list-my-channels", {}],
    ];
    for (const [fn, body] of calls) {
      const real = await invoke(fn, accessToken, body);
      assertEquals(real.status, 200, `${fn}: ${JSON.stringify(real.body)}`);
      const fake = await invoke(fn, forged, body);
      assertEquals(fake.status, 401, `${fn} answered a forged token: ${JSON.stringify(fake.body)}`);
    }
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
