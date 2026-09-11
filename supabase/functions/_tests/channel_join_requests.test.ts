// Regression coverage for Phase 6c (channel_join_requests). Mirrors the
// manual verification originally done via a throwaway script -- see
// project_smile-app-phase6c-join-requests memory for the design rationale.
import { assertEquals } from "jsr:@std/assert@1";
import { accessTokenFor, createThrowawayUser, deleteUser, FIXTURES, invoke, svc } from "./helpers.ts";

Deno.test("channel invite with requires_approval creates a pending request, not a membership", async () => {
  const requester = await createThrowawayUser("join-request");
  const code = `TEST${Date.now() % 100000}`;
  try {
    const admin = await accessTokenFor(FIXTURES.adminEmail);
    const requesterAuth = await accessTokenFor(requester.email);

    await svc("pairing_codes", {
      method: "POST",
      body: JSON.stringify({
        space_id: FIXTURES.omaSpaceId,
        channel_id: FIXTURES.enkelkinderChannelId,
        code,
        code_type: "channel_invite",
        expires_at: new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(),
        max_uses: 20,
        requires_approval: true,
        created_by: admin.userId,
      }),
    });

    const claim = await invoke("claim-channel-invite", requesterAuth.accessToken, { code });
    assertEquals(claim.status, 200);
    assertEquals(claim.body.status, "pending_approval");

    const { body: membershipRows } = await svc(
      `channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${requester.id}`,
    );
    assertEquals(membershipRows.length, 0, "a pending request must not create a membership yet");

    // Redeeming again while pending must stay idempotent, not error.
    const claimAgain = await invoke("claim-channel-invite", requesterAuth.accessToken, { code });
    assertEquals(claimAgain.body.status, "pending_approval");

    const list = await invoke("list-channel-join-requests", admin.accessToken, {
      channel_id: FIXTURES.enkelkinderChannelId,
    });
    assertEquals(list.status, 200);
    const found = list.body.requests.find((r: any) => r.user_id === requester.id);
    assertEquals(found?.email, requester.email);

    // The requester themselves must not be able to list requests.
    const forbidden = await invoke("list-channel-join-requests", requesterAuth.accessToken, {
      channel_id: FIXTURES.enkelkinderChannelId,
    });
    assertEquals(forbidden.status, 403);

    const approve = await invoke("decide-channel-join-request", admin.accessToken, {
      request_id: found.id,
      decision: "approve",
    });
    assertEquals(approve.body.status, "approved");

    const { body: afterApprove } = await svc(
      `channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${requester.id}&select=role`,
    );
    assertEquals(afterApprove[0]?.role, "contributor");

    const { body: codeRow } = await svc(`pairing_codes?code=eq.${code}&select=use_count`);
    assertEquals(codeRow[0]?.use_count, 1, "approval should bump the code's use_count exactly once");
  } finally {
    await svc(`channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${requester.id}`, {
      method: "DELETE",
    });
    await svc(`pairing_codes?code=eq.${code}`, { method: "DELETE" });
    await deleteUser(requester.id);
  }
});

Deno.test("a rejected join request can be requested again", async () => {
  const requester = await createThrowawayUser("join-reject");
  const code = `TESTR${Date.now() % 100000}`;
  try {
    const admin = await accessTokenFor(FIXTURES.adminEmail);
    const requesterAuth = await accessTokenFor(requester.email);

    await svc("pairing_codes", {
      method: "POST",
      body: JSON.stringify({
        space_id: FIXTURES.omaSpaceId,
        channel_id: FIXTURES.enkelkinderChannelId,
        code,
        code_type: "channel_invite",
        expires_at: new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(),
        max_uses: 20,
        requires_approval: true,
        created_by: admin.userId,
      }),
    });

    await invoke("claim-channel-invite", requesterAuth.accessToken, { code });
    const list = await invoke("list-channel-join-requests", admin.accessToken, {
      channel_id: FIXTURES.enkelkinderChannelId,
    });
    const requestId = list.body.requests.find((r: any) => r.user_id === requester.id).id;

    const reject = await invoke("decide-channel-join-request", admin.accessToken, {
      request_id: requestId,
      decision: "reject",
    });
    assertEquals(reject.body.status, "rejected");

    const { body: afterReject } = await svc(
      `channel_memberships?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${requester.id}`,
    );
    assertEquals(afterReject.length, 0);

    const reRequest = await invoke("claim-channel-invite", requesterAuth.accessToken, { code });
    assertEquals(reRequest.body.status, "pending_approval", "must be able to request again after a rejection");
  } finally {
    await svc(`channel_join_requests?channel_id=eq.${FIXTURES.enkelkinderChannelId}&user_id=eq.${requester.id}`, {
      method: "DELETE",
    });
    await svc(`pairing_codes?code=eq.${code}`, { method: "DELETE" });
    await deleteUser(requester.id);
  }
});
