// "Darf Alben anlegen" (2026-11-19, migrations/0109): the Space's managers
// let a person of the Space create albums; that person manages exactly the
// albums they made, nothing else (no other albums, no Frames); taking the
// right away ends managing them.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { accessTokenFor, asUser, createChannel, createSpace, createThrowawayUser, deleteSpace, deleteUser, ensureProfile, invoke, svc } from "./helpers.ts";

Deno.test("album creators: create and manage own albums only", async () => {
  const owner = await createThrowawayUser("acown");
  const ines = await createThrowawayUser("acines");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "AC Ernst");
    await ensureProfile(ines.id, "AC Ines");
    const { accessToken: ernst } = await accessTokenFor(owner.email);
    const { accessToken: inesToken } = await accessTokenFor(ines.email);
    space = await createSpace(ernst, "AC Space");
    const family = await createChannel(ernst, space, "AC Enkel");
    const created = await invoke("create-frame", ernst, { space_id: space, name: "AC Frame" });
    const frameId = created.body.frame_id as string;

    const newAlbum = (name: string) =>
      asUser("channels", inesToken, { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ space_id: space, name }) });
    const giveRight = () =>
      asUser("space_album_creators", ernst, { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ space_id: space, user_id: ines.id }) });

    // Not in the Space: no album, and the right can't be given yet.
    assert((await newAlbum("AC Nope")).status >= 400);
    assert((await giveRight()).status >= 400);

    // In one of its albums: the right can be given, Ines may create.
    await svc("channel_members", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ channel_id: family, user_id: ines.id }) });
    assertEquals((await giveRight()).status, 201);
    const people = await asUser("rpc/space_people", ernst, { method: "POST", body: JSON.stringify({ p_space: space }) });
    assertEquals(people.body.length, 1);
    assertEquals(people.body[0].creates_albums, true);
    const mine = await asUser("rpc/album_creator_spaces", inesToken, { method: "POST", body: "{}" });
    assertEquals(mine.body.length, 1);

    const made = await newAlbum("AC Winterurlaub");
    assertEquals(made.status, 201, JSON.stringify(made.body));
    const winter = made.body[0].id as string;
    assertEquals(made.body[0].created_by, ines.id);
    // She is in it (to send photos) and manages it.
    assertEquals((await svc(`channel_members?channel_id=eq.${winter}&user_id=eq.${ines.id}`)).body.length, 1);
    const roster = await invoke("list-channel-members", inesToken, { channel_id: winter });
    assertEquals(roster.body.caller_is_sco, true);

    const rename = (id: string, name: string) =>
      asUser(`channels?id=eq.${id}`, inesToken, { method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify({ name }) });
    assertEquals((await rename(winter, "AC Winter 2026")).body.length, 1);
    // Not Ernst's album, not the Frame.
    assertEquals((await rename(family, "AC Hacked")).body.length, 0);
    assertEquals((await invoke("assign-frame-channel", inesToken, { frame_id: frameId, channel_id: winter })).status, 403);

    // Right taken away: no new albums, no longer managing hers; still in it.
    await asUser(`space_album_creators?space_id=eq.${space}&user_id=eq.${ines.id}`, ernst, { method: "DELETE" });
    assert((await newAlbum("AC Again")).status >= 400);
    assertEquals((await rename(winter, "AC Mine?")).body.length, 0);
    assertEquals((await svc(`channel_members?channel_id=eq.${winter}&user_id=eq.${ines.id}`)).body.length, 1);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
    await deleteUser(ines.id);
  }
});
