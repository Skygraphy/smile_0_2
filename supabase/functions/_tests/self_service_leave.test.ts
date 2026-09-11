// Regression coverage for self-service leave (migrations/0026, 0027) --
// includes the real RLS gotcha found this session: a DELETE needs the row
// to also be visible via a SELECT policy, not just pass the DELETE
// policy's USING clause (see project_smile-app-self-service-leave memory).
import { assertEquals } from "jsr:@std/assert@1";
import { accessTokenFor, asUser, createThrowawayUser, deleteUser, FIXTURES, svc } from "./helpers.ts";

Deno.test("a member can leave a channel they joined directly", async () => {
  const member = await createThrowawayUser("leave-direct");
  try {
    const { body: rows } = await svc("channel_memberships", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ channel_id: FIXTURES.enkelkinderChannelId, user_id: member.id, role: "contributor" }),
    });
    const membershipId = rows[0].id;
    const memberAuth = await accessTokenFor(member.email);

    const leave = await asUser(`channel_memberships?id=eq.${membershipId}`, memberAuth.accessToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals(leave.status, 200);
    assertEquals(leave.body.length, 1, "the delete must actually match and return the row, not silently no-op");

    const { body: after } = await svc(`channel_memberships?id=eq.${membershipId}`);
    assertEquals(after.length, 0);
  } finally {
    await svc(`channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${member.id}`, {
      method: "DELETE",
    });
    await deleteUser(member.id);
  }
});

Deno.test("a member cannot self-leave a group-derived channel membership directly", async () => {
  const admin = await accessTokenFor(FIXTURES.adminEmail);
  const member = await createThrowawayUser("leave-group-derived");
  let groupId: string | undefined;
  try {
    const { body: groupRows } = await svc("groups", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ owner_id: admin.userId, name: "Test Group Leave Guard" }),
    });
    groupId = groupRows[0].id;
    await svc("group_members", { method: "POST", body: JSON.stringify({ group_id: groupId, user_id: member.id }) });
    await svc("group_channel_grants", {
      method: "POST",
      body: JSON.stringify({ group_id: groupId, channel_id: FIXTURES.enkelkinderChannelId, granted_by: admin.userId }),
    });

    const { body: membershipRows } = await svc(
      `channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${member.id}&select=id`,
    );
    const membershipId = membershipRows[0].id;
    const memberAuth = await accessTokenFor(member.email);

    const blockedLeave = await asUser(`channel_memberships?id=eq.${membershipId}`, memberAuth.accessToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals(blockedLeave.body.length, 0, "RLS must block a direct self-leave of a group-derived row");

    const { body: stillThere } = await svc(`channel_memberships?id=eq.${membershipId}`);
    assertEquals(stillThere.length, 1);
  } finally {
    if (groupId) await svc(`groups?id=eq.${groupId}`, { method: "DELETE" });
    await deleteUser(member.id);
  }
});

Deno.test("leaving a group revokes every channel it granted, via the reconcile trigger", async () => {
  const admin = await accessTokenFor(FIXTURES.adminEmail);
  const member = await createThrowawayUser("leave-group-itself");
  let groupId: string | undefined;
  try {
    const { body: groupRows } = await svc("groups", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ owner_id: admin.userId, name: "Test Group Leave Cascade" }),
    });
    groupId = groupRows[0].id;
    await svc("group_members", { method: "POST", body: JSON.stringify({ group_id: groupId, user_id: member.id }) });
    await svc("group_channel_grants", {
      method: "POST",
      body: JSON.stringify({ group_id: groupId, channel_id: FIXTURES.enkelkinderChannelId, granted_by: admin.userId }),
    });

    const memberAuth = await accessTokenFor(member.email);
    const leaveGroup = await asUser(`group_members?group_id=eq.${groupId}&user_id=eq.${member.id}`, memberAuth.accessToken, {
      method: "DELETE",
      headers: { Prefer: "return=representation" },
    });
    assertEquals(leaveGroup.body.length, 1, "the self-leave delete must actually match the row");

    const { body: membershipAfter } = await svc(
      `channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${member.id}`,
    );
    assertEquals(membershipAfter.length, 0, "reconcile must have revoked the group-derived channel access");
  } finally {
    if (groupId) await svc(`groups?id=eq.${groupId}`, { method: "DELETE" });
    await deleteUser(member.id);
  }
});
