// A video the phone already converted (2026-10-09) is taken as it is:
// ready right after the upload, no worker task (~30 s start) in between.
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

Deno.test("client-encoded video is ready at once with its own poster, nothing left behind", async () => {
  const { url, anonKey } = requireEnv();
  const owner = await createThrowawayUser("cevid");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "CE Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "CE Space");
    const album = await createChannel(accessToken, space, "CE Album");

    const created = await invoke("create-upload", accessToken, {
      channel_id: album, media_type: "video", mime_type: "video/mp4", file_extension: "mp4",
      file_size_bytes: 16, client_encoded: true,
    });
    assertEquals(created.status, 200, JSON.stringify(created.body));
    const { media_item_id: id, storage_path: path, token, poster_path: posterPath, poster_token: posterToken } = created.body;
    assertEquals(typeof posterToken, "string");

    const put = (p: string, t: string, type: string) =>
      fetch(`${url}/storage/v1/object/upload/sign/media-originals/${p}?token=${t}`, {
        method: "PUT",
        headers: { apikey: anonKey, "Content-Type": type },
        body: new Uint8Array(16),
      });
    assertEquals((await put(path, token, "video/mp4")).status, 200);
    assertEquals((await put(posterPath, posterToken, "image/jpeg")).status, 200);

    const done = await invoke("complete-upload", accessToken, {
      media_item_id: id, client_encoded: true, width: 1280, height: 720, duration_seconds: 6.3,
    });
    assertEquals(done.body.status, "ready", JSON.stringify(done.body));

    const { body: rows } = await svc(`media_items?id=eq.${id}&select=processing_status,storage_path_display,storage_path_thumbnail,width,height`);
    const item = rows[0];
    assertEquals([item.processing_status, item.width, item.height], ["ready", 1280, 720]);
    const listed = async (bucket: string, file: string) => {
      const folder = file.split("/").slice(0, -1).join("/");
      const { body } = await req(
        `${url}/storage/v1/object/list/${bucket}`,
        asService({ method: "POST", body: JSON.stringify({ prefix: folder }) }),
      );
      return (body as { name: string }[]).some((o) => file.endsWith(o.name));
    };
    assertEquals(await listed("media-display", item.storage_path_display), true);
    assertEquals(await listed("media-thumbnails", item.storage_path_thumbnail), true);
    assertEquals(await listed("media-originals", posterPath), false, "poster removed from originals");
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});

Deno.test("client-encoded photo is ready at once with its own thumbnail", async () => {
  const { url, anonKey } = requireEnv();
  const owner = await createThrowawayUser("cephoto");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "CP Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "CP Space");
    const album = await createChannel(accessToken, space, "CP Album");
    const created = await invoke("create-upload", accessToken, {
      channel_id: album, media_type: "photo", mime_type: "image/jpeg", file_extension: "jpg",
      file_size_bytes: 16, client_encoded: true,
    });
    assertEquals(created.status, 200, JSON.stringify(created.body));
    const { media_item_id: id, storage_path: path, token, poster_path: thumbPath, poster_token: thumbToken } = created.body;
    const put = (p: string, t: string) =>
      fetch(`${url}/storage/v1/object/upload/sign/media-originals/${p}?token=${t}`, {
        method: "PUT",
        headers: { apikey: anonKey, "Content-Type": "image/jpeg" },
        body: new Uint8Array(16),
      });
    assertEquals((await put(path, token)).status, 200);
    assertEquals((await put(thumbPath, thumbToken)).status, 200);
    const done = await invoke("complete-upload", accessToken, { media_item_id: id, client_encoded: true, width: 2048, height: 1536 });
    assertEquals(done.body.status, "ready", JSON.stringify(done.body));
    const { body: rows } = await svc(`media_items?id=eq.${id}&select=processing_status,width,height,storage_path_thumbnail`);
    assertEquals([rows[0].processing_status, rows[0].width, rows[0].height], ["ready", 2048, 1536]);
    assertEquals(typeof rows[0].storage_path_thumbnail, "string");
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
