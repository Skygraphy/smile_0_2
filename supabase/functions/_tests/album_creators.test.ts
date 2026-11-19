// "Darf Alben anlegen" (2026-11-19, migrations/0109 + 0110): only by an
// invitation of its own that the person accepts (by name or QR) -- being in
// an album of the Space never leads to it. With it, the person creates
// albums and manages exactly those (no other albums, no Frames); taking it
// away or giving it back ends that.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { accessTokenFor, asUser, createChannel, createSpace, createThrowawayUser, deleteSpace, deleteUser, ensureProfile, invoke, svc } from "./helpers.ts";

Deno.test("album creators: invited, accepted, own albums only", async () => {
  const owner = await createThrowawayUser("acown");
  const ines = await createThrowawayUser("acines");
  const julian = await createThrowawayUser("acjul");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "AC Ernst");
    await ensureProfile(ines.id, "AC Ines");
    await ensureProfile(julian.id, "AC Julian");
    const { accessToken: ernst } = await accessTokenFor(owner.email);
    const { accessToken: inesToken } = await accessTokenFor(ines.email);
    const { accessToken: julianToken } = await accessTokenFor(julian.email);
    space = await createSpace(ernst, "AC Space");
    const family = await createChannel(ernst, space, "AC Enkel");
    const created = await invoke("create-frame", ernst, { space_id: space, name: "AC Frame" });
    const frameId = created.body.frame_id as string;

    const newAlbum = (token: string, name: string) =>
      asUser("channels", token, { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ space_id: space, name }) });

    // In an album of the Space: still no right, and a manager can't just give it.
    await svc("channel_members", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ channel_id: family, user_id: julian.id }) });
    assert((await newAlbum(julianToken, "AC Nope")).status >= 400);
    const direct = await asUser("space_album_creators", ernst, {
      method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ space_id: space, user_id: julian.id }),
    });
    assert(direct.status >= 400);

    // By name: Ines (in no album at all) is invited and accepts.
    const invited = await invoke("invite-album-creator", ernst, { space_id: space, user_id: ines.id });
    assertEquals(invited.body.status, "invited", JSON.stringify(invited.body));
    assert((await newAlbum(inesToken, "AC Too early")).status >= 400);
    const mine = await asUser("rpc/my_album_creator_invites", inesToken, { method: "POST", body: "{}" });
    assertEquals(mine.body.length, 1);
    assertEquals(mine.body[0].space_name, "AC Space");
    let roster = await asUser("rpc/album_creator_roster", ernst, { method: "POST", body: JSON.stringify({ p_space: space }) });
    assertEquals(roster.body[0].status, "pending");
    const decided = await asUser(`space_album_creator_invites?id=eq.${invited.body.invite_id}`, inesToken, {
      method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ status: "accepted" }),
    });
    assertEquals(decided.body.length, 1);
    roster = await asUser("rpc/album_creator_roster", ernst, { method: "POST", body: JSON.stringify({ p_space: space }) });
    assertEquals(roster.body[0].status, "active");

    // Ines creates and manages her album -- not Ernst's, not the Frame.
    const made = await newAlbum(inesToken, "AC Winterurlaub");
    assertEquals(made.status, 201, JSON.stringify(made.body));
    const winter = made.body[0].id as string;
    assertEquals((await svc(`channel_members?channel_id=eq.${winter}&user_id=eq.${ines.id}`)).body.length, 1);
    assertEquals((await invoke("list-channel-members", inesToken, { channel_id: winter })).body.caller_is_sco, true);
    const rename = (id: string, name: string) =>
      asUser(`channels?id=eq.${id}`, inesToken, { method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ name }) });
    assertEquals((await rename(winter, "AC Winter 2026")).body.length, 1);
    assertEquals((await rename(family, "AC Hacked")).body.length, 0);
    assertEquals((await invoke("assign-frame-channel", inesToken, { frame_id: frameId, channel_id: winter })).status, 403);

    // By QR: Julian scans and has it at once.
    const code = await invoke("create-invite-code", ernst, { kind: "album_creator", target_id: space });
    assertEquals(code.status, 200, JSON.stringify(code.body));
    const scanned = await invoke("redeem-invite-code", julianToken, { code: `smile:invite:${code.body.code}`, via: "qr" });
    assertEquals(scanned.body.status, "joined", JSON.stringify(scanned.body));
    assertEquals((await newAlbum(julianToken, "AC Julian Album")).status, 201);

    // Ines gives it back herself: no new albums, hers no longer managed.
    await asUser(`space_album_creators?space_id=eq.${space}&user_id=eq.${ines.id}`, inesToken, { method: "DELETE" });
    assert((await newAlbum(inesToken, "AC Again")).status >= 400);
    assertEquals((await rename(winter, "AC Mine?")).body.length, 0);
    assertEquals((await svc(`channel_members?channel_id=eq.${winter}&user_id=eq.${ines.id}`)).body.length, 1);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
    await deleteUser(ines.id);
    await deleteUser(julian.id);
  }
});

// Who an album creator may bring in (migrations/0111): people already in
// the Space directly; anyone else only as a proposal the managers decide;
// her QR code lets strangers only ask; no sharing with other Spaces.
Deno.test("album creators: family directly, strangers only through the managers", async () => {
  const owner = await createThrowawayUser("acown2");
  const ines = await createThrowawayUser("acines2");
  const julian = await createThrowawayUser("acjul2");
  const peter = await createThrowawayUser("acpet2");
  const paul = await createThrowawayUser("acpau2");
  let space: string | undefined;
  try {
    for (const [u, n] of [[owner, "AC2 Ernst"], [ines, "AC2 Ines"], [julian, "AC2 Julian"], [peter, "AC2 Peter"], [paul, "AC2 Paul"]] as const) {
      await ensureProfile(u.id, n);
    }
    const { accessToken: ernst } = await accessTokenFor(owner.email);
    const { accessToken: inesToken } = await accessTokenFor(ines.email);
    const { accessToken: paulToken } = await accessTokenFor(paul.email);
    space = await createSpace(ernst, "AC2 Space");
    const family = await createChannel(ernst, space, "AC2 Enkel");
    await svc("channel_members", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ channel_id: family, user_id: julian.id }) });
    const invited = await invoke("invite-album-creator", ernst, { space_id: space, user_id: ines.id });
    await asUser(`space_album_creator_invites?id=eq.${invited.body.invite_id}`, inesToken, {
      method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ status: "accepted" }),
    });
    const made = await asUser("channels", inesToken, {
      method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ space_id: space, name: "AC2 Winter" }),
    });
    const winter = made.body[0].id as string;
    const pendingFor = async (userId: string) =>
      (await svc(`channel_membership_requests?channel_id=eq.${winter}&user_id=eq.${userId}&status=eq.pending&select=direction`)).body as { direction: string }[];

    // Julian (in Enkel) directly; Peter (stranger) only proposed.
    assertEquals((await invoke("invite-channel-member", inesToken, { channel_id: winter, user_id: julian.id })).body.status, "invited");
    assertEquals((await invoke("invite-channel-member", inesToken, { channel_id: winter, user_id: peter.id })).body.status, "proposed");
    assertEquals((await pendingFor(peter.id)).length, 0);
    // Not around it through the database either.
    const direct = await asUser("channel_membership_requests", inesToken, {
      method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ channel_id: winter, user_id: peter.id, direction: "invite" }),
    });
    assert(direct.status >= 400);

    // Ernst sees and approves the proposal: now Peter is invited.
    const proposals = await asUser("rpc/my_invite_proposals", ernst, { method: "POST", body: "{}" });
    assertEquals(proposals.body.length, 1);
    assertEquals(proposals.body[0].invitee_name, "AC2 Peter");
    const approved = await asUser(`channel_invite_proposals?id=eq.${proposals.body[0].id}`, ernst, {
      method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ status: "approved" }),
    });
    assertEquals(approved.body.length, 1, JSON.stringify(approved.body));
    assertEquals((await pendingFor(peter.id))[0]?.direction, "invite");

    // Ines' QR code: a stranger (Paul) only asks -- and Ines can't let him in, Ernst can.
    const code = await invoke("create-invite-code", inesToken, { kind: "album_member", target_id: winter });
    assertEquals(code.status, 200, JSON.stringify(code.body));
    const scanned = await invoke("redeem-invite-code", paulToken, { code: `smile:invite:${code.body.code}`, via: "qr" });
    assertEquals(scanned.body.status, "requested", JSON.stringify(scanned.body));
    const request = (await svc(`channel_membership_requests?channel_id=eq.${winter}&user_id=eq.${paul.id}&status=eq.pending&select=id`)).body[0].id;
    const byInes = await asUser(`channel_membership_requests?id=eq.${request}`, inesToken, {
      method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ status: "accepted" }),
    });
    assertEquals(byInes.body.length, 0);
    const byErnst = await asUser(`channel_membership_requests?id=eq.${request}`, ernst, {
      method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ status: "accepted" }),
    });
    assertEquals(byErnst.body.length, 1);

    // Sharing with another Space: not for Ines.
    assertEquals((await invoke("create-invite-code", inesToken, { kind: "album_share", target_id: winter })).status, 403);
  } finally {
    if (space) await deleteSpace(space);
    for (const u of [owner, ines, julian, peter, paul]) await deleteUser(u.id);
  }
});
