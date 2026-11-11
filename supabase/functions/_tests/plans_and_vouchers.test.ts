// Frame subscriptions and voucher codes (2026-11-11, migrations/0102):
// trial from the first paired Frame, a Frame without cover gets nothing
// new, staff create codes, a Space manager redeems each code once, wrong
// codes are limited, partners see only redeemed/open, storage and video
// length follow the plan, extra Frames beyond the plan get nothing new.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  accessTokenFor,
  createChannel,
  createSpace,
  createThrowawayUser,
  deleteSpace,
  deleteUser,
  ensureProfile,
  invoke,
  svc,
} from "./helpers.ts";

const DAY = 24 * 3600 * 1000;

Deno.test("trial, lapse, voucher redeem once, limits, partner view, extra Frames", async () => {
  const owner = await createThrowawayUser("pvown");
  const other = await createThrowawayUser("pvoth");
  let space: string | undefined;
  const batchIds: string[] = [];
  try {
    await ensureProfile(owner.id, "PV Owner");
    await ensureProfile(other.id, "PV Other");
    const { accessToken } = await accessTokenFor(owner.email);
    const { accessToken: otherToken } = await accessTokenFor(other.email);
    space = await createSpace(accessToken, "PV Space");
    const album = await createChannel(accessToken, space, "PV Album");

    const spacePlan = async () => {
      const r = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/space_plan`, {
        method: "POST",
        headers: {
          apikey: Deno.env.get("SUPABASE_ANON_KEY")!,
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ p_space: space }),
      });
      return await r.json();
    };

    // No Frame yet: free, no trial.
    let p = await spacePlan();
    assertEquals(p.status, "none");
    assertEquals(p.trial_used, false);
    assertEquals(p.video_seconds, 120);

    // Pairing the first Frame starts the 2-month trial.
    const created = await invoke("create-frame", accessToken, { space_id: space, name: "PV Frame 1" });
    const frame1 = created.body.frame_id as string;
    const claim = await invoke("claim-frame-pairing", "anon", { code: created.body.pairing_code });
    const frameToken = claim.body.access_token as string;
    assertEquals((await invoke("assign-frame-channel", accessToken, { frame_id: frame1, channel_id: album })).status, 200);
    p = await spacePlan();
    assertEquals(p.status, "trial");
    assert(new Date(p.ends_at).getTime() > Date.now() + 55 * DAY);
    assertEquals(p.covered_frames, [frame1]);

    const addMedia = async (createdAt: Date) => {
      const id = crypto.randomUUID();
      const { status } = await svc("media_items", {
        method: "POST",
        headers: { Prefer: "return=minimal" },
        body: JSON.stringify({
          id,
          channel_id: album,
          sender_id: owner.id,
          media_type: "photo",
          storage_path_original: `${album}/${id}.jpg`,
          storage_path_display: `${album}/${id}.jpg`,
          mime_type: "image/jpeg",
          file_size_bytes: 1000,
          processing_status: "ready",
          created_at: createdAt.toISOString(),
        }),
      });
      assertEquals(status, 201);
      return id;
    };
    const frameSees = async (token: string) =>
      ((await invoke("get-media-batch", "anon", { access_token: token, channel_id: album })).body.items ?? []).map((
        i: { media_item_id: string },
      ) => i.media_item_id);

    const old = await addMedia(new Date(Date.now() - 10 * DAY));
    assertEquals(await frameSees(frameToken), [old]);

    // Trial over (moved into the past): the Frame keeps what came before
    // the end, gets nothing newer.
    await svc(`space_plans?space_id=eq.${space}`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ starts_at: new Date(Date.now() - 70 * DAY).toISOString(), ends_at: new Date(Date.now() - 5 * DAY).toISOString() }),
    });
    const fresh = await addMedia(new Date(Date.now() - 1 * DAY));
    p = await spacePlan();
    assertEquals(p.status, "none");
    assertEquals(p.trial_used, true);
    assertEquals(await frameSees(frameToken), [old]);

    // Only staff may create codes.
    assertEquals((await invoke("voucher-admin", accessToken, { action: "list" })).status, 403);
    await svc("staff_members", { method: "POST", body: JSON.stringify({ user_id: owner.id, role: "ops_admin" }) });
    const until = new Date(Date.now() + 365 * DAY).toISOString();
    const made = await invoke("voucher-admin", accessToken, {
      action: "create",
      name: "PV Partner",
      kind: "partner",
      frames: 1,
      months: 12,
      count: 3,
      redeem_until: until,
      card_name: "PV Heim",
    });
    assertEquals(made.status, 200);
    batchIds.push(made.body.batch.id);
    const codes = made.body.codes as string[];
    assertEquals(codes.length, 3);
    assert(/^SMILE-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{4}$/.test(codes[0]));
    // Only the HMAC is stored.
    const { body: stored } = await svc(`voucher_codes?batch_id=eq.${made.body.batch.id}&select=code_hash,last4`);
    assert(!(stored as { code_hash: string }[]).some((r) => codes.some((c) => r.code_hash.includes(c.replace(/\W/g, "").slice(5)))));

    // Not a manager of the Space: refused.
    const notMine = await invoke("redeem-voucher", otherToken, { code: codes[0], space_id: space });
    assertEquals(notMine.body.error, "not_space_manager");

    // The manager redeems it (lower case, without dashes works too).
    const typed = codes[0].replace(/-/g, "").toLowerCase();
    const ok = await invoke("redeem-voucher", accessToken, { code: typed, space_id: space });
    assertEquals(ok.status, 200);
    assertEquals(ok.body.frames, 1);
    assertEquals(ok.body.from, "PV Heim");
    p = await spacePlan();
    assertEquals(p.status, "active");
    assertEquals(p.source, "voucher");
    assertEquals(p.video_seconds, 300);
    assertEquals(Number(p.storage_bytes), 25 * 1024 ** 3);
    assertEquals((await frameSees(frameToken)).sort(), [old, fresh].sort());

    // Only once.
    const again = await invoke("redeem-voucher", accessToken, { code: codes[0], space_id: space });
    assertEquals(again.body.error, "already_used");

    // A second code goes after the first one (back to back).
    const second = await invoke("redeem-voucher", accessToken, { code: codes[1], space_id: space });
    assertEquals(second.status, 200);
    assertEquals(new Date(second.body.starts_at).getTime(), new Date(ok.body.ends_at).getTime());

    // Partner sees 2 of 3 redeemed, nothing about the Space.
    const partner = await invoke("voucher-partner", "anon", { token: made.body.batch.partner_token });
    assertEquals(partner.status, 200);
    assertEquals(partner.body.cards.filter((c: { redeemed_at: string | null }) => c.redeemed_at).length, 2);
    assert(!JSON.stringify(partner.body).includes("PV Space"));

    // Blocking the batch: the open card stops working, redeemed time stays.
    assertEquals((await invoke("voucher-admin", accessToken, { action: "block", batch_id: made.body.batch.id })).status, 200);
    assertEquals((await invoke("redeem-voucher", accessToken, { code: codes[2], space_id: space })).body.error, "blocked");
    assertEquals((await spacePlan()).status, "active");

    // Storage and video length follow the plan (1 Frame: 25 GB, 5 min).
    const tooBig = await invoke("create-upload", accessToken, {
      channel_id: album,
      media_type: "video",
      mime_type: "video/mp4",
      file_extension: "mp4",
      file_size_bytes: 26 * 1024 ** 3,
    });
    assertEquals(tooBig.body.error, "space_full");
    const tooLong = await invoke("create-upload", accessToken, {
      channel_id: album,
      media_type: "video",
      mime_type: "video/mp4",
      file_extension: "mp4",
      file_size_bytes: 1000,
      duration_ms: 400000,
    });
    assertEquals(tooLong.body.error, "video_too_long");

    // A second Frame is beyond the 1-Frame plan: it gets nothing newer
    // than its pairing; the first Frame stays covered.
    const created2 = await invoke("create-frame", accessToken, { space_id: space, name: "PV Frame 2" });
    const claim2 = await invoke("claim-frame-pairing", "anon", { code: created2.body.pairing_code });
    assertEquals((await invoke("assign-frame-channel", accessToken, { frame_id: created2.body.frame_id, channel_id: album })).status, 200);
    const later = await addMedia(new Date(Date.now() + 60 * 1000));
    assertEquals((await frameSees(claim2.body.access_token)).sort(), [old, fresh].sort());
    assert((await frameSees(frameToken)).includes(later));
    assertEquals((await spacePlan()).covered_frames, [frame1]);

    // Wrong codes: at most 5 per hour.
    for (let i = 0; i < 5; i++) {
      const wrong = await invoke("redeem-voucher", accessToken, { code: "SMILE-2222-2222", space_id: space });
      assertEquals(wrong.body.error, "not_found");
    }
    const limited = await invoke("redeem-voucher", accessToken, { code: codes[2], space_id: space });
    assertEquals(limited.status, 429);
  } finally {
    for (const id of batchIds) await svc(`voucher_batches?id=eq.${id}`, { method: "DELETE" });
    await svc(`staff_members?user_id=eq.${owner.id}`, { method: "DELETE" });
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
    await deleteUser(other.id);
  }
});
