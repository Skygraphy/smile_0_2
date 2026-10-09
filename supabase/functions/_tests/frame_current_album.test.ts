// Which album a Frame shows is kept on the server (migrations/0069,
// 2026-10-09): the app switches it ("Jetzt zeigen"), a switch on the Frame
// is stored too, the last choice wins.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  svc,
  asUser,
  invoke,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
  createChannel,
} from "./helpers.ts";

Deno.test("app and Frame switch the shown album; last choice wins", async () => {
  const owner = await createThrowawayUser("fcaown");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "FCA Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "FCA Space");
    const albumA = await createChannel(accessToken, space, "FCA A");
    const albumB = await createChannel(accessToken, space, "FCA B");
    const albumC = await createChannel(accessToken, space, "FCA C");

    const created = await invoke("create-frame", accessToken, { space_id: space, name: "FCA Frame" });
    const frameId = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code: created.body.pairing_code });
    const frameToken = claim.body.access_token as string;
    for (const album of [albumA, albumB]) {
      assertEquals((await invoke("assign-frame-channel", accessToken, { frame_id: frameId, channel_id: album })).status, 200);
    }
    const batch = (extra: Record<string, unknown> = {}) =>
      invoke("get-media-batch", "irrelevant-anon-call", { access_token: frameToken, ...extra });
    const current = async () =>
      ((await svc(`frames?id=eq.${frameId}&select=current_channel_id`)).body as { current_channel_id: string | null }[])[0]
        .current_channel_id;

    // First sync: the first album, and the server remembers it.
    assertEquals((await batch()).body.channel_id, albumA);
    assertEquals(await current(), albumA);

    // The app switches to B: the Frame's next sync shows B, and the other
    // managers get a push (event carries the album).
    const patch = (data: unknown) =>
      asUser(`frames?id=eq.${frameId}`, accessToken, {
        method: "PATCH",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify(data),
      });
    assertEquals((await patch({ current_channel_id: albumB })).status, 204);
    assertEquals((await batch()).body.channel_id, albumB);
    const { body: events } = await svc(
      `internal_calls?fn=eq.notify-event&body->>kind=eq.frame_changed&select=body&order=id.desc&limit=10`,
    );
    assertEquals(
      (events as { body: { payload: Record<string, unknown> } }[]).some(
        (e) => e.body.payload.frame_id === frameId && e.body.payload.current_channel_id === albumB,
      ),
      true,
    );

    // An album that isn't on the Frame can't be chosen.
    assertEquals((await patch({ current_channel_id: albumC })).status >= 400, true);

    // A switch on the Frame itself (back to A) wins over the app's B.
    assertEquals((await batch({ select_channel_id: albumA })).body.channel_id, albumA);
    assertEquals(await current(), albumA);
    assertEquals((await batch()).body.channel_id, albumA);
    assertEquals((await batch({ select_channel_id: albumC })).status, 403);

    // Taking the shown album off the Frame falls back to the first one left.
    await asUser(`frame_channels?frame_id=eq.${frameId}&channel_id=eq.${albumA}`, accessToken, { method: "DELETE" });
    assertEquals(await current(), null);
    assertEquals((await batch()).body.channel_id, albumB);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
