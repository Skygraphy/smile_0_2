// Lieblingsbilder (migrations/0076, 2026-10-14): marked on the Frame when
// its controls allow it, by its managers in the app, listed with who and
// when, removed in bulk -- and only ever photos of the Frame's own albums.
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

async function postPhoto(channelId: string, senderId: string): Promise<string> {
  const path = `test/${crypto.randomUUID()}.jpg`;
  const { status, body } = await svc("media_items", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({
      channel_id: channelId,
      sender_id: senderId,
      media_type: "photo",
      storage_path_original: path,
      storage_path_display: path,
      processing_status: "ready",
    }),
  });
  assertEquals(status, 201, JSON.stringify(body));
  return (body as { id: string }[])[0].id;
}

Deno.test("Lieblingsbilder: marked on the Frame and in the app, listed, removed", async () => {
  const owner = await createThrowawayUser("favown");
  const stranger = await createThrowawayUser("favstr");
  let space: string | undefined;
  let otherSpace: string | undefined;
  try {
    await ensureProfile(owner.id, "FAV Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    const { accessToken: strangerToken } = await accessTokenFor(stranger.email);
    space = await createSpace(accessToken, "FAV Space");
    otherSpace = await createSpace(accessToken, "FAV Other");
    const album = await createChannel(accessToken, space, "FAV Album");
    const foreign = await createChannel(accessToken, otherSpace, "FAV Foreign");
    const photoA = await postPhoto(album, owner.id);
    const photoB = await postPhoto(album, owner.id);
    const foreignPhoto = await postPhoto(foreign, owner.id);

    const created = await invoke("create-frame", accessToken, { space_id: space, name: "FAV Frame" });
    const frameId = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code: created.body.pairing_code });
    const frameToken = claim.body.access_token as string;
    assertEquals((await invoke("assign-frame-channel", accessToken, { frame_id: frameId, channel_id: album })).status, 200);
    const batch = (extra: Record<string, unknown> = {}) =>
      invoke("get-media-batch", "irrelevant-anon-call", { access_token: frameToken, ...extra });

    // A new Frame (level 3): may mark and play favorites.
    const first = await batch();
    assertEquals(first.body.settings.controls.favorite, true);
    assertEquals(first.body.favorites, []);

    // Marked on the Frame -- the answer already carries it.
    assertEquals((await batch({ favorite: { media_item_id: photoA, on: true } })).body.favorites, [photoA]);
    // A photo of an album that isn't on the Frame is ignored.
    assertEquals((await batch({ favorite: { media_item_id: foreignPhoto, on: true } })).body.favorites, [photoA]);

    // Added in the app by a manager; a stranger can't.
    const add = (token: string, media: string, by: string) =>
      asUser("frame_favorites", token, {
        method: "POST",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({ frame_id: frameId, media_item_id: media, added_by: by }),
      });
    assertEquals((await add(accessToken, photoB, owner.id)).status, 201);
    assertEquals((await add(strangerToken, photoB, stranger.id)).status >= 400, true);

    // Listed newest first, with who marked it (null = the Frame itself).
    const listed = await invoke("list-frame-favorites", accessToken, { frame_id: frameId });
    assertEquals(listed.status, 200);
    const items = listed.body.items as { added_by: string | null; added_by_name: string | null; media: { id: string } }[];
    assertEquals(items.map((i) => i.media.id), [photoB, photoA]);
    assertEquals(items[0].added_by_name, "FAV Owner");
    assertEquals(items[1].added_by, null);
    assertEquals((await invoke("list-frame-favorites", strangerToken, { frame_id: frameId })).status, 404);

    // Taken back on the Frame.
    assertEquals((await batch({ favorite: { media_item_id: photoB, on: false } })).body.favorites, [photoA]);

    // Level 2: marking on the Frame isn't allowed any more.
    await asUser(`frames?id=eq.${frameId}`, accessToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ control_level: 2, controls: { next: true, pause: true } }),
    });
    assertEquals((await batch({ favorite: { media_item_id: photoB, on: true } })).body.favorites, [photoA]);

    // Removed in bulk from the app.
    const removed = await asUser(`frame_favorites?frame_id=eq.${frameId}`, accessToken, { method: "DELETE" });
    assertEquals(removed.status, 204);
    assertEquals((await batch()).body.favorites, []);
  } finally {
    if (space) await deleteSpace(space);
    if (otherSpace) await deleteSpace(otherSpace);
    await deleteUser(owner.id);
    await deleteUser(stranger.id);
  }
});
