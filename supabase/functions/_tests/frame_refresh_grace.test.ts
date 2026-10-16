// A Frame that misses the answer of a token refresh is not locked out
// (migrations/0078, 2026-10-15: the kitchen Frame was, for days): the
// previous secret works until the new one has been used once.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  invoke,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
} from "./helpers.ts";

Deno.test("refresh: a missed answer can be retried, a used secret retires the one before", async () => {
  const owner = await createThrowawayUser("rgown");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "RG Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "RG Space");
    const created = await invoke("create-frame", accessToken, { space_id: space, name: "RG Frame" });
    const frameId = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code: created.body.pairing_code });
    const s0 = claim.body.refresh_secret as string;
    const refresh = (secret: string) =>
      invoke("refresh-frame-token", "irrelevant-anon-call", { frame_id: frameId, refresh_secret: secret });

    // The answer carrying s1 "never arrives".
    const first = await refresh(s0);
    assertEquals(first.status, 200);
    const s1 = first.body.refresh_secret as string;

    // The Frame asks again with what it has -- and gets in.
    const retry = await refresh(s0);
    assertEquals(retry.status, 200, JSON.stringify(retry.body));
    const s2 = retry.body.refresh_secret as string;
    // The lost one is gone; its access token works.
    assertEquals((await refresh(s1)).status, 401);
    const batch = await invoke("get-media-batch", "irrelevant-anon-call", { access_token: retry.body.access_token });
    assertEquals(batch.status, 200);

    // Using s2 retires s0 for good.
    const third = await refresh(s2);
    assertEquals(third.status, 200);
    assertEquals((await refresh(s0)).status, 401);
    // ...but s2 is now the fallback (the answer with s3 could be lost too).
    assertEquals((await refresh(s2)).status, 200);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
