// Regression coverage for 0030_multi_space_channels.sql -- the concrete
// motivating scenario is real fixture data here: "Oma" and "Opa" are two
// actual Spaces in this project (both owned by FIXTURES.adminEmail), and
// this suite verifies a channel can be shared between them via a
// channel_space_share code, that both Spaces then have full symmetric
// access, that unlinking one Space never destroys the other's copy, and
// that the orphan-cleanup trigger only fires once the *last* link is
// removed. A throwaway channel (via the create_channel RPC) is used for
// the destructive delete/unlink assertions so the real "Enkelkinder"
// fixture channel is never at risk.
import { assertEquals, assertExists } from "jsr:@std/assert@1";
import { accessTokenFor, asUser, FIXTURES, invoke, requireEnv, svc } from "./helpers.ts";

async function createThrowawayChannel(accessToken: string, spaceId: string, name: string): Promise<string> {
  const { url, anonKey } = requireEnv();
  const res = await fetch(`${url}/rest/v1/rpc/create_channel`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: anonKey, Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({ p_space_id: spaceId, p_name: name }),
  });
  const body = await res.json();
  assertExists(body?.id, `create_channel failed: ${JSON.stringify(body)}`);
  return body.id as string;
}

async function spaceChannelRows(channelId: string) {
  const { body } = await svc(`space_channels?channel_id=eq.${channelId}&select=space_id`);
  return (body as { space_id: string }[]).map((r) => r.space_id).sort();
}

async function channelExists(channelId: string): Promise<boolean> {
  const { body } = await svc(`channels?id=eq.${channelId}&select=id`);
  return body.length > 0;
}

Deno.test("a channel_space_share code links a second Space; unlinking is safe until the last link is removed", async () => {
  const admin = await accessTokenFor(FIXTURES.adminEmail); // owns both Oma and Opa
  const channelId = await createThrowawayChannel(admin.accessToken, FIXTURES.omaSpaceId, "Test Share Channel");
  const code = `TESTSHARE${Date.now() % 100000}`;
  try {
    assertEquals(await spaceChannelRows(channelId), [FIXTURES.omaSpaceId], "starts linked only to Oma");

    // Generate the share code as the channel's admin (auto-joined by
    // on_channel_created), same RLS path channel_members_screen.dart uses.
    await asUser("pairing_codes", admin.accessToken, {
      method: "POST",
      body: JSON.stringify({
        channel_id: channelId,
        code,
        code_type: "channel_space_share",
        expires_at: new Date(Date.now() + 3600 * 1000).toISOString(),
        max_uses: 5,
      }),
    });

    // Redeem it into Opa.
    const claim = await invoke("claim-channel-space-share", admin.accessToken, { code, space_id: FIXTURES.opaSpaceId });
    assertEquals(claim.status, 200, JSON.stringify(claim.body));
    assertEquals(claim.body.status, "linked");
    assertEquals(claim.body.channel_id, channelId);

    assertEquals(
      await spaceChannelRows(channelId),
      [FIXTURES.omaSpaceId, FIXTURES.opaSpaceId].sort(),
      "now linked to both Spaces",
    );

    // Redeeming again (idempotent) must not error or double-link.
    const claimAgain = await invoke("claim-channel-space-share", admin.accessToken, {
      code,
      space_id: FIXTURES.opaSpaceId,
    });
    assertEquals(claimAgain.body.status, "linked");
    assertEquals(await spaceChannelRows(channelId), [FIXTURES.omaSpaceId, FIXTURES.opaSpaceId].sort());

    // list-channel-members must now report both linked Spaces.
    const members = await invoke("list-channel-members", admin.accessToken, { channel_id: channelId });
    const returnedSpaceIds = (members.body.spaces as { id: string }[]).map((s) => s.id).sort();
    assertEquals(returnedSpaceIds, [FIXTURES.omaSpaceId, FIXTURES.opaSpaceId].sort());

    // Unlink Oma -- the channel must survive (Opa's link remains).
    await asUser(`space_channels?space_id=eq.${FIXTURES.omaSpaceId}&channel_id=eq.${channelId}`, admin.accessToken, {
      method: "DELETE",
    });
    assertEquals(await channelExists(channelId), true, "channel must survive while Opa is still linked");
    assertEquals(await spaceChannelRows(channelId), [FIXTURES.opaSpaceId]);

    // Unlink Opa too -- now the *last* link is gone, so the orphan-cleanup
    // trigger (delete_channel_if_orphaned) must delete the channel itself.
    await asUser(`space_channels?space_id=eq.${FIXTURES.opaSpaceId}&channel_id=eq.${channelId}`, admin.accessToken, {
      method: "DELETE",
    });
    assertEquals(await channelExists(channelId), false, "channel must be deleted once no Space links to it any more");
  } finally {
    await svc(`pairing_codes?code=eq.${code}`, { method: "DELETE" });
    // Best-effort: if an assertion failed before the channel deleted
    // itself, still clean up rather than leaving test debris behind.
    await svc(`space_channels?channel_id=eq.${channelId}`, { method: "DELETE" });
    await svc(`channels?id=eq.${channelId}`, { method: "DELETE" });
  }
});

Deno.test("assign-device-channel accepts a channel shared into the device's Space, not just its original one", async () => {
  const admin = await accessTokenFor(FIXTURES.adminEmail);
  const channelId = await createThrowawayChannel(admin.accessToken, FIXTURES.omaSpaceId, "Test Frame Share Channel");
  let deviceId: string | undefined;
  try {
    const { body: deviceRows } = await svc("devices", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({ space_id: FIXTURES.opaSpaceId, name: "Test Frame (regression suite)" }),
    });
    deviceId = deviceRows[0].id;

    // Before sharing: the channel only lives in Oma, the device is in Opa.
    const before = await invoke("assign-device-channel", admin.accessToken, { device_id: deviceId, channel_id: channelId });
    assertEquals(before.status, 400);
    assertEquals(before.body.error, "channel_not_in_device_space");

    // Share the channel into Opa (direct service-role insert here -- the
    // code-based redemption path is covered by the previous test).
    await svc("space_channels", {
      method: "POST",
      body: JSON.stringify({ space_id: FIXTURES.opaSpaceId, channel_id: channelId }),
    });

    const after = await invoke("assign-device-channel", admin.accessToken, { device_id: deviceId, channel_id: channelId });
    assertEquals(after.status, 200, JSON.stringify(after.body));
    assertEquals(after.body.status, "assigned");
  } finally {
    if (deviceId) await svc(`channel_memberships?device_id=eq.${deviceId}`, { method: "DELETE" });
    if (deviceId) await svc(`devices?id=eq.${deviceId}`, { method: "DELETE" });
    await svc(`space_channels?channel_id=eq.${channelId}`, { method: "DELETE" });
    await svc(`channels?id=eq.${channelId}`, { method: "DELETE" });
  }
});
