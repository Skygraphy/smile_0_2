// Fixes from the 2026-09-29 architecture review (see the decisions in
// migrations/0046 onwards) -- one test per fixed weakness.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
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

/** Shares [channelId] into [viewerSpaceId] via invite + accept, as the app does. */
async function shareChannel(ownerToken: string, viewerToken: string, viewerEmail: string, channelId: string, viewerSpaceId: string) {
  const inviteResp = await invoke("invite-channel-share", ownerToken, { channel_id: channelId, email: viewerEmail });
  assertEquals(inviteResp.status, 200, JSON.stringify(inviteResp.body));
  const { status } = await asUser(`channel_share_requests?id=eq.${inviteResp.body.request_id}`, viewerToken, {
    method: "PATCH",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ status: "accepted", space_id: viewerSpaceId }),
  });
  assertEquals(status, 204);
}

// Weakness 1 (migrations/0046): the channel's own side may end a share.
Deno.test("the channel's owner can end a share it granted", async () => {
  requireEnv();
  const owner = await createThrowawayUser("owner");
  const viewer = await createThrowawayUser("viewer");
  let ownerSpace: string | undefined;
  let viewerSpace: string | undefined;
  try {
    await ensureProfile(owner.id, "Test Owner");
    await ensureProfile(viewer.id, "Test Viewer");
    const { accessToken: ownerToken } = await accessTokenFor(owner.email);
    const { accessToken: viewerToken } = await accessTokenFor(viewer.email);
    ownerSpace = await createSpace(ownerToken, "Owner Space");
    viewerSpace = await createSpace(viewerToken, "Viewer Space");
    const channelId = await createChannel(ownerToken, ownerSpace, "Shared Channel");
    await shareChannel(ownerToken, viewerToken, viewer.email, channelId, viewerSpace);

    // A new co-owner of the viewing household now sees the channel too --
    // by decision, a share belongs to the whole household (the owner's side
    // is notified via emit_event('co_owner_added'), not asked).
    const partner = await createThrowawayUser("partner");
    try {
      const { status: coStatus } = await svc("space_co_owners", {
        method: "POST",
        body: JSON.stringify({ space_id: viewerSpace, user_id: partner.id }),
      });
      assertEquals(coStatus, 201);
      const { accessToken: partnerToken } = await accessTokenFor(partner.email);
      const { body: visible } = await asUser(`channels?id=eq.${channelId}`, partnerToken);
      assertEquals(visible.length, 1, "a co-owner of the viewing household sees shared-in channels");
    } finally {
      await svc(`space_co_owners?user_id=eq.${partner.id}`, { method: "DELETE" });
      await deleteUser(partner.id);
    }

    const { status } = await asUser(`channel_shares?channel_id=eq.${channelId}&space_id=eq.${viewerSpace}`, ownerToken, {
      method: "DELETE",
    });
    assertEquals(status, 204);
    const { body } = await svc(`channel_shares?channel_id=eq.${channelId}`);
    assertEquals(body.length, 0, "the owner's side must be able to take a share back");
  } finally {
    if (viewerSpace) await deleteSpace(viewerSpace);
    if (ownerSpace) await deleteSpace(ownerSpace);
    await deleteUser(owner.id);
    await deleteUser(viewer.id);
  }
});
