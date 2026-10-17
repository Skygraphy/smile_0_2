// Titles for photos and videos (migrations/0084, 2026-10-17): sent with the
// upload, changed by the sender or the album's admins, delivered to Frames,
// and shown or hidden there ("captions" control).
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  accessTokenFor,
  asUser,
  createChannel,
  createSpace,
  createThrowawayUser,
  deleteSpace,
  deleteUser,
  ensureProfile,
  invoke,
  svc,
} from "./helpers.ts";

const rpc = (fn: string, token: string, args: unknown) =>
  asUser(`rpc/${fn}`, token, { method: "POST", body: JSON.stringify(args) });

Deno.test("captions: upload, edit, Frame delivery and switch", async () => {
  const owner = await createThrowawayUser("capown");
  const stranger = await createThrowawayUser("capstr");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "Cap Owner");
    await ensureProfile(stranger.id, "Cap Stranger");
    const { accessToken } = await accessTokenFor(owner.email);
    const strangerToken = (await accessTokenFor(stranger.email)).accessToken;
    space = await createSpace(accessToken, "Cap Space");
    const album = await createChannel(accessToken, space, "Cap Album");

    // Sent with a title (trimmed), and one without.
    const created = await invoke("create-upload", accessToken, {
      channel_id: album,
      items: [
        { media_type: "photo", mime_type: "image/jpeg", file_extension: "jpg", caption: "  Schau Oma, da waren wir schon einmal  " },
        { media_type: "photo", mime_type: "image/jpeg", file_extension: "jpg" },
      ],
    });
    assertEquals(created.status, 200, JSON.stringify(created.body));
    const ids = (created.body.items as { media_item_id: string }[]).map((i) => i.media_item_id);
    const row = async (id: string) =>
      ((await svc(`media_items?id=eq.${id}&select=caption`)).body as { caption: string | null }[])[0];
    assertEquals((await row(ids[0])).caption, "Schau Oma, da waren wir schon einmal");
    assertEquals((await row(ids[1])).caption, null);

    // The sender changes it; a stranger may not; empty removes it.
    assertEquals((await rpc("set_media_caption", accessToken, { p_media_item_id: ids[1], p_caption: "Neu" })).status, 204);
    assertEquals((await row(ids[1])).caption, "Neu");
    assert((await rpc("set_media_caption", strangerToken, { p_media_item_id: ids[1], p_caption: "Hack" })).status >= 400);
    assertEquals((await row(ids[1])).caption, "Neu");
    await rpc("set_media_caption", accessToken, { p_media_item_id: ids[1], p_caption: "   " });
    assertEquals((await row(ids[1])).caption, null);
    await rpc("set_media_caption", accessToken, { p_media_item_id: ids[1], p_caption: "x".repeat(250) });
    assertEquals((await row(ids[1])).caption?.length, 200);

    // On a Frame: the title arrives with the photo.
    for (const id of ids) {
      await svc(`media_items?id=eq.${id}`, {
        method: "PATCH",
        body: JSON.stringify({ processing_status: "ready", storage_path_display: `${album}/${id}_display.jpg` }),
      });
    }
    const frame = await invoke("create-frame", accessToken, { space_id: space, name: "Cap Frame" });
    const frameId = frame.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code: frame.body.pairing_code });
    const frameToken = claim.body.access_token as string;
    assertEquals((await invoke("assign-frame-channel", accessToken, { frame_id: frameId, channel_id: album })).status, 200);
    const batch = (extra: Record<string, unknown> = {}) =>
      invoke("get-media-batch", "irrelevant-anon-call", { access_token: frameToken, ...extra });

    const first = await batch();
    assertEquals(first.status, 200, JSON.stringify(first.body));
    const byId = new Map((first.body.items as { media_item_id: string; caption: string | null }[]).map((i) => [i.media_item_id, i]));
    assertEquals(byId.get(ids[0])?.caption, "Schau Oma, da waren wir schon einmal");
    assertEquals(first.body.settings.show_captions, true);

    // Level 3 (new Frame): no Titel button, so the Frame may not switch.
    await batch({ set_settings: { show_captions: false } });
    assertEquals((await batch()).body.settings.show_captions, true);
    // With the captions control (level 4): it may.
    await svc(`frames?id=eq.${frameId}`, {
      method: "PATCH",
      body: JSON.stringify({ controls: { next: true, back: true, pause: true, newest: true, overview: true, album: true, duration: true, playback: false, favorite: true, favorites: true, captions: true }, control_level: 4 }),
    });
    const switched = await batch({ set_settings: { show_captions: false } });
    assertEquals(switched.body.settings.show_captions, false);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
    await deleteUser(stranger.id);
  }
});
