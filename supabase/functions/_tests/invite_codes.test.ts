// Inviting by QR code / typed code and by name (migrations/0073,
// 2026-10-11): scanned = in at once, typed = the admins decide; a
// Co-Admin code works by QR only; known_people lists only people one
// already shares something with.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
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

Deno.test("invite codes: scan joins, typing asks, co-admin by QR only, known people", async () => {
  const admin = await createThrowawayUser("icadm");
  const scanner = await createThrowawayUser("icscn");
  const typer = await createThrowawayUser("ictyp");
  const stranger = await createThrowawayUser("icstr");
  const spaces: string[] = [];
  try {
    await ensureProfile(admin.id, "IC Admin");
    await ensureProfile(scanner.id, "IC Scanner");
    await ensureProfile(typer.id, "IC Typer");
    await ensureProfile(stranger.id, "IC Stranger");
    const { accessToken: adminToken } = await accessTokenFor(admin.email);
    const { accessToken: scannerToken } = await accessTokenFor(scanner.email);
    const { accessToken: typerToken } = await accessTokenFor(typer.email);
    const { accessToken: strangerToken } = await accessTokenFor(stranger.email);
    const space = await createSpace(adminToken, "IC Space");
    spaces.push(space);
    const album = await createChannel(adminToken, space, "IC Album");

    // Only the album's managers create codes; asking again gives the same.
    const first = await invoke("create-invite-code", adminToken, { kind: "album_member", target_id: album });
    assertEquals(first.status, 200, JSON.stringify(first.body));
    const code = first.body.code as string;
    assertEquals(code.length, 6);
    assertEquals((await invoke("create-invite-code", adminToken, { kind: "album_member", target_id: album })).body.code, code);
    assertEquals((await invoke("create-invite-code", strangerToken, { kind: "album_member", target_id: album })).status, 403);

    // Scanned: a member at once.
    const scanned = await invoke("redeem-invite-code", scannerToken, { code: `smile:invite:${code}`, via: "qr" });
    assertEquals(scanned.body.status, "joined", JSON.stringify(scanned.body));
    const { body: members } = await svc(`channel_members?channel_id=eq.${album}&user_id=eq.${scanner.id}&select=user_id`);
    assertEquals((members as unknown[]).length, 1);

    // Typed: a request the admin decides.
    const typed = await invoke("redeem-invite-code", typerToken, { code: `${code.slice(0, 3)}-${code.slice(3)}`, via: "typed" });
    assertEquals(typed.body.status, "requested", JSON.stringify(typed.body));
    const { body: requests } = await svc(
      `channel_membership_requests?channel_id=eq.${album}&user_id=eq.${typer.id}&select=direction,status`,
    );
    assertEquals(requests, [{ direction: "request", status: "pending" }]);

    // A renewed code replaces the old one.
    const renewed = await invoke("create-invite-code", adminToken, { kind: "album_member", target_id: album, renew: true });
    assertEquals(renewed.body.code === code, false);
    assertEquals((await invoke("redeem-invite-code", strangerToken, { code, via: "qr" })).status, 404);

    // Co-Admin: by QR only.
    const coCode = (await invoke("create-invite-code", adminToken, { kind: "space_co_owner", target_id: space })).body.code;
    assertEquals((await invoke("redeem-invite-code", strangerToken, { code: coCode, via: "typed" })).status, 403);
    assertEquals((await invoke("redeem-invite-code", scannerToken, { code: coCode, via: "qr" })).body.status, "joined");
    const { body: coOwners } = await svc(`space_co_owners?space_id=eq.${space}&user_id=eq.${scanner.id}&select=user_id`);
    assertEquals((coOwners as unknown[]).length, 1);

    // Sharing into the redeemer's own Space.
    const strangerSpace = await createSpace(strangerToken, "IC Stranger Space");
    spaces.push(strangerSpace);
    const shareCode = (await invoke("create-invite-code", adminToken, { kind: "album_share", target_id: album })).body.code;
    const shared = await invoke("redeem-invite-code", strangerToken, { code: shareCode, via: "qr" });
    assertEquals(shared.body.status, "joined", JSON.stringify(shared.body));
    const { body: shares } = await svc(`channel_shares?channel_id=eq.${album}&space_id=eq.${strangerSpace}&select=space_id`);
    assertEquals((shares as unknown[]).length, 1);

    // Known people: those one shares something with -- not strangers.
    const known = await asUser("rpc/known_people", typerToken, { method: "POST", body: "{}" });
    assertEquals((known.body as unknown[]).length, 0); // only a pending request so far
    const ofScanner = await asUser("rpc/known_people", scannerToken, { method: "POST", body: "{}" });
    const names = (ofScanner.body as { display_name: string }[]).map((p) => p.display_name);
    assertEquals(names.includes("IC Admin"), true);
    assertEquals(names.includes("IC Typer"), false);

    // By name: an invite with a user_id instead of an email.
    const byName = await invoke("invite-channel-member", adminToken, { channel_id: album, user_id: typer.id });
    assertEquals(byName.status === 200 || byName.status === 409, true, JSON.stringify(byName.body));
  } finally {
    for (const s of spaces) await deleteSpace(s);
    for (const u of [stranger, typer, scanner, admin]) await deleteUser(u.id);
  }
});
