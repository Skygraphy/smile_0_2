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
