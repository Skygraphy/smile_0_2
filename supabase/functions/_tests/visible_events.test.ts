// "Alles komplett interaktiv", second round (migrations/0064, 2026-10-07):
// every change that used to sync silently now reaches the people affected.
// App writes raise a server event (checked in the outbox); Edge Function
// writes push directly (checked in the recipient's Verlauf).
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

async function events(kind: string): Promise<Record<string, unknown>[]> {
  const { body } = await svc(`internal_calls?fn=eq.notify-event&body->>kind=eq.${kind}&select=body&order=id.desc&limit=30`);
  return (body as { body: { payload: Record<string, unknown> } }[]).map((r) => r.body.payload);
}

async function verlauf(userId: string): Promise<string[]> {
  const { body } = await svc(`user_notifications?user_id=eq.${userId}&select=title&order=created_at.desc`);
  return (body as { title: string }[]).map((r) => r.title);
}

const patch = (path: string, token: string, data: unknown) =>
  asUser(path, token, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify(data) });

Deno.test("formerly silent changes now reach everyone affected", async () => {
  requireEnv();
  const admin = await createThrowawayUser("veadmin");
  const co = await createThrowawayUser("veco");
  const member = await createThrowawayUser("vemem");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "VE Admin");
    await ensureProfile(co.id, "VE Co");
    await ensureProfile(member.id, "VE Member");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    space = await createSpace(adminToken, "VE Space");
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: space, user_id: co.id }) });

    // App writes -> server events, with the actor.
    const album = await createChannel(adminToken, space, "VE Album");
    assertEquals((await events("album_created")).some((p) => p.channel_id === album && p.actor_id === admin.id), true);

    assertEquals((await patch(`channels?id=eq.${album}`, adminToken, { name: "VE Album 2" })).status, 204);
    assertEquals((await events("album_renamed")).some((p) => p.channel_id === album && p.new_name === "VE Album 2"), true);

    assertEquals((await patch(`spaces?id=eq.${space}`, adminToken, { name: "VE Space 2" })).status, 204);
    assertEquals((await events("space_renamed")).some((p) => p.space_id === space && p.old_name === "VE Space"), true);

    // Edge Function writes -> direct push to the other managers.
    const frame = await invoke("create-frame", adminToken, { space_id: space, name: "VE Frame" });
    const frameId = frame.body.frame_id as string;
    assertEquals((await verlauf(co.id)).includes("Neuer Frame"), true);
    assertEquals((await verlauf(admin.id)).includes("Neuer Frame"), false, "the actor is not told about their own change");

    assertEquals((await patch(`frames?id=eq.${frameId}`, adminToken, { name: "VE Frame 2", video_sound: false })).status, 204);
    const changed = (await events("frame_changed")).find((p) => p.frame_id === frameId);
    assertEquals([changed?.new_name, changed?.video_sound], ["VE Frame 2", false]);

    const assigned = await invoke("assign-frame-channel", adminToken, { frame_id: frameId, channel_id: album });
    assertEquals(assigned.status, 200, JSON.stringify(assigned.body));
    assertEquals((await verlauf(co.id)).includes("Frame zeigt neues Album"), true);
    const unassigned = await asUser(`frame_channels?frame_id=eq.${frameId}&channel_id=eq.${album}`, adminToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals((unassigned.body as unknown[]).length, 1, JSON.stringify(unassigned.body));
    assertEquals((await events("frame_album_removed")).some((p) => p.frame_id === frameId), true);

    // An admin deleting someone else's photo -> its sender hears it.
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: album, user_id: member.id }) });
    const { body: media } = await svc("media_items", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        channel_id: album,
        sender_id: member.id,
        media_type: "photo",
        storage_path_original: `test/${crypto.randomUUID()}.jpg`,
        processing_status: "ready",
      }),
    });
    const del = await invoke("delete-media", adminToken, { media_item_ids: [media[0].id], action: "delete" });
    assertEquals(del.status, 200, JSON.stringify(del.body));
    assertEquals((await verlauf(member.id)).includes("Foto gelöscht"), true);

    const removed = await invoke("delete-frame", adminToken, { frame_id: frameId });
    assertEquals(removed.status, 200);
    assertEquals((await verlauf(co.id)).includes("Frame gelöscht"), true);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(member.id);
    await deleteUser(co.id);
    await deleteUser(admin.id);
  }
});
