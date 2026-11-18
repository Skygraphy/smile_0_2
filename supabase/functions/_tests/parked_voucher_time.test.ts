// Voucher time set aside during a Google Play subscription (2026-11-18,
// migrations/0106): buying parks the rest of a running voucher and ends
// the trial, a voucher redeemed while paying is parked at once, a
// cancelled subscription gets the parked time right after its end, taking
// the cancellation back parks it again. RevenueCat itself is not called:
// the Play row is written the way play-sync writes it.
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { accessTokenFor, createSpace, createThrowawayUser, deleteSpace, deleteUser, ensureProfile, invoke, svc } from "./helpers.ts";

const DAY = 24 * 3600 * 1000;
const iso = (ms: number) => new Date(ms).toISOString();

Deno.test("voucher time is parked while a Play subscription renews and comes back after it", async () => {
  const owner = await createThrowawayUser("pkown");
  let space: string | undefined;
  const batchIds: string[] = [];
  try {
    await ensureProfile(owner.id, "PK Owner");
    const { accessToken } = await accessTokenFor(owner.email);
    space = await createSpace(accessToken, "PK Space");

    const spacePlan = async () => {
      const r = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/space_plan`, {
        method: "POST",
        headers: { apikey: Deno.env.get("SUPABASE_ANON_KEY")!, Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({ p_space: space }),
      });
      return await r.json();
    };
    const reconcile = async () => (await svc("rpc/reconcile_play_cover", { method: "POST", body: JSON.stringify({ p_space: space }) })).body;
    const rows = async (source: string) =>
      (await svc(`space_plans?space_id=eq.${space}&source=eq.${source}&select=id,frames,starts_at,ends_at&order=starts_at`)).body as {
        id: string;
        frames: number;
        starts_at: string;
        ends_at: string;
      }[];
    const parked = async () => (await svc(`space_plans_parked?space_id=eq.${space}&select=frames,duration`)).body as { frames: number; duration: string }[];

    // A trial and a running voucher (started 10 days ago, 90 days left).
    const now = Date.now();
    await svc("space_plans", {
      method: "POST",
      body: JSON.stringify([
        { space_id: space, source: "trial", frames: 10000, starts_at: iso(now - 20 * DAY), ends_at: iso(now + 40 * DAY) },
        { space_id: space, source: "voucher", frames: 1, starts_at: iso(now - 10 * DAY), ends_at: iso(now + 90 * DAY) },
      ]),
    });
    let p = await spacePlan();
    assertEquals(p.cover_source, "voucher");
    assertEquals(p.parked_days, null);

    // Nothing to do without a subscription.
    assertEquals(await reconcile(), { parked: 0, unparked: 0 });

    // A renewing Play subscription (as play-sync writes it): voucher parked, trial ended.
    const ref = `rc:${owner.id}:smile_frames_3`;
    await svc("space_plans", {
      method: "POST",
      body: JSON.stringify({
        space_id: space, source: "play", frames: 3, starts_at: iso(now - 60 * 1000), ends_at: iso(now + 30 * DAY),
        external_ref: ref, payer_id: owner.id, store_product: "smile_frames_3:monthly", will_renew: true,
      }),
    });
    assertEquals(await reconcile(), { parked: 1, unparked: 0 });
    const pk = await parked();
    assertEquals(pk.length, 1);
    assertEquals(pk[0].frames, 1);
    assert(new Date((await rows("voucher"))[0].ends_at).getTime() <= Date.now());
    assert(new Date((await rows("trial"))[0].ends_at).getTime() <= Date.now());
    p = await spacePlan();
    assertEquals(p.status, "active");
    assertEquals(p.source, "play");
    assertEquals(p.frames, 3);
    assert(p.parked_days >= 89 && p.parked_days <= 90, `parked_days ${p.parked_days}`);
    assertEquals(p.parked_frames, 1);

    // Idempotent: a second sync parks nothing more.
    assertEquals(await reconcile(), { parked: 0, unparked: 0 });

    // A voucher redeemed while paying is parked at once.
    await svc("voucher_admins", { method: "POST", body: JSON.stringify({ user_id: owner.id }) });
    const made = await invoke("voucher-admin", accessToken, {
      action: "create", name: "PK Test", kind: "partner", frames: 1, months: 3, count: 1,
      redeem_until: iso(now + 30 * DAY),
    });
    assertEquals(made.status, 200);
    batchIds.push(made.body.batch.id);
    const redeemed = await invoke("redeem-voucher", accessToken, { code: made.body.codes[0], space_id: space });
    assertEquals(redeemed.status, 200);
    assertEquals(redeemed.body.parked, true);
    assertEquals(redeemed.body.months, 3);
    assertEquals((await parked()).length, 2);
    assertEquals((await rows("voucher")).length, 1);

    // Cancelled: the parked time follows right after the subscription's end.
    await svc(`space_plans?external_ref=eq.${ref}`, { method: "PATCH", body: JSON.stringify({ will_renew: false }) });
    assertEquals(await reconcile(), { parked: 0, unparked: 2 });
    assertEquals((await parked()).length, 0);
    const after = (await rows("voucher")).slice(1);
    assertEquals(after.length, 2);
    const playEnd = new Date((await rows("play"))[0].ends_at).getTime();
    assertEquals(new Date(after[0].starts_at).getTime(), playEnd);
    assertEquals(new Date(after[1].starts_at).getTime(), new Date(after[0].ends_at).getTime());
    p = await spacePlan();
    assertEquals(p.play_renews, false);
    assertEquals(p.after_play_frames, 1);
    assertEquals(new Date(p.after_play_ends_at).getTime(), new Date(after[1].ends_at).getTime());
    // The Space's plan now runs to the end of the last voucher.
    assertEquals(new Date(p.ends_at).getTime(), new Date(after[1].ends_at).getTime());

    // Cancellation taken back: parked again, nothing lost.
    await svc(`space_plans?external_ref=eq.${ref}`, { method: "PATCH", body: JSON.stringify({ will_renew: true }) });
    assertEquals(await reconcile(), { parked: 2, unparked: 0 });
    assertEquals((await rows("voucher")).length, 1);
    p = await spacePlan();
    assert(p.parked_days >= 180 && p.parked_days <= 183, `parked_days ${p.parked_days}`);

    // The subscription has ended (expired or refunded): the time comes back from now.
    await svc(`space_plans?external_ref=eq.${ref}`, { method: "PATCH", body: JSON.stringify({ ends_at: iso(Date.now() - 1000) }) });
    assertEquals(await reconcile(), { parked: 0, unparked: 2 });
    p = await spacePlan();
    assertEquals(p.status, "active");
    assertEquals(p.source, "voucher");
    assertEquals(p.frames, 1);
  } finally {
    if (space) await svc(`space_plans_parked?space_id=eq.${space}`, { method: "DELETE" });
    if (space) await svc(`space_plans?space_id=eq.${space}`, { method: "DELETE" });
    for (const id of batchIds) await svc(`voucher_batches?id=eq.${id}`, { method: "DELETE" });
    await svc(`voucher_admins?user_id=eq.${owner.id}`, { method: "DELETE" });
    if (space) await deleteSpace(space);
    await deleteUser(owner.id);
  }
});
