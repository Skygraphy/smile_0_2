// Photos straight from the phone (migrations/0071, 2026-10-10): members
// upload prepared files into their album and insert the rows as ready --
// no Edge Function in between; the database checks and announces.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireEnv,
  svc,
  asUser,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
  createChannel,
} from "./helpers.ts";

Deno.test("member uploads directly and inserts ready photos; strangers and mismatches are refused", async () => {
  const { url, anonKey } = requireEnv();
  const member = await createThrowawayUser("dpmem");
  const stranger = await createThrowawayUser("dpstr");
  let space: string | undefined;
  try {
    await ensureProfile(member.id, "DP Member");
    await ensureProfile(stranger.id, "DP Stranger");
    const { accessToken } = await accessTokenFor(member.email);
    const { accessToken: strangerToken } = await accessTokenFor(stranger.email);
    space = await createSpace(accessToken, "DP Space");
    const album = await createChannel(accessToken, space, "DP Album");

    const upload = (token: string, bucket: string, name: string) =>
      fetch(`${url}/storage/v1/object/${bucket}/${name}`, {
        method: "POST",
        headers: { apikey: anonKey, Authorization: `Bearer ${token}`, "Content-Type": "image/jpeg" },
        body: new Uint8Array(16),
      });
    const ids = [crypto.randomUUID(), crypto.randomUUID()];
    for (const id of ids) {
      const res = await upload(accessToken, "media-display", `${album}/${id}_display.jpg`);
      assertEquals(res.status, 200, await res.text());
      assertEquals((await upload(accessToken, "media-thumbnails", `${album}/${id}_thumb.jpg`)).status, 200);
    }
    // A stranger can't put files into the album; nobody can use other names.
    const strangerId = crypto.randomUUID();
    assertEquals((await upload(strangerToken, "media-display", `${album}/${strangerId}_display.jpg`)).status >= 400, true);
    assertEquals((await upload(accessToken, "media-display", `${album}/whatever.jpg`)).status >= 400, true);

    const row = (id: string) => ({
      id,
      channel_id: album,
      sender_id: member.id,
      media_type: "photo",
      mime_type: "image/jpeg",
      storage_path_original: `${album}/${id}_display.jpg`,
      storage_path_display: `${album}/${id}_display.jpg`,
      storage_path_thumbnail: `${album}/${id}_thumb.jpg`,
      processing_status: "ready",
      width: 2048,
      height: 1536,
    });
    const insert = (rows: unknown[]) =>
      asUser("media_items", accessToken, {
        method: "POST",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify(rows),
      });
    assertEquals((await insert(ids.map(row))).status, 201);

    // In the order they were picked; announced (one push per album).
    const { body: rows } = await svc(`media_items?channel_id=eq.${album}&select=id,processing_status&order=created_at`);
    assertEquals((rows as { id: string }[]).map((r) => r.id), ids);
    const { body: events } = await svc(
      `internal_calls?fn=eq.notify-event&body->>kind=eq.media_ready&select=body&order=id.desc&limit=5`,
    );
    assertEquals(
      (events as { body: { payload: { channel_id: string } } }[]).some((e) => e.body.payload.channel_id === album),
      true,
    );

    // A "ready" row without its files is refused.
    const missing = crypto.randomUUID();
    assertEquals((await insert([row(missing)])).status >= 400, true);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(stranger.id);
    await deleteUser(member.id);
  }
});
