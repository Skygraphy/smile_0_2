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
    const batch = await invoke("get-media-batch", "irrelevant-anon-call", { access_token: retry.body.access_token });
    assertEquals(batch.status, 200);

    // 0116: s1 still works too -- of two answers at the same moment the
    // Frame may have kept the older one (2026-11-23, kitchen Frame).
    const viaS1 = await refresh(s1);
    assertEquals(viaS1.status, 200, JSON.stringify(viaS1.body));
    const s3 = viaS1.body.refresh_secret as string;

    // Using the current one (s3) retires all the others for good.
    const proven = await refresh(s3);
    assertEquals(proven.status, 200);
    for (const old of [s0, s1, s2]) assertEquals((await refresh(old)).status, 401);
    // ...but s3 is now the fallback (the answer with s4 could be lost too).
    assertEquals((await refresh(s3)).status, 200);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});

Deno.test("refresh: two refreshes at the same moment both succeed, the older secret still works", async () => {
  const owner = await createThrowawayUser("rgrace");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "RR Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "RR Space");
    const created = await invoke("create-frame", accessToken, { space_id: space, name: "RR Frame" });
    const frameId = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code: created.body.pairing_code });
    const s0 = claim.body.refresh_secret as string;
    const refresh = (secret: string) =>
      invoke("refresh-frame-token", "irrelevant-anon-call", { frame_id: frameId, refresh_secret: secret });

    const [a, b] = await Promise.all([refresh(s0), refresh(s0)]);
    assertEquals([a.status, b.status], [200, 200], JSON.stringify([a.body, b.body]));
    // The older answer's access token is already stale (the other rotated
    // after it) -- exactly the one the Frame must still get in with.
    const batchA = await invoke("get-media-batch", "irrelevant-anon-call", { access_token: a.body.access_token });
    const batchB = await invoke("get-media-batch", "irrelevant-anon-call", { access_token: b.body.access_token });
    assertEquals([batchA.status, batchB.status].sort(), [200, 401]);
    const older = batchA.status === 401 ? a : b;
    const c = await refresh(older.body.refresh_secret as string);
    assertEquals(c.status, 200, JSON.stringify(c.body));
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
