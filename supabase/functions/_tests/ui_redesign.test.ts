// Server additions made for the UI redesign (2026-10-05): small, additive
// payload extensions the new screens rely on.
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

/** The notify-event outbox calls (migrations/0050) raised for [kind]. */
async function emitted(kind: string): Promise<Record<string, string | null>[]> {
  const { status, body } = await svc(
    `internal_calls?fn=eq.notify-event&body->>kind=eq.${kind}&select=body&order=id.desc&limit=50`,
  );
  assertEquals(status, 200, JSON.stringify(body));
  return (body as { body: { payload: Record<string, string | null> } }[]).map((r) => r.body.payload);
}

// "Everything interactive" (migrations/0057): requests, leaving/removal from
// an album and Co-Admin changes each raise a server event for notify-event,
// carrying who did it so the right side gets the push.
Deno.test("requests, leaving, removals and Co-Admin changes raise push events", async () => {
  requireEnv();
  const admin = await createThrowawayUser("eadmin");
  const co = await createThrowawayUser("eco");
  const member = await createThrowawayUser("emem");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "Event Admin");
    await ensureProfile(co.id, "Event Co");
    await ensureProfile(member.id, "Event Member");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: coToken } = await accessTokenFor(co.email);
    const { accessToken: memberToken } = await accessTokenFor(member.email);
    space = await createSpace(adminToken, "Event Space");
    const album = await createChannel(adminToken, space, "Event Album");

    // 1. A request (as the app makes it: the person inserts it themselves).
    const created = await asUser("channel_membership_requests", memberToken, {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ channel_id: album, user_id: member.id, direction: "request" }),
    });
    assertEquals(created.status, 201, JSON.stringify(created.body));
    const requestId = created.body[0].id as string;
    assertEquals((await emitted("request_created")).some((p) => p.id === requestId), true);

    // Accept it, then the member leaves on their own -> actor = the member.
    const accepted = await asUser(`channel_membership_requests?id=eq.${requestId}`, adminToken, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ status: "accepted" }),
    });
    assertEquals(accepted.status, 204);
    const left = await asUser(`channel_members?channel_id=eq.${album}&user_id=eq.${member.id}`, memberToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals(left.status, 200, JSON.stringify(left.body));
    assertEquals((left.body as unknown[]).length, 1, "the member's own leave must really delete the row");
    assertEquals(
      (await emitted("member_removed")).some((p) => p.channel_id === album && p.user_id === member.id && p.actor_id === member.id),
      true,
    );

    // Back in, then removed by the Admin -> actor = the Admin.
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: album, user_id: member.id }) });
    const removed = await asUser(`channel_members?channel_id=eq.${album}&user_id=eq.${member.id}`, adminToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals((removed.body as unknown[]).length, 1, JSON.stringify(removed.body));
    assertEquals(
      (await emitted("member_removed")).some((p) => p.user_id === member.id && p.actor_id === admin.id),
      true,
    );

    // Co-Admin steps down -> actor = the Co-Admin.
    await svc("space_co_owners", { method: "POST", body: JSON.stringify({ space_id: space, user_id: co.id }) });
    const stepped = await asUser(`space_co_owners?space_id=eq.${space}&user_id=eq.${co.id}`, coToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals((stepped.body as unknown[]).length, 1, JSON.stringify(stepped.body));
    assertEquals(
      (await emitted("co_admin_removed")).some((p) => p.space_id === space && p.user_id === co.id && p.actor_id === co.id),
      true,
    );
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(member.id);
    await deleteUser(co.id);
    await deleteUser(admin.id);
  }
});
