// Several photos in one go -> one notification per album and sender that
// keeps counting up (decided 2026-10-08), not one per photo.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { announceReadyPhoto, batchBody } from "../_shared/media-fanout.ts";
import {
  requireEnv,
  svc,
  createThrowawayUser,
  deleteUser,
  deleteSpace,
  accessTokenFor,
  ensureProfile,
  createSpace,
  createChannel,
} from "./helpers.ts";

Deno.test("batch push text", () => {
  assertEquals(batchBody("Ernst", 1, 0), "Ernst hat ein Foto geteilt.");
  assertEquals(batchBody("Ernst", 0, 1), "Ernst hat ein Video geteilt.");
  assertEquals(batchBody("Ernst", 5, 0), "Ernst hat 5 neue Fotos geteilt.");
  assertEquals(batchBody("Ernst", 0, 2), "Ernst hat 2 neue Videos geteilt.");
  assertEquals(batchBody("Ernst", 2, 1), "Ernst hat 3 neue Fotos und Videos geteilt.");
});

Deno.test("three photos in a row leave one Verlauf entry that counts them", async () => {
  const { url, serviceKey } = requireEnv();
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const sender = await createThrowawayUser("pbsend");
  const member = await createThrowawayUser("pbmem");
  let space: string | undefined;
  try {
    await ensureProfile(sender.id, "PB Sender");
    await ensureProfile(member.id, "PB Member");
    const { accessToken } = await accessTokenFor(sender.email);
    space = await createSpace(accessToken, "PB Space");
    const album = await createChannel(accessToken, space, "PB Album");
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: album, user_id: member.id }) });

    for (let i = 0; i < 3; i++) {
      const path = `test/${crypto.randomUUID()}.jpg`;
      const { body } = await svc("media_items", {
        method: "POST",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({
          channel_id: album, sender_id: sender.id, media_type: "photo",
          storage_path_original: path, storage_path_thumbnail: path, processing_status: "ready",
        }),
      });
      await announceReadyPhoto(admin, body[0].id as string, album);
    }

    const { body: rows } = await svc(`user_notifications?user_id=eq.${member.id}&select=title,body,data`);
    const photoRows = (rows as { title: string; body: string; data: Record<string, string> }[])
      .filter((r) => r.data.type === "new_photo");
    assertEquals(photoRows.length, 1);
    assertEquals(photoRows[0].title, "PB Album");
    assertEquals(photoRows[0].body, "PB Sender hat 3 neue Fotos geteilt.");
    assertEquals(photoRows[0].data.collapse_key, `photos_${album}_${sender.id}`);
    // The sender gets nothing about their own photos.
    const { body: own } = await svc(`user_notifications?user_id=eq.${sender.id}&data->>type=eq.new_photo&select=id`);
    assertEquals(own, []);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(member.id);
    await deleteUser(sender.id);
  }
});
