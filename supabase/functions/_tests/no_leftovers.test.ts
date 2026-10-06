// "Niemals Leichen" (migrations/0062, decision 2026-10-06): deleting a Frame
// or an account leaves nothing behind, files follow their rows, and
// unanswered invites expire.
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

async function queuedFileRemovals(): Promise<{ bucket: string; path: string }[]> {
  const { body } = await svc(`internal_calls?fn=eq.remove-storage-files&select=body&order=id.desc&limit=50`);
  return (body as { body: { files: { bucket: string; path: string }[] } }[]).flatMap((r) => r.body.files);
}

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
  return path;
}

Deno.test("a Frame can be deleted by its Space's managers -- and only by them", async () => {
  requireEnv();
  const admin = await createThrowawayUser("dfadmin");
  const stranger = await createThrowawayUser("dfstr");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "DF Admin");
    await ensureProfile(stranger.id, "DF Stranger");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: strangerToken } = await accessTokenFor(stranger.email);
    space = await createSpace(adminToken, "DF Space");
    const frame = await invoke("create-frame", adminToken, { space_id: space, name: "DF Frame" });
    const frameId = frame.body.frame_id as string;

    const denied = await invoke("delete-frame", strangerToken, { frame_id: frameId });
    assertEquals(denied.status, 403, JSON.stringify(denied.body));

    const done = await invoke("delete-frame", adminToken, { frame_id: frameId });
    assertEquals(done.status, 200, JSON.stringify(done.body));
    assertEquals((await svc(`frames?id=eq.${frameId}&select=id`)).body, []);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(stranger.id);
    await deleteUser(admin.id);
  }
});

Deno.test("deleting a photo row, however it happens, queues its files for removal", async () => {
  requireEnv();
  const admin = await createThrowawayUser("fradmin");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "FR Admin");
    const { accessToken } = await accessTokenFor(admin.email);
    space = await createSpace(accessToken, "FR Space");
    const album = await createChannel(accessToken, space, "FR Album");
    const path = await postPhoto(album, admin.id);
    // A cascade, not delete-media: the album row goes.
    await svc(`channels?id=eq.${album}`, { method: "DELETE" });
    const queued = await queuedFileRemovals();
    assertEquals(queued.some((f) => f.bucket === "media-originals" && f.path === path), true);
    assertEquals(queued.some((f) => f.bucket === "media-display" && f.path === path), true);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(admin.id);
  }
});

Deno.test("deleting an account removes everything of it and hands Spaces over", async () => {
  requireEnv();
  const leaver = await createThrowawayUser("dalv");
  const co = await createThrowawayUser("daco");
  const other = await createThrowawayUser("daoth");
  const spaces: string[] = [];
  try {
    await ensureProfile(leaver.id, "DA Leaver");
    await ensureProfile(co.id, "DA Co");
    await ensureProfile(other.id, "DA Other");
    const { accessToken: leaverToken } = await accessTokenFor(leaver.email);
    const { accessToken: otherToken } = await accessTokenFor(other.email);

    const alone = await createSpace(leaverToken, "DA Alone"); // no Co-Admin -> goes
    const shared = await createSpace(leaverToken, "DA Shared"); // Co-Admin -> handed over
    const othersSpace = await createSpace(otherToken, "DA Others");
    spaces.push(alone, shared, othersSpace);
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: shared, user_id: co.id }) });
    await createChannel(leaverToken, alone, "DA Alone Album");
    const othersAlbum = await createChannel(otherToken, othersSpace, "DA Others Album");
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: othersAlbum, user_id: leaver.id }) });
    const photoPath = await postPhoto(othersAlbum, leaver.id);

    const res = await invoke("delete-account", leaverToken, {});
    assertEquals(res.status, 200, JSON.stringify(res.body));
    assertEquals([res.body.handed_over, res.body.spaces_deleted], [1, 1]);

    assertEquals((await svc(`spaces?id=eq.${alone}&select=id`)).body, []);
    assertEquals((await svc(`spaces?id=eq.${shared}&select=owner_id`)).body, [{ owner_id: co.id }]);
    assertEquals((await svc(`media_items?sender_id=eq.${leaver.id}&select=id`)).body, []);
    assertEquals((await svc(`profiles?user_id=eq.${leaver.id}&select=user_id`)).body, []);
    assertEquals((await queuedFileRemovals()).some((f) => f.path === photoPath), true);
  } finally {
    for (const s of spaces) await deleteSpace(s).catch(() => {});
    await deleteUser(other.id);
    await deleteUser(co.id);
    await deleteUser(leaver.id).catch(() => {});
  }
});

Deno.test("invites nobody answers within 30 days expire", async () => {
  requireEnv();
  const admin = await createThrowawayUser("exadmin");
  const invitee = await createThrowawayUser("exinv");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "EX Admin");
    await ensureProfile(invitee.id, "EX Invitee");
    const { accessToken } = await accessTokenFor(admin.email);
    space = await createSpace(accessToken, "EX Space");
    const album = await createChannel(accessToken, space, "EX Album");
    const old = new Date(Date.now() - 31 * 24 * 3600 * 1000).toISOString();
    const { body } = await svc("channel_membership_requests", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ channel_id: album, user_id: invitee.id, direction: "invite", requested_at: old }),
    });
    const requestId = body[0].id as string;

    // Same path as the daily cron job.
    const run = await svc("rpc/invoke_internal", { method: "POST", body: JSON.stringify({ fn: "expire-requests", body: {} }) });
    assertEquals(run.status, 204, JSON.stringify(run.body));
    let gone = false;
    for (let i = 0; i < 20 && !gone; i++) {
      await new Promise((r) => setTimeout(r, 1000));
      gone = ((await svc(`channel_membership_requests?id=eq.${requestId}&select=id`)).body as unknown[]).length === 0;
    }
    assertEquals(gone, true, "the 31-day-old invite must be gone");
    const history = await svc(`user_notifications?user_id=eq.${admin.id}&select=title`);
    assertEquals((history.body as { title: string }[]).some((n) => n.title === "Einladung abgelaufen"), true);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(invitee.id);
    await deleteUser(admin.id);
  }
});
