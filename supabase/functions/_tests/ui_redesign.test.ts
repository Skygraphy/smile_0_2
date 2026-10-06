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

// Album list line (TODO from stage 3, done 2026-10-05): who posted last and
// how many in a row -- hidden items of the caller don't count.
Deno.test("the album list knows who posted last and how many in a row", async () => {
  requireEnv();
  const admin = await createThrowawayUser("ladmin");
  const roman = await createThrowawayUser("lroman");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "List Admin");
    await ensureProfile(roman.id, "List Roman");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    space = await createSpace(adminToken, "List Space");
    const album = await createChannel(adminToken, space, "List Album");
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: album, user_id: roman.id }) });

    const post = async (sender: string, type: "photo" | "video", minutesAgo: number) => {
      const { status, body } = await svc("media_items", {
        method: "POST",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({
          channel_id: album,
          sender_id: sender,
          media_type: type,
          storage_path_original: `test/${crypto.randomUUID()}`,
          processing_status: "ready",
          created_at: new Date(Date.now() - minutesAgo * 60_000).toISOString(),
        }),
      });
      assertEquals(status, 201, JSON.stringify(body));
      return body[0].id as string;
    };
    await post(admin.id, "photo", 10);
    await post(roman.id, "photo", 3);
    await post(roman.id, "video", 2);
    const newest = await post(roman.id, "photo", 1);

    type Row = { channel_id: string; last_post: { sender_id: string; sender_name: string; photos: number; videos: number } };
    const lastPostOf = async () => {
      const list = await invoke("list-my-channels", adminToken, {});
      assertEquals(list.status, 200, JSON.stringify(list.body));
      return (list.body.channels as Row[]).find((c) => c.channel_id === album)!.last_post;
    };
    const before = await lastPostOf();
    assertEquals(before.sender_id, roman.id);
    assertEquals(before.sender_name, "List Roman");
    assertEquals([before.photos, before.videos], [2, 1]);

    // Hiding the newest photo for yourself drops it from your own list line.
    await svc("media_item_hides", { method: "POST", body: JSON.stringify({ media_item_id: newest, user_id: admin.id }) });
    const after = await lastPostOf();
    assertEquals([after.photos, after.videos], [1, 1]);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(roman.id);
    await deleteUser(admin.id);
  }
});

// Unread counter (migrations/0058): others' posts since you last opened the
// album; opening it (mark_album_seen) clears it; a repeat call changes
// nothing, so the open feed can call it after every reload without looping.
Deno.test("unread counter counts others' new posts until the album is opened", async () => {
  requireEnv();
  const admin = await createThrowawayUser("uadmin");
  const roman = await createThrowawayUser("uroman");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "Unread Admin");
    await ensureProfile(roman.id, "Unread Roman");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    space = await createSpace(adminToken, "Unread Space");
    const album = await createChannel(adminToken, space, "Unread Album");
    await svc("channel_members", { method: "POST", body: JSON.stringify({ channel_id: album, user_id: roman.id }) });

    const post = async (sender: string) => {
      const { status, body } = await svc("media_items", {
        method: "POST",
        body: JSON.stringify({
          channel_id: album,
          sender_id: sender,
          media_type: "photo",
          storage_path_original: `test/${crypto.randomUUID()}`,
          processing_status: "ready",
        }),
      });
      assertEquals(status, 201, JSON.stringify(body));
    };
    const unread = async () => {
      const list = await invoke("list-my-channels", adminToken, {});
      assertEquals(list.status, 200, JSON.stringify(list.body));
      return (list.body.channels as { channel_id: string; unread_count: number }[])
        .find((c) => c.channel_id === album)!.unread_count;
    };
    const markSeen = () =>
      asUser("rpc/mark_album_seen", adminToken, { method: "POST", body: JSON.stringify({ p_channel: album }) });
    const marker = async () =>
      (await svc(`album_reads?user_id=eq.${admin.id}&channel_id=eq.${album}&select=last_seen_at`)).body[0]?.last_seen_at;

    await post(admin.id); // own posts never count
    await post(roman.id);
    await post(roman.id);
    assertEquals(await unread(), 2);

    assertEquals((await markSeen()).status, 204);
    assertEquals(await unread(), 0);
    const first = await marker();
    assertEquals((await markSeen()).status, 204);
    assertEquals(await marker(), first, "a repeat call must not move the marker");

    await post(roman.id);
    assertEquals(await unread(), 1);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(roman.id);
    await deleteUser(admin.id);
  }
});

// Notification history (migrations/0059): every visible push is also kept,
// so Neuigkeiten can show it later -- readable only by its recipient.
Deno.test("every push lands in the recipient's own notification history", async () => {
  requireEnv();
  const admin = await createThrowawayUser("hadmin");
  const invitee = await createThrowawayUser("hinv");
  let space: string | undefined;
  try {
    await ensureProfile(admin.id, "History Admin");
    await ensureProfile(invitee.id, "History Invitee");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: inviteeToken } = await accessTokenFor(invitee.email);
    space = await createSpace(adminToken, "History Space");
    const album = await createChannel(adminToken, space, "History Album");

    const invite = await invoke("invite-channel-member", adminToken, { channel_id: album, email: invitee.email });
    assertEquals(invite.status, 200, JSON.stringify(invite.body));

    const mine = await asUser("user_notifications?select=title,body,data", inviteeToken);
    assertEquals(mine.status, 200, JSON.stringify(mine.body));
    const rows = mine.body as { title: string; body: string; data: Record<string, string> }[];
    assertEquals(rows.length, 1, JSON.stringify(rows));
    assertEquals(rows[0].title, "Einladung ins Album");
    assertEquals(rows[0].data.channel_id, album);

    // Nobody else reads it (RLS): the admin sees none of the invitee's rows.
    const theirs = await asUser(`user_notifications?user_id=eq.${invitee.id}&select=id`, adminToken);
    assertEquals(theirs.body, []);

    // Dismissing (migrations/0060): nobody else can remove it, its owner can.
    const foreign = await asUser(`user_notifications?user_id=eq.${invitee.id}`, adminToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals(foreign.body, []);
    const own = await asUser(`user_notifications?user_id=eq.${invitee.id}`, inviteeToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals((own.body as unknown[]).length, 1, JSON.stringify(own.body));
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(invitee.id);
    await deleteUser(admin.id);
  }
});
