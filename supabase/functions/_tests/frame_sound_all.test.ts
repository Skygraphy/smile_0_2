// Ton for all videos from the Frame's sound button (2026-11-19,
// migrations/0108): allowed from level 3 (controls.sound_all), then the
// Frame may save video_sound itself; without it the change is ignored.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { accessTokenFor, asUser, createChannel, createSpace, createThrowawayUser, deleteSpace, deleteUser, ensureProfile, invoke, svc } from "./helpers.ts";

Deno.test("Frame sound for all videos: only with sound_all", async () => {
  const owner = await createThrowawayUser("fsaown");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "FSA Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "FSA Space");
    const album = await createChannel(accessToken, space, "FSA Album");
    const created = await invoke("create-frame", accessToken, { space_id: space, name: "FSA Frame" });
    const frameId = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "anon", { code: created.body.pairing_code });
    const frameToken = claim.body.access_token as string;
    await invoke("assign-frame-channel", accessToken, { frame_id: frameId, channel_id: album });
    const batch = (extra: Record<string, unknown> = {}) => invoke("get-media-batch", "anon", { access_token: frameToken, ...extra });
    const sound = async () => ((await svc(`frames?id=eq.${frameId}&select=video_sound`)).body as { video_sound: boolean }[])[0].video_sound;

    // A new Frame (level 3): allowed, the Frame turns sound off for all videos.
    const first = await batch();
    assertEquals(first.body.settings.controls.sound_all, true);
    const off = await batch({ set_settings: { video_sound: false } });
    assertEquals(off.body.settings.video_sound, false);
    assertEquals(await sound(), false);

    // Level 2 (no sound_all, no playback): ignored.
    await asUser(`frames?id=eq.${frameId}`, accessToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({
        control_level: 2,
        controls: { easy_stop: true, next: true, pause: true, back: false, newest: false, favorite: false, favorites: false, sound_all: false, overview: false, album: false, duration: false, captions: false, playback: false },
      }),
    });
    await batch({ set_settings: { video_sound: true } });
    assertEquals(await sound(), false);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
