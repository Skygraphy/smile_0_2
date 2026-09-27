// Regressions found during the 2026-09-27 manual walkthrough (after the
// switch to FCM-only sync) -- each test pins one fix so it can't silently
// come back.
import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  requireEnv,
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

async function createPairedFrame(ownerToken: string, spaceId: string): Promise<{ frameId: string; frameAccessToken: string }> {
  const createResp = await invoke("create-frame", ownerToken, { space_id: spaceId, name: "Test Frame" });
  assertEquals(createResp.status, 200, JSON.stringify(createResp.body));
  const claimResp = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code: createResp.body.pairing_code });
  assertEquals(claimResp.status, 200, JSON.stringify(claimResp.body));
  return { frameId: createResp.body.frame_id as string, frameAccessToken: claimResp.body.access_token as string };
}

async function addCoOwner(spaceId: string, userId: string) {
  const { status, body } = await svc("space_co_owners", {
    method: "POST",
    body: JSON.stringify({ space_id: spaceId, user_id: userId }),
  });
  assertEquals(status, 201, JSON.stringify(body));
}

// migrations/0044_revoke_share_unassigns_frames.sql
Deno.test("revoking a share takes the channel off the viewing Space's Frames", async () => {
  requireEnv();
  const channelOwner = await createThrowawayUser("sharesrc");
  const viewer = await createThrowawayUser("sharedst");
  let srcSpaceId: string | undefined;
  let dstSpaceId: string | undefined;
  try {
    await ensureProfile(channelOwner.id, "Test Source");
    await ensureProfile(viewer.id, "Test Viewer");
    const { accessToken: ownerToken } = await accessTokenFor(channelOwner.email);
    const { accessToken: viewerToken } = await accessTokenFor(viewer.email);
    srcSpaceId = await createSpace(ownerToken, "Source Space");
    dstSpaceId = await createSpace(viewerToken, "Viewer Space");
    const channelId = await createChannel(ownerToken, srcSpaceId, "Shared Channel");

    const inviteResp = await invoke("invite-channel-share", ownerToken, { channel_id: channelId, email: viewer.email });
    assertEquals(inviteResp.status, 200, JSON.stringify(inviteResp.body));
    const { status: acceptStatus } = await asUser(`channel_share_requests?id=eq.${inviteResp.body.request_id}`, viewerToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ status: "accepted", space_id: dstSpaceId }),
    });
    assertEquals(acceptStatus, 204);

    const { frameId } = await createPairedFrame(viewerToken, dstSpaceId);
    const assignResp = await invoke("assign-frame-channel", viewerToken, { frame_id: frameId, channel_id: channelId });
    assertEquals(assignResp.status, 200, JSON.stringify(assignResp.body));

    const { status: revokeStatus } = await asUser(
      `channel_shares?channel_id=eq.${channelId}&space_id=eq.${dstSpaceId}`,
      viewerToken,
      { method: "DELETE" },
    );
    assertEquals(revokeStatus, 204);

    const { body: assignments } = await svc(`frame_channels?frame_id=eq.${frameId}`);
    assertEquals(assignments.length, 0, "a Frame must not keep showing a channel its Space can no longer see");
  } finally {
    if (dstSpaceId) await deleteSpace(dstSpaceId);
    if (srcSpaceId) await deleteSpace(srcSpaceId);
    await deleteUser(channelOwner.id);
    await deleteUser(viewer.id);
  }
});

// migrations/0045_protect_administrator_channel_membership.sql
Deno.test("a co-owner can remove members, but never the Administrator", async () => {
  requireEnv();
  const admin = await createThrowawayUser("admin");
  const coOwner = await createThrowawayUser("coowner");
  const member = await createThrowawayUser("member");
  let spaceId: string | undefined;
  try {
    await ensureProfile(admin.id, "Test Admin");
    await ensureProfile(coOwner.id, "Test CoOwner");
    await ensureProfile(member.id, "Test Member");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: coOwnerToken } = await accessTokenFor(coOwner.email);
    spaceId = await createSpace(adminToken, "Test Space");
    const channelId = await createChannel(adminToken, spaceId, "Test Channel");
    await addCoOwner(spaceId, coOwner.id);
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: channelId, user_id: member.id }) });

    const { status: adminRemoval } = await asUser(
      `channel_members?channel_id=eq.${channelId}&user_id=eq.${admin.id}`,
      coOwnerToken,
      { method: "DELETE" },
    );
    assert(adminRemoval >= 400, `removing the Administrator must be refused, got ${adminRemoval}`);
    const { body: stillThere } = await svc(`channel_members?channel_id=eq.${channelId}&user_id=eq.${admin.id}`);
    assertEquals(stillThere.length, 1);

    const { status: memberRemoval } = await asUser(
      `channel_members?channel_id=eq.${channelId}&user_id=eq.${member.id}`,
      coOwnerToken,
      { method: "DELETE" },
    );
    assertEquals(memberRemoval, 204);
    const { body: gone } = await svc(`channel_members?channel_id=eq.${channelId}&user_id=eq.${member.id}`);
    assertEquals(gone.length, 0, "a co-owner may still remove ordinary members");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(admin.id);
    await deleteUser(coOwner.id);
    await deleteUser(member.id);
  }
});

// delete-media treated only spaces.owner_id as SCO, not co-owners.
Deno.test("a co-owner may delete someone else's photo", async () => {
  requireEnv();
  const admin = await createThrowawayUser("admin");
  const coOwner = await createThrowawayUser("coowner");
  let spaceId: string | undefined;
  try {
    await ensureProfile(admin.id, "Test Admin");
    await ensureProfile(coOwner.id, "Test CoOwner");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: coOwnerToken } = await accessTokenFor(coOwner.email);
    spaceId = await createSpace(adminToken, "Test Space");
    const channelId = await createChannel(adminToken, spaceId, "Test Channel");
    await addCoOwner(spaceId, coOwner.id);

    const { body: media } = await svc("media_items", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        channel_id: channelId,
        sender_id: admin.id,
        media_type: "photo",
        storage_path_original: "test/original.jpg",
        processing_status: "ready",
      }),
    });
    const mediaId = media[0].id as string;

    const resp = await invoke("delete-media", coOwnerToken, { action: "delete", media_item_ids: [mediaId] });
    assertEquals(resp.status, 200, JSON.stringify(resp.body));
    assertEquals(resp.body.applied, [mediaId], JSON.stringify(resp.body));
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(admin.id);
    await deleteUser(coOwner.id);
  }
});

// delete-space-or-channel + get-media-batch's frame_not_found
Deno.test("channel/Space deletion: who may, and a deleted Space's Frame learns it's gone", async () => {
  requireEnv();
  const admin = await createThrowawayUser("admin");
  const coOwner = await createThrowawayUser("coowner");
  const stranger = await createThrowawayUser("stranger");
  let spaceId: string | undefined;
  try {
    await ensureProfile(admin.id, "Test Admin");
    await ensureProfile(coOwner.id, "Test CoOwner");
    await ensureProfile(stranger.id, "Test Stranger");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: coOwnerToken } = await accessTokenFor(coOwner.email);
    const { accessToken: strangerToken } = await accessTokenFor(stranger.email);
    spaceId = await createSpace(adminToken, "Test Space");
    const channelA = await createChannel(adminToken, spaceId, "Channel A");
    await createChannel(adminToken, spaceId, "Channel B");
    await addCoOwner(spaceId, coOwner.id);
    const { frameAccessToken } = await createPairedFrame(adminToken, spaceId);

    const strangerResp = await invoke("delete-space-or-channel", strangerToken, { kind: "channel", id: channelA });
    assertEquals(strangerResp.status, 403, JSON.stringify(strangerResp.body));

    const coOwnerChannel = await invoke("delete-space-or-channel", coOwnerToken, { kind: "channel", id: channelA });
    assertEquals(coOwnerChannel.status, 200, JSON.stringify(coOwnerChannel.body));
    const { body: channelGone } = await svc(`channels?id=eq.${channelA}`);
    assertEquals(channelGone.length, 0);

    const coOwnerSpace = await invoke("delete-space-or-channel", coOwnerToken, { kind: "space", id: spaceId });
    assertEquals(coOwnerSpace.status, 403, "a co-owner manages the Space but must never end it");

    const adminSpace = await invoke("delete-space-or-channel", adminToken, { kind: "space", id: spaceId });
    assertEquals(adminSpace.status, 200, JSON.stringify(adminSpace.body));
    const { body: spaceGone } = await svc(`spaces?id=eq.${spaceId}`);
    assertEquals(spaceGone.length, 0);
    spaceId = undefined;

    const batchResp = await invoke("get-media-batch", "irrelevant-anon-call", { access_token: frameAccessToken });
    assertEquals(batchResp.status, 403);
    assertEquals(batchResp.body.error, "frame_not_found", "the Frame must be told to go back to pairing");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(admin.id);
    await deleteUser(coOwner.id);
    await deleteUser(stranger.id);
  }
});
