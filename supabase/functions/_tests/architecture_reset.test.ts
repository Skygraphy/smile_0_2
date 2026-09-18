// Phase 2 regression suite for the architecture reset (User/Space/Channel/
// Frame, see migrations/0031_architecture_reset.sql and the plan under
// C:\Users\ernst\.claude\plans\swift-riding-snail.md). Replaces every test
// file this reset made obsolete (channel_join_requests/groups/
// multi_space_channels/self_service_leave.test.ts, all deleted -- their
// underlying tables/functions no longer exist).
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
} from "./helpers.ts";

async function ensureProfile(userId: string, displayName: string) {
  await svc("profiles", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates" },
    body: JSON.stringify({ user_id: userId, display_name: displayName }),
  });
}

async function createSpace(accessToken: string, name: string): Promise<string> {
  const { status, body } = await asUser("spaces", accessToken, {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ name }),
  });
  assertEquals(status, 201, JSON.stringify(body));
  return body[0].id as string;
}

async function createChannel(accessToken: string, spaceId: string, name: string): Promise<string> {
  const { status, body } = await asUser("channels", accessToken, {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ space_id: spaceId, name }),
  });
  assertEquals(status, 201, JSON.stringify(body));
  return body[0].id as string;
}

Deno.test("channel create auto-joins the SCO and blocks a stranger", async () => {
  requireEnv();
  const owner = await createThrowawayUser("sco");
  const stranger = await createThrowawayUser("stranger");
  let spaceId: string | undefined;
  try {
    await ensureProfile(owner.id, "Test Owner");
    await ensureProfile(stranger.id, "Test Stranger");
    const { accessToken: ownerToken } = await accessTokenFor(owner.email);
    const { accessToken: strangerToken } = await accessTokenFor(stranger.email);

    spaceId = await createSpace(ownerToken, "Test Space");
    const channelId = await createChannel(ownerToken, spaceId, "Test Channel");

    const { status: memberStatus, body: memberBody } = await asUser(
      `channel_members?channel_id=eq.${channelId}&user_id=eq.${owner.id}`,
      ownerToken,
    );
    assertEquals(memberStatus, 200);
    assertEquals(memberBody.length, 1, "SCO should be auto-joined by on_channel_created");

    const { status: strangerSelect, body: strangerBody } = await asUser(`channels?id=eq.${channelId}`, strangerToken);
    assertEquals(strangerSelect, 200);
    assertEquals(strangerBody.length, 0, "a stranger must not see a channel they have no relation to");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(owner.id);
    await deleteUser(stranger.id);
  }
});

Deno.test("channel membership invite -> accept grants posting rights", async () => {
  requireEnv();
  const owner = await createThrowawayUser("sco");
  const invitee = await createThrowawayUser("invitee");
  let spaceId: string | undefined;
  try {
    await ensureProfile(owner.id, "Test Owner");
    await ensureProfile(invitee.id, "Test Invitee");
    const { accessToken: ownerToken } = await accessTokenFor(owner.email);
    const { accessToken: inviteeToken } = await accessTokenFor(invitee.email);

    spaceId = await createSpace(ownerToken, "Test Space");
    const channelId = await createChannel(ownerToken, spaceId, "Test Channel");

    const inviteResp = await invoke("invite-channel-member", ownerToken, {
      channel_id: channelId,
      email: invitee.email,
    });
    assertEquals(inviteResp.status, 200, JSON.stringify(inviteResp.body));
    assertEquals(inviteResp.body.status, "invited");
    const requestId = inviteResp.body.request_id as string;

    // Invitee can already see the channel's name via the invite (list-my-invites),
    // but not via plain RLS yet -- not a member, not a share, not the SCO.
    const inboxResp = await invoke("list-my-invites", inviteeToken, {});
    assertEquals(inboxResp.status, 200);
    const found = inboxResp.body.membership_requests.find((r: { id: string }) => r.id === requestId);
    assert(found, "invitee should see the pending invite in their inbox");
    assertEquals(found.channel_name, "Test Channel");

    const { status: preAcceptSelect, body: preAcceptBody } = await asUser(`channels?id=eq.${channelId}`, inviteeToken);
    assertEquals(preAcceptSelect, 200);
    assertEquals(preAcceptBody.length, 0, "an un-accepted invitee must not see the channel via RLS yet");

    // Accept: a plain RLS-governed PATCH (channel_membership_requests_decide).
    const { status: acceptStatus } = await asUser(`channel_membership_requests?id=eq.${requestId}`, inviteeToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ status: "accepted" }),
    });
    assertEquals(acceptStatus, 204);

    const { status: memberStatus, body: memberBody } = await asUser(
      `channel_members?channel_id=eq.${channelId}&user_id=eq.${invitee.id}`,
      inviteeToken,
    );
    assertEquals(memberStatus, 200);
    assertEquals(memberBody.length, 1, "accepting the invite should materialize a channel_members row");

    const { status: postAcceptSelect, body: postAcceptBody } = await asUser(`channels?id=eq.${channelId}`, inviteeToken);
    assertEquals(postAcceptSelect, 200);
    assertEquals(postAcceptBody.length, 1, "a member can now see the channel");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(owner.id);
    await deleteUser(invitee.id);
  }
});

Deno.test("channel share invite -> accept grants view only, never write, and is unilaterally revocable", async () => {
  requireEnv();
  const owner = await createThrowawayUser("sco");
  const otherOwner = await createThrowawayUser("otherowner");
  let spaceId: string | undefined;
  let otherSpaceId: string | undefined;
  try {
    await ensureProfile(owner.id, "Test Owner");
    await ensureProfile(otherOwner.id, "Test Other Owner");
    const { accessToken: ownerToken } = await accessTokenFor(owner.email);
    const { accessToken: otherToken } = await accessTokenFor(otherOwner.email);

    spaceId = await createSpace(ownerToken, "Test Space");
    const channelId = await createChannel(ownerToken, spaceId, "Test Channel");
    otherSpaceId = await createSpace(otherToken, "Other Space");

    const inviteResp = await invoke("invite-channel-share", ownerToken, {
      channel_id: channelId,
      email: otherOwner.email,
    });
    assertEquals(inviteResp.status, 200, JSON.stringify(inviteResp.body));
    const requestId = inviteResp.body.request_id as string;

    // Accept, supplying which of their own Spaces to link, in the same call.
    const { status: acceptStatus } = await asUser(`channel_share_requests?id=eq.${requestId}`, otherToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ status: "accepted", space_id: otherSpaceId }),
    });
    assertEquals(acceptStatus, 204);

    const { status: shareSelect, body: shareBody } = await asUser(
      `channel_shares?channel_id=eq.${channelId}&space_id=eq.${otherSpaceId}`,
      otherToken,
    );
    assertEquals(shareSelect, 200);
    assertEquals(shareBody.length, 1, "accepting a share invite should materialize a channel_shares row");

    const { status: viewStatus, body: viewBody } = await asUser(`channels?id=eq.${channelId}`, otherToken);
    assertEquals(viewStatus, 200);
    assertEquals(viewBody.length, 1, "the linked Space's owner can view the channel");

    const { status: writeStatus } = await asUser("channel_members", otherToken, {
      method: "POST",
      body: JSON.stringify({ channel_id: channelId, user_id: otherOwner.id }),
    });
    assert(writeStatus === 403 || writeStatus === 401, `a shared-only viewer must never get write power, got ${writeStatus}`);

    const { status: revokeStatus } = await asUser(
      `channel_shares?channel_id=eq.${channelId}&space_id=eq.${otherSpaceId}`,
      otherToken,
      { method: "DELETE" },
    );
    assertEquals(revokeStatus, 204, "the linked Space's owner can always unilaterally revoke");

    const { body: afterRevokeBody } = await asUser(`channels?id=eq.${channelId}`, otherToken);
    assertEquals(afterRevokeBody.length, 0, "view access should be gone immediately after revoking");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    if (otherSpaceId) await deleteSpace(otherSpaceId);
    await deleteUser(owner.id);
    await deleteUser(otherOwner.id);
  }
});

Deno.test("frame create -> claim pairing -> assign channel backfills existing photos", async () => {
  requireEnv();
  const owner = await createThrowawayUser("frameowner");
  let spaceId: string | undefined;
  try {
    await ensureProfile(owner.id, "Test Frame Owner");
    const { accessToken: ownerToken } = await accessTokenFor(owner.email);
    spaceId = await createSpace(ownerToken, "Test Space");
    const channelId = await createChannel(ownerToken, spaceId, "Test Channel");

    const createResp = await invoke("create-frame", ownerToken, { space_id: spaceId, name: "Test Frame" });
    assertEquals(createResp.status, 200, JSON.stringify(createResp.body));
    const frameId = createResp.body.frame_id as string;
    const code = createResp.body.pairing_code as string;
    assert(code.length > 0);

    const claimResp = await invoke("claim-frame-pairing", "irrelevant-anon-call", { code });
    assertEquals(claimResp.status, 200, JSON.stringify(claimResp.body));
    assertEquals(claimResp.body.frame_id, frameId);
    assertEquals(claimResp.body.status, "paired");
    const frameAccessToken = claimResp.body.access_token as string;
    assert(claimResp.body.refresh_secret.length > 0);

    // Seed a pre-existing "ready" photo directly (bypassing the upload
    // pipeline, which needs real storage bytes -- out of scope here; this
    // test is about the assignment/backfill/poll path, not the pipeline).
    const { status: mediaStatus, body: mediaBody } = await svc("media_items", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        channel_id: channelId,
        sender_id: owner.id,
        media_type: "photo",
        storage_path_original: "test/original.jpg",
        storage_path_display: "test/display.jpg",
        mime_type: "image/jpeg",
        processing_status: "ready",
      }),
    });
    assertEquals(mediaStatus, 201, JSON.stringify(mediaBody));

    const assignResp = await invoke("assign-frame-channel", ownerToken, { frame_id: frameId, channel_id: channelId });
    assertEquals(assignResp.status, 200, JSON.stringify(assignResp.body));
    assertEquals(assignResp.body.backfilled_items, 1);

    const batchResp = await invoke("get-media-batch", "irrelevant-anon-call", { access_token: frameAccessToken });
    assertEquals(batchResp.status, 200, JSON.stringify(batchResp.body));
    assertEquals(batchResp.body.channel_id, channelId);
    assertEquals(batchResp.body.items.length, 1, "the backfilled photo should show up on the frame's first poll");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(owner.id);
  }
});
