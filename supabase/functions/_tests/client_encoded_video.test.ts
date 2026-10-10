// Photos and videos prepared on the phone (2026-10-09/10) go straight to
// where they are served from; complete-upload only marks them ready -- no
// worker task (~30 s start), no copying.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireEnv,
  req,
  asService,
  svc,
  invoke,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
  createChannel,
} from "./helpers.ts";

async function preparedUpload(kind: "photo" | "video") {
  const { url, anonKey } = requireEnv();
  const owner = await createThrowawayUser(`ce${kind}`);
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "CE Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "CE Space");
    const album = await createChannel(accessToken, space, "CE Album");
    const mime = kind === "video" ? "video/mp4" : "image/jpeg";

    const created = await invoke("create-upload", accessToken, {
      channel_id: album, media_type: kind, mime_type: mime, file_extension: kind === "video" ? "mp4" : "jpg",
      file_size_bytes: 16, client_encoded: true,
    });
    assertEquals(created.status, 200, JSON.stringify(created.body));
    const { media_item_id: id, display_path, display_token, thumb_path, thumb_token } = created.body;

    const put = (bucket: string, p: string, t: string, type: string) =>
      fetch(`${url}/storage/v1/object/upload/sign/${bucket}/${p}?token=${t}`, {
        method: "PUT",
        headers: { apikey: anonKey, "Content-Type": type },
        body: new Uint8Array(16),
      });
    assertEquals((await put("media-display", display_path, display_token, mime)).status, 200);
    assertEquals((await put("media-thumbnails", thumb_path, thumb_token, "image/jpeg")).status, 200);

    const done = await invoke("complete-upload", accessToken, {
      media_item_id: id, client_encoded: true, direct: true,
      width: kind === "video" ? 720 : 2048, height: kind === "video" ? 1280 : 1536,
      ...(kind === "video" ? { duration_seconds: 6.3 } : {}),
    });
    assertEquals(done.body.status, "ready", JSON.stringify(done.body));

    const { body: rows } = await svc(`media_items?id=eq.${id}&select=processing_status,storage_path_display,storage_path_thumbnail,width`);
    assertEquals(rows[0].processing_status, "ready");
    assertEquals([rows[0].storage_path_display, rows[0].storage_path_thumbnail], [display_path, thumb_path]);
    const listed = async (bucket: string, file: string) => {
      const folder = file.split("/").slice(0, -1).join("/");
      const { body } = await req(
        `${url}/storage/v1/object/list/${bucket}`,
        asService({ method: "POST", body: JSON.stringify({ prefix: folder }) }),
      );
      return (body as { name: string }[]).some((o) => file.endsWith(o.name));
    };
    assertEquals(await listed("media-display", display_path), true);
    assertEquals(await listed("media-thumbnails", thumb_path), true);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
}

Deno.test("prepared video goes straight to its place and is ready at once", () => preparedUpload("video"));
Deno.test("prepared photo goes straight to its place and is ready at once", () => preparedUpload("photo"));

Deno.test("a selection of photos: one request to register, one to mark ready, order kept", async () => {
  const { url, anonKey } = requireEnv();
  const owner = await createThrowawayUser("cebatch");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "CB Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "CB Space");
    const album = await createChannel(accessToken, space, "CB Album");
    const item = { media_type: "photo", mime_type: "image/jpeg", file_extension: "jpg", file_size_bytes: 16, client_encoded: true };
    const created = await invoke("create-upload", accessToken, { channel_id: album, items: [item, item, item] });
    assertEquals(created.status, 200, JSON.stringify(created.body));
    const slots = created.body.items as Record<string, string>[];
    assertEquals(slots.length, 3);

    for (const slot of slots) {
      for (const [bucket, path, token] of [
        ["media-display", slot.display_path, slot.display_token],
        ["media-thumbnails", slot.thumb_path, slot.thumb_token],
      ]) {
        const res = await fetch(`${url}/storage/v1/object/upload/sign/${bucket}/${path}?token=${token}`, {
          method: "PUT",
          headers: { apikey: anonKey, "Content-Type": "image/jpeg" },
          body: new Uint8Array(16),
        });
        assertEquals(res.status, 200);
      }
    }
    const done = await invoke("complete-upload", accessToken, {
      items: slots.map((s) => ({ media_item_id: s.media_item_id, width: 2048, height: 1536 })),
    });
    assertEquals((done.body.items as { status: string }[]).map((r) => r.status), ["ready", "ready", "ready"]);

    const { body: rows } = await svc(`media_items?channel_id=eq.${album}&select=id,processing_status&order=created_at`);
    assertEquals((rows as { id: string }[]).map((r) => r.id), slots.map((s) => s.media_item_id), "order kept");
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
