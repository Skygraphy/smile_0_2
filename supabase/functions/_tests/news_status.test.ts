// The Neuigkeiten icon in one query (migrations/0074, 2026-10-12): an
// invite waiting for the caller turns needs_answer on, deciding it turns
// it off again; the inviting admin has nothing to answer.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
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

Deno.test("my_news_status: needs_answer follows a pending invite", async () => {
  const admin = await createThrowawayUser("nsadm");
  const guest = await createThrowawayUser("nsgst");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "NS Admin");
    await ensureProfile(guest.id, "NS Guest");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: guestToken } = await accessTokenFor(guest.email);
    space = await createSpace(adminToken, "NS Space");
    const album = await createChannel(adminToken, space, "NS Album");
    const status = async (token: string) =>
      (await asUser("rpc/my_news_status", token, { method: "POST", body: "{}" })).body as { needs_answer: boolean };

    assertEquals((await status(guestToken)).needs_answer, false);
    const invited = await invoke("invite-channel-member", adminToken, { channel_id: album, user_id: guest.id });
    assertEquals(invited.status, 200, JSON.stringify(invited.body));
    assertEquals((await status(guestToken)).needs_answer, true);
    assertEquals((await status(adminToken)).needs_answer, false);

    // Accepted: nothing waits any more.
    const decided = await asUser(`channel_membership_requests?id=eq.${invited.body.request_id}`, guestToken, {
      method: "PATCH",
      body: JSON.stringify({ status: "accepted" }),
    });
    assertEquals(decided.status < 300, true, JSON.stringify(decided.body));
    assertEquals((await status(guestToken)).needs_answer, false);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(guest.id);
    await deleteUser(admin.id);
  }
});
