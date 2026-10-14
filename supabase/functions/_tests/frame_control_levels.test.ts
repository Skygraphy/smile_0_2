// Frame control levels and playback (migrations/0075, 2026-10-14): the
// Frame gets them with every sync, may change itself only what its controls
// allow, and the app's remote control is validated before it is sent.
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

Deno.test("Frame settings: delivered, changed on the Frame only as allowed, remote validated", async () => {
  const owner = await createThrowawayUser("fclown");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "FCL Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "FCL Space");
    const album = await createChannel(accessToken, space, "FCL Album");

    const created = await invoke("create-frame", accessToken, { space_id: space, name: "FCL Frame" });
    const frameId = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code: created.body.pairing_code });
    const frameToken = claim.body.access_token as string;
    assertEquals((await invoke("assign-frame-channel", accessToken, { frame_id: frameId, channel_id: album })).status, 200);
    const batch = (extra: Record<string, unknown> = {}) =>
      invoke("get-media-batch", "irrelevant-anon-call", { access_token: frameToken, ...extra });
    const row = async () =>
      ((await svc(`frames?id=eq.${frameId}&select=control_level,slideshow_interval_seconds,play_order,show_clock`))
        .body as Record<string, unknown>[])[0];

    // A new Frame: level 3 "Einfach", playback defaults -- all in the sync.
    const first = await batch();
    assertEquals(first.body.settings.control_level, 3);
    assertEquals(first.body.settings.controls.newest, true);
    assertEquals(first.body.settings.controls.duration, false);
    assertEquals(first.body.settings.content_mode, "album");
    assertEquals(first.body.settings.show_clock, false);

    // Level 3 may not change the display time or playback on the Frame.
    await batch({ set_settings: { slideshow_interval_seconds: 20, play_order: "shuffle" } });
    assertEquals((await row()).slideshow_interval_seconds, 8);
    assertEquals((await row()).play_order, "oldest");

    // The app raises it to level 5 (and turns the clock on).
    const patch = await asUser(`frames?id=eq.${frameId}`, accessToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        control_level: 5,
        controls: { next: true, back: true, pause: true, newest: true, overview: true, album: true, duration: true, playback: true },
        show_clock: true,
      }),
    });
    assertEquals(patch.status, 204);

    // Now the Frame may -- and the answer already carries it. Values out of
    // range are still ignored.
    const changed = await batch({ set_settings: { slideshow_interval_seconds: 20, play_order: "shuffle", show_clock: false } });
    assertEquals(changed.body.settings.slideshow_interval_seconds, 20);
    assertEquals(changed.body.settings.play_order, "shuffle");
    assertEquals((await row()).show_clock, false);
    await batch({ set_settings: { slideshow_interval_seconds: 99999, play_order: "sideways" } });
    assertEquals((await row()).slideshow_interval_seconds, 20);
    assertEquals((await row()).play_order, "shuffle");

    // Remote control: unknown commands and "show" without a photo are refused
    // before anything is sent; a valid one goes through (no FCM token here).
    assertEquals((await invoke("notify-frame", accessToken, { frame_id: frameId, command: "explode" })).status, 400);
    assertEquals((await invoke("notify-frame", accessToken, { frame_id: frameId, command: "show" })).status, 400);
    const pause = await invoke("notify-frame", accessToken, { frame_id: frameId, command: "pause" });
    assertEquals(pause.status, 200);

    // Someone who doesn't manage the Frame can't steer it.
    const stranger = await createThrowawayUser("fclstr");
    try {
      const { accessToken: strangerToken } = await accessTokenFor(stranger.email);
      assertEquals((await invoke("notify-frame", strangerToken, { frame_id: frameId, command: "next" })).status, 404);
    } finally {
      await deleteUser(stranger.id);
    }
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
