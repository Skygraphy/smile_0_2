// Fixes from the 2026-09-29 architecture review (see the decisions in
// migrations/0046 onwards) -- one test per fixed weakness.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
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

async function pairFrame(ownerToken: string, spaceId: string): Promise<string> {
  const createResp = await invoke("create-frame", ownerToken, { space_id: spaceId, name: "Test Frame" });
  assertEquals(createResp.status, 200, JSON.stringify(createResp.body));
  return createResp.body.frame_id as string;
}

// Weakness 3 (migrations/0047): one source of authorization. Each assert
// below failed before 0047 because one copy of a rule had drifted.
Deno.test("co-owners get the same access everywhere (single source)", async () => {
  requireEnv();
  const owner = await createThrowawayUser("owner");
  const viewerAdmin = await createThrowawayUser("vadmin");
  const viewerCo = await createThrowawayUser("vco");
  let ownerSpace: string | undefined;
  let viewerSpace: string | undefined;
  try {
    await ensureProfile(owner.id, "Test Owner");
    await ensureProfile(viewerAdmin.id, "Test Viewer Admin");
    await ensureProfile(viewerCo.id, "Test Viewer CoOwner");
    const { accessToken: ownerToken } = await accessTokenFor(owner.email);
    const { accessToken: viewerAdminToken } = await accessTokenFor(viewerAdmin.email);
    const { accessToken: viewerCoToken } = await accessTokenFor(viewerCo.email);
    ownerSpace = await createSpace(ownerToken, "Owner Space");
    viewerSpace = await createSpace(viewerAdminToken, "Viewer Space");
    const sharedChannel = await createChannel(ownerToken, ownerSpace, "Shared Channel");
    const viewerOwnChannel = await createChannel(viewerAdminToken, viewerSpace, "Viewer Own Channel");
    await shareChannel(ownerToken, viewerAdminToken, viewerAdmin.email, sharedChannel, viewerSpace);
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: viewerSpace, user_id: viewerCo.id }) });

    // Edge Functions used to know only a shared-in Space's Administrator.
    const roster = await invoke("list-channel-members", viewerCoToken, { channel_id: sharedChannel });
    assertEquals(roster.status, 200, `co-owner of the viewing Space must see the roster: ${JSON.stringify(roster.body)}`);

    // The home screen list used to forget a co-owner's own Space's channels
    // and channels shared into it.
    const mine = await invoke("list-my-channels", viewerCoToken, {});
    assertEquals(mine.status, 200, JSON.stringify(mine.body));
    const ids = (mine.body.channels as { channel_id: string }[]).map((c) => c.channel_id).sort();
    assertEquals(ids, [sharedChannel, viewerOwnChannel].sort());

    // Co-owners manage the Space -> may rename it.
    const { status: renameStatus } = await asUser(`spaces?id=eq.${viewerSpace}`, viewerCoToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ name: "Renamed by co-owner" }),
    });
    assertEquals(renameStatus, 204);
    const { body: renamed } = await svc(`spaces?id=eq.${viewerSpace}&select=name`);
    assertEquals(renamed[0].name, "Renamed by co-owner");

    // ...but the Administrator role only changes hands via the handover,
    // never by a plain update (not even by the Administrator).
    const { status: grabStatus } = await asUser(`spaces?id=eq.${viewerSpace}`, viewerAdminToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ owner_id: owner.id }),
    });
    assert(grabStatus >= 400, `a plain owner_id change must be refused, got ${grabStatus}`);
  } finally {
    await svc(`space_co_owners?user_id=eq.${viewerCo.id}`, { method: "DELETE" });
    if (viewerSpace) await deleteSpace(viewerSpace);
    if (ownerSpace) await deleteSpace(ownerSpace);
    await deleteUser(owner.id);
    await deleteUser(viewerAdmin.id);
    await deleteUser(viewerCo.id);
  }
});

Deno.test("a Frame only gets channels its household can see, not what one person can", async () => {
  requireEnv();
  const alice = await createThrowawayUser("alice");
  const bob = await createThrowawayUser("bob");
  let aliceSpace: string | undefined;
  let bobSpace: string | undefined;
  try {
    await ensureProfile(alice.id, "Test Alice");
    await ensureProfile(bob.id, "Test Bob");
    const { accessToken: aliceToken } = await accessTokenFor(alice.email);
    const { accessToken: bobToken } = await accessTokenFor(bob.email);
    aliceSpace = await createSpace(aliceToken, "Alice Space");
    bobSpace = await createSpace(bobToken, "Bob Space");
    // Alice posts in Bob's channel personally -- her household doesn't see it.
    const bobChannel = await createChannel(bobToken, bobSpace, "Bob Channel");
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: bobChannel, user_id: alice.id }) });
    const frameId = await pairFrame(aliceToken, aliceSpace);

    const viaFunction = await invoke("assign-frame-channel", aliceToken, { frame_id: frameId, channel_id: bobChannel });
    assertEquals(viaFunction.status, 400, JSON.stringify(viaFunction.body));

    const { status: viaRls } = await asUser("frame_channels", aliceToken, {
      method: "POST",
      body: JSON.stringify({ frame_id: frameId, channel_id: bobChannel }),
    });
    assert(viaRls >= 400, `direct insert must be refused too, got ${viaRls}`);
    const { body: assigned } = await svc(`frame_channels?frame_id=eq.${frameId}`);
    assertEquals(assigned.length, 0);
  } finally {
    if (aliceSpace) await deleteSpace(aliceSpace);
    if (bobSpace) await deleteSpace(bobSpace);
    await deleteUser(alice.id);
    await deleteUser(bob.id);
  }
});

// migrations/0051: deleting an account must work (it never did via the
// Auth API) -- and when the Administrator's account goes, the
// longest-standing co-owner takes over (0037's handover, untested until now).
Deno.test("deleting the Administrator's account hands the Space to a co-owner", async () => {
  requireEnv();
  const admin = await createThrowawayUser("admin");
  const coOwner = await createThrowawayUser("coowner");
  let spaceId: string | undefined;
  try {
    await ensureProfile(admin.id, "Test Admin");
    await ensureProfile(coOwner.id, "Test CoOwner");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    spaceId = await createSpace(adminToken, "Handover Space");
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: spaceId, user_id: coOwner.id }) });

    await deleteUser(admin.id); // throws if the Auth API refuses

    const { body: space } = await svc(`spaces?id=eq.${spaceId}&select=owner_id`);
    assertEquals(space[0].owner_id, coOwner.id, "the co-owner is the new Administrator");
    const { body: coOwners } = await svc(`space_co_owners?space_id=eq.${spaceId}`);
    assertEquals(coOwners.length, 0, "and no longer listed as a co-owner");
  } finally {
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(coOwner.id);
  }
});

// migrations/0052 (decision 2026-10-01): everyone who manages a Space posts
// in all of its channels -- existing ones when they become co-owner, new
// ones whoever creates them.
Deno.test("Space managers are members of every channel of their Space", async () => {
  requireEnv();
  const admin = await createThrowawayUser("admin");
  const coOwner = await createThrowawayUser("coowner");
  let spaceId: string | undefined;
  try {
    await ensureProfile(admin.id, "Test Admin");
    await ensureProfile(coOwner.id, "Test CoOwner");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: coOwnerToken } = await accessTokenFor(coOwner.email);
    spaceId = await createSpace(adminToken, "Managed Space");
    const before = await createChannel(adminToken, spaceId, "Before");
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: spaceId, user_id: coOwner.id }) });

    const { body: joined } = await svc(`channel_members?channel_id=eq.${before}&user_id=eq.${coOwner.id}`);
    assertEquals(joined.length, 1, "a new co-owner joins the existing channels");

    const after = await createChannel(coOwnerToken, spaceId, "After");
    const { body: members } = await svc(`channel_members?channel_id=eq.${after}&select=user_id`);
    assertEquals(
      (members as { user_id: string }[]).map((m) => m.user_id).sort(),
      [admin.id, coOwner.id].sort(),
      "a channel created by a co-owner includes the Administrator too",
    );

    const { status: leave } = await asUser(`channel_members?channel_id=eq.${before}&user_id=eq.${coOwner.id}`, coOwnerToken, {
      method: "DELETE",
    });
    assertEquals(leave, 204, "a manager may still leave a channel");
  } finally {
    await svc(`space_co_owners?user_id=eq.${coOwner.id}`, { method: "DELETE" });
    if (spaceId) await deleteSpace(spaceId);
    await deleteUser(admin.id);
    await deleteUser(coOwner.id);
  }
});
