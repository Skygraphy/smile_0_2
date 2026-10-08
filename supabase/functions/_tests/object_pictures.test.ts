// Own pictures for Space / Album / Frame (migrations/0066, 2026-10-08).
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireEnv,
  svc,
  invoke,
  asUser,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
  createChannel,
} from "./helpers.ts";

const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);


async function events(kind: string): Promise<Record<string, unknown>[]> {
  const { body } = await svc(`internal_calls?fn=eq.notify-event&body->>kind=eq.${kind}&select=body&order=id.desc&limit=30`);
  return (body as { body: { payload: Record<string, unknown> } }[]).map((r) => r.body.payload);
}

Deno.test("managers set pictures; others can't; changes notify and old files go", async () => {
  const { url, anonKey } = requireEnv();
  const admin = await createThrowawayUser("opadmin");
  const stranger = await createThrowawayUser("opstr");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "OP Admin");
    await ensureProfile(stranger.id, "OP Stranger");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: strangerToken } = await accessTokenFor(stranger.email);
    space = await createSpace(adminToken, "OP Space");
    const album = await createChannel(adminToken, space, "OP Album");

    // Storage: the Space's manager may write its picture, a stranger may not.
    const putAs = async (token: string, path: string) =>
      (await fetch(`${url}/storage/v1/object/avatars/${path}`, {
        method: "POST",
        headers: { apikey: anonKey, Authorization: `Bearer ${token}`, "Content-Type": "image/jpeg" },
        body: JPEG,
      })).status;
    assertEquals(await putAs(adminToken, `spaces/${space}/a.jpg`), 200);
    assertEquals((await putAs(strangerToken, `spaces/${space}/b.jpg`)) >= 400, true);

    // Setting it notifies; replacing it queues the old file for removal.
    const patch = (path: string, data: unknown) =>
      asUser(path, adminToken, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify(data) });
    assertEquals((await patch(`spaces?id=eq.${space}`, { avatar_path: `spaces/${space}/a.jpg` })).status, 204);
    assertEquals((await events("picture_changed")).some((p) => p.kind === "space" && p.id === space), true);
    assertEquals((await putAs(adminToken, `spaces/${space}/c.jpg`)), 200);
    assertEquals((await patch(`spaces?id=eq.${space}`, { avatar_path: `spaces/${space}/c.jpg` })).status, 204);
    const { body: removals } = await svc(`internal_calls?fn=eq.remove-storage-files&select=body&order=id.desc&limit=10`);
    assertEquals(
      (removals as { body: { files: { path: string }[] } }[]).some((r) => r.body.files.some((f) => f.path === `spaces/${space}/a.jpg`)),
      true,
    );

    // Album: a chosen photo becomes the cover even when a newer one exists.
    const thumb = async (name: string) => {
      const path = `test/${crypto.randomUUID()}_${name}.jpg`;
      await fetch(`${url}/storage/v1/object/media-thumbnails/${path}`, {
        method: "POST",
        headers: { apikey: anonKey, Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`, "Content-Type": "image/jpeg" },
        body: JPEG,
      });
      const { body } = await svc("media_items", {
        method: "POST",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({
          channel_id: album, sender_id: admin.id, media_type: "photo",
          storage_path_original: path, storage_path_thumbnail: path, processing_status: "ready",
        }),
      });
      return body[0].id as string;
    };
    const older = await thumb("older");
    await thumb("newer");
    assertEquals((await patch(`channels?id=eq.${album}`, { cover_media_id: older, cover_path: null })).status, 204);
    const list = await invoke("list-my-channels", adminToken, {});
    const cover = (list.body.channels as { channel_id: string; cover: { media_id: string; custom: boolean } }[])
      .find((c) => c.channel_id === album)!.cover;
    assertEquals([cover.media_id, cover.custom], [older, true]);
    assertEquals((await events("picture_changed")).some((p) => p.kind === "album" && p.id === album), true);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(stranger.id);
    await deleteUser(admin.id);
  }
});
