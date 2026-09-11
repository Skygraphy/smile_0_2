// Regression coverage for Phase 6b's group -> channel_memberships
// reconciliation trigger (migrations/0020_groups.sql,
// reconcile_channel_group_access). This is the highest-risk piece of logic
// in the group feature -- a regression here silently grants or revokes
// photo access -- so it gets the most thorough test here.
import { assertEquals } from "jsr:@std/assert@1";
import { accessTokenFor, createThrowawayUser, deleteUser, FIXTURES, req, requireEnv, svc } from "./helpers.ts";

async function membershipRow(channelId: string, userId: string) {
  const { body } = await svc(`channel_memberships?channel_id=eq.${channelId}&user_id=eq.${userId}&select=*`);
  return body[0] ?? null;
}

Deno.test("adding a member grants access to every channel already granted to the group, and removing them revokes it", async () => {
  const admin = await accessTokenFor(FIXTURES.adminEmail);
  const member = await createThrowawayUser("group-member");
  let groupId: string | undefined;
  try {
    const { body: groupRows } = await svc("groups", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ owner_id: admin.userId, name: "Test Group (regression suite)" }),
    });
    groupId = groupRows[0].id;

    await svc("group_channel_grants", {
      method: "POST",
      body: JSON.stringify({ group_id: groupId, channel_id: FIXTURES.enkelkinderChannelId, granted_by: admin.userId }),
    });
    await svc("group_channel_grants", {
      method: "POST",
      body: JSON.stringify({ group_id: groupId, channel_id: FIXTURES.stammtischChannelId, granted_by: admin.userId }),
    });

    // Not a member yet -- granting channels first must not create anything.
    assertEquals(await membershipRow(FIXTURES.enkelkinderChannelId, member.id), null);

    await svc("group_members", { method: "POST", body: JSON.stringify({ group_id: groupId, user_id: member.id }) });

    const enkelkinder = await membershipRow(FIXTURES.enkelkinderChannelId, member.id);
    const stammtisch = await membershipRow(FIXTURES.stammtischChannelId, member.id);
    assertEquals(enkelkinder?.role, "contributor");
    assertEquals(enkelkinder?.via_group_id, groupId);
    assertEquals(stammtisch?.role, "contributor");
    assertEquals(stammtisch?.via_group_id, groupId);

    await svc(`group_members?group_id=eq.${groupId}&user_id=eq.${member.id}`, { method: "DELETE" });

    assertEquals(await membershipRow(FIXTURES.enkelkinderChannelId, member.id), null);
    assertEquals(await membershipRow(FIXTURES.stammtischChannelId, member.id), null);
  } finally {
    if (groupId) await svc(`groups?id=eq.${groupId}`, { method: "DELETE" });
    await deleteUser(member.id);
  }
});

Deno.test("a pre-existing direct membership is never overwritten or duplicated by a group grant", async () => {
  const admin = await accessTokenFor(FIXTURES.adminEmail);
  const member = await createThrowawayUser("group-direct-preserve");
  let groupId: string | undefined;
  try {
    await svc("channel_memberships", {
      method: "POST",
      body: JSON.stringify({ channel_id: FIXTURES.enkelkinderChannelId, user_id: member.id, role: "contributor" }),
    });

    const { body: groupRows } = await svc("groups", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ owner_id: admin.userId, name: "Test Group Direct Preserve" }),
    });
    groupId = groupRows[0].id;
    await svc("group_members", { method: "POST", body: JSON.stringify({ group_id: groupId, user_id: member.id }) });
    await svc("group_channel_grants", {
      method: "POST",
      body: JSON.stringify({ group_id: groupId, channel_id: FIXTURES.enkelkinderChannelId, granted_by: admin.userId }),
    });

    const rows = await svc(`channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${member.id}`);
    assertEquals(rows.body.length, 1, "must not duplicate the row");
    assertEquals(rows.body[0].via_group_id, null, "a pre-existing direct membership must not be reattributed to the group");

    // Leaving the group must not touch a membership the group never created.
    await svc(`group_members?group_id=eq.${groupId}&user_id=eq.${member.id}`, { method: "DELETE" });
    const stillThere = await membershipRow(FIXTURES.enkelkinderChannelId, member.id);
    assertEquals(stillThere?.via_group_id, null);
  } finally {
    await svc(`channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${member.id}`, {
      method: "DELETE",
    });
    if (groupId) await svc(`groups?id=eq.${groupId}`, { method: "DELETE" });
    await deleteUser(member.id);
  }
});

Deno.test("group_channel_grants RLS blocks granting a channel the caller doesn't administer", async () => {
  const { anonKey } = requireEnv();
  const outsider = await createThrowawayUser("group-outsider");
  let groupId: string | undefined;
  try {
    const outsiderAuth = await accessTokenFor(outsider.email);
    const { body: groupRows } = await svc("groups", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ owner_id: outsider.id, name: "Outsider's own group" }),
    });
    groupId = groupRows[0].id;

    const { url } = requireEnv();
    const attempt = await req(`${url}/rest/v1/group_channel_grants`, {
      method: "POST",
      headers: { apikey: anonKey, Authorization: `Bearer ${outsiderAuth.accessToken}`, Prefer: "return=representation" },
      body: JSON.stringify({ group_id: groupId, channel_id: FIXTURES.enkelkinderChannelId, granted_by: outsider.id }),
    });
    assertEquals(attempt.status, 403, "RLS must reject granting a channel the caller doesn't administer");
  } finally {
    if (groupId) await svc(`groups?id=eq.${groupId}`, { method: "DELETE" });
    await deleteUser(outsider.id);
  }
});
