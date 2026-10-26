// migrations/0088 (decision 2026-10-26): whoever stops being a Co-Admin
// leaves the albums they were in only because of that role -- not the ones
// they were invited to or have sent something to. A hand-over keeps all.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireEnv,
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

async function isMember(channelId: string, userId: string): Promise<boolean> {
  const { body } = await svc(`channel_members?channel_id=eq.${channelId}&user_id=eq.${userId}&select=user_id`);
  return (body as unknown[]).length === 1;
}

Deno.test("stepping down as Co-Admin leaves only the albums that came with the role", async () => {
  requireEnv();
  const admin = await createThrowawayUser("admin");
  const coAdmin = await createThrowawayUser("coadmin");
  let spaceId: string | undefined;
  try {
    await ensureProfile(admin.id, "Test Admin");
    await ensureProfile(coAdmin.id, "Test CoAdmin");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    spaceId = await createSpace(adminToken, "Helping Space");
    const onlyRole = await createChannel(adminToken, spaceId, "Only the role");
    const sentTo = await createChannel(adminToken, spaceId, "Sent something");
    const invited = await createChannel(adminToken, spaceId, "Invited");

    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: spaceId, user_id: coAdmin.id }) });
    for (const c of [onlyRole, sentTo, invited]) assertEquals(await isMember(c, coAdmin.id), true, "the role brings every album");
    const { body: rows } = await svc(`channel_members?user_id=eq.${coAdmin.id}&select=via_co_admin`);
    assertEquals((rows as { via_co_admin: boolean }[]).every((r) => r.via_co_admin), true, "remembered as through the role");

    // One album they sent a photo to, one they said yes to an invite of.
    const { status: media } = await svc("media_items", {
      method: "POST",
      body: JSON.stringify({ channel_id: sentTo, sender_id: coAdmin.id, media_type: "photo", storage_path_original: "test/x.jpg" }),
    });
    assertEquals(media, 201);
    const { body: request } = await svc("channel_membership_requests", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ channel_id: invited, user_id: coAdmin.id, direction: "invite" }),
    });
    await svc(`channel_membership_requests?id=eq.${(request as { id: string }[])[0].id}`, {
      method: "PATCH",
      body: JSON.stringify({ status: "accepted" }),
    });
    const { body: inv } = await svc(`channel_members?channel_id=eq.${invited}&user_id=eq.${coAdmin.id}&select=via_co_admin`);
    assertEquals((inv as { via_co_admin: boolean }[])[0].via_co_admin, false, "an accepted invite makes it deliberate");

    await svc(`space_co_owners?space_id=eq.${spaceId}&user_id=eq.${coAdmin.id}`, { method: "DELETE" });
    assertEquals(await isMember(onlyRole, coAdmin.id), false, "the album that came only with the role is left");
    assertEquals(await isMember(sentTo, coAdmin.id), true, "an album they sent to stays");
    assertEquals(await isMember(invited, coAdmin.id), true, "an album they were invited to stays");
    assertEquals(await isMember(onlyRole, admin.id), true, "the Administrator stays everywhere");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(admin.id);
    await deleteUser(coAdmin.id);
  }
});

Deno.test("a hand-over to a Co-Admin keeps all their albums", async () => {
  requireEnv();
  const admin = await createThrowawayUser("admin");
  const coAdmin = await createThrowawayUser("coadmin");
  let spaceId: string | undefined;
  try {
    await ensureProfile(admin.id, "Test Admin");
    await ensureProfile(coAdmin.id, "Test CoAdmin");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    spaceId = await createSpace(adminToken, "Handed Space");
    const album = await createChannel(adminToken, spaceId, "Album");
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: spaceId, user_id: coAdmin.id }) });

    const { body } = await invoke("transfer-space-ownership", adminToken, { space_id: spaceId, new_owner_user_id: coAdmin.id });
    assertEquals(body.status, "transferred");
    assertEquals(await isMember(album, coAdmin.id), true, "the new Administrator keeps the album");
    assertEquals(await isMember(album, admin.id), true, "the old one too, now a Co-Admin");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(admin.id);
    await deleteUser(coAdmin.id);
  }
});
