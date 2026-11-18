// Live look at a Frame's screen (2026-11-18, migrations/0107): only the
// Space's Admin / Co-Admins, the Frame sends while someone asks, the
// picture comes back as a short URL, nothing is kept after stop.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { accessTokenFor, createChannel, createSpace, createThrowawayUser, deleteSpace, deleteUser, ensureProfile, invoke, svc } from "./helpers.ts";

// A 1x1 PNG.
const PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==";

Deno.test("only managers look live, the Frame sends while asked, nothing stays", async () => {
  const owner = await createThrowawayUser("flown");
  const other = await createThrowawayUser("floth");
  let space: string | undefined;
  try {
    await ensureProfile(owner.id, "FL Owner");
    await ensureProfile(other.id, "FL Other");
    const { accessToken } = await accessTokenFor(owner.email);
    const { accessToken: otherToken } = await accessTokenFor(other.email);
    space = await createSpace(accessToken, "FL Space");
    const album = await createChannel(accessToken, space, "FL Album");
    const created = await invoke("create-frame", accessToken, { space_id: space, name: "FL Frame" });
    const frameId = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "anon", { code: created.body.pairing_code });
    const frameToken = claim.body.access_token as string;
    await invoke("assign-frame-channel", accessToken, { frame_id: frameId, channel_id: album });

    const upload = () => invoke("frame-live", "anon", { action: "upload", access_token: frameToken, image: PNG, state: { state: "playing", album: "FL Album" } });

    // Nobody looks: the Frame is told to stop.
    assertEquals((await upload()).body.go_on, false);

    // Someone who doesn't manage the Space: refused.
    assertEquals((await invoke("frame-live", otherToken, { action: "start", frame_id: frameId })).status, 403);

    // The Admin starts; the Frame sends and hears who looks.
    const start = await invoke("frame-live", accessToken, { action: "start", frame_id: frameId });
    assertEquals(start.body.ok, true);
    const sent = await upload();
    assertEquals(sent.body.go_on, true);
    assertEquals(sent.body.watcher, "FL Owner");

    const got = await invoke("frame-live", accessToken, { action: "get", frame_id: frameId });
    assert(typeof got.body.image_url === "string");
    assertEquals(got.body.state.state, "playing");
    const img = await fetch(got.body.image_url);
    assertEquals(img.status, 200);
    assertEquals((await img.arrayBuffer()).byteLength > 0, true);

    // Stop: row and picture gone, the Frame stops.
    await invoke("frame-live", accessToken, { action: "stop", frame_id: frameId });
    assertEquals((await svc(`frame_live?frame_id=eq.${frameId}`)).body.length, 0);
    // The file itself is gone (a signed URL may still be answered from cache).
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const direct = await fetch(`${Deno.env.get("SUPABASE_URL")}/storage/v1/object/frame-live/${frameId}.png`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
    });
    await direct.body?.cancel();
    assertEquals(direct.status >= 400, true);
    assertEquals((await upload()).body.go_on, false);
  } finally {
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
    await deleteUser(other.id);
  }
});
