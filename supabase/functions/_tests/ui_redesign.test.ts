// Server additions made for the UI redesign (2026-10-05): small, additive
// payload extensions the new screens rely on.
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

// "Neuigkeiten" (stage 6): someone asking to join an album must reach the
// album's managers -- Admin AND Co-Admins -- in their personal inbox, and
// nobody else.
Deno.test("join requests show up in every manager's Neuigkeiten, and only there", async () => {
  requireEnv();
  const admin = await createThrowawayUser("nadmin");
  const coAdmin = await createThrowawayUser("nco");
  const requester = await createThrowawayUser("nreq");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "News Admin");
    await ensureProfile(coAdmin.id, "News CoAdmin");
    await ensureProfile(requester.id, "News Requester");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: coToken } = await accessTokenFor(coAdmin.email);
    const { accessToken: requesterToken } = await accessTokenFor(requester.email);
    space = await createSpace(adminToken, "News Space");
    const channel = await createChannel(adminToken, space, "News Album");
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: space, user_id: coAdmin.id }) });
    await svc("channel_membership_requests", {
      method: "POST",
      body: JSON.stringify({ channel_id: channel, user_id: requester.id, direction: "request" }),
    });

    for (const token of [adminToken, coToken]) {
      const inbox = await invoke("list-my-invites", token, { include_managed: true });
      assertEquals(inbox.status, 200, JSON.stringify(inbox.body));
      const managed = inbox.body.managed_membership_requests as {
        channel_name: string;
        counterpart_user_id: string;
        counterpart_display_name: string;
      }[];
      assertEquals(managed.length, 1, JSON.stringify(inbox.body));
      assertEquals(managed[0].channel_name, "News Album");
      assertEquals(managed[0].counterpart_user_id, requester.id);
      assertEquals(managed[0].counterpart_display_name, "News Requester");
    }

    // The requester sees their own request as before, nothing "managed".
    const own = await invoke("list-my-invites", requesterToken, { include_managed: true });
    assertEquals(own.status, 200, JSON.stringify(own.body));
    assertEquals((own.body.membership_requests as unknown[]).length, 1);
    assertEquals(own.body.managed_membership_requests, []);

    // Old callers (no flag) get exactly the old payload shape.
    const legacy = await invoke("list-my-invites", adminToken, {});
    assertEquals(Object.keys(legacy.body).sort(), ["membership_requests", "share_requests"]);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(requester.id);
    await deleteUser(coAdmin.id);
    await deleteUser(admin.id);
  }
});
