// Google Play subscriptions via RevenueCat -> space_plans (2026-11-17,
// migrations/0105, 0106). Called by the revenuecat-webhook and by the app
// right after a purchase (play-subscription, action sync). Always reads the
// full subscriber from RevenueCat, so the order or repetition of webhooks
// does not matter.
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const RC_KEY = Deno.env.get("REVENUECAT_SECRET_KEY") ?? "";
const RC_API = "https://api.revenuecat.com/v1";
const PRODUCT = /^smile_frames_(\d+)$/;

type RcSubscription = {
  expires_date: string | null;
  purchase_date: string;
  original_purchase_date?: string;
  unsubscribe_detected_at?: string | null;
  billing_issues_detected_at?: string | null;
  refunded_at?: string | null;
  product_plan_identifier?: string | null;
  store?: string;
};

async function subscriber(userId: string): Promise<Record<string, RcSubscription>> {
  const r = await fetch(`${RC_API}/subscribers/${encodeURIComponent(userId)}`, {
    headers: { Authorization: `Bearer ${RC_KEY}`, "Content-Type": "application/json" },
  });
  if (!r.ok) throw new Error(`revenuecat ${r.status}`);
  const j = await r.json();
  return (j?.subscriber?.subscriptions ?? {}) as Record<string, RcSubscription>;
}

export type SyncResult = { synced: number; parked: number; unparked: number };

/// Brings all of this person's Smile subscriptions into space_plans, then
/// sets voucher time aside / gives it back for every Space touched
/// (reconcile_play_cover, migrations/0106). Google is never deferred: a
/// deferred subscription cannot switch tiers any more (live-tested
/// 2026-11-18).
export async function syncPlaySubscriber(admin: SupabaseClient, userId: string): Promise<SyncResult> {
  if (!RC_KEY) throw new Error("REVENUECAT_SECRET_KEY missing");
  const subs = await subscriber(userId);
  let synced = 0;
  const spaces = new Set<string>();

  for (const [key, s] of Object.entries(subs)) {
    const product = key.split(":")[0];
    const m = PRODUCT.exec(product);
    if (!m || (s.store !== undefined && s.store !== "play_store")) continue;
    const frames = parseInt(m[1], 10);

    const { data: link } = await admin.from("play_links").select("space_id")
      .eq("user_id", userId).eq("product", product).maybeSingle();
    if (!link) {
      console.warn(`play-sync: no space for ${userId} ${product}`);
      continue;
    }
    const spaceId = link.space_id as string;
    const ref = `rc:${userId}:${product}`;
    const purchased = new Date(s.purchase_date);
    const expires = s.expires_date ? new Date(s.expires_date) : null;
    const refunded = s.refunded_at ? new Date(s.refunded_at) : null;
    const endsAt = refunded && (!expires || refunded < expires) ? refunded : expires;

    const { data: existing } = await admin.from("space_plans").select("id, starts_at, space_id")
      .eq("external_ref", ref).maybeSingle();

    // A product moved to another Space (bought again for a different one):
    // start a fresh row there, the old one keeps its history.
    let rowId = existing?.id as string | undefined;
    if (existing && existing.space_id !== spaceId) {
      await admin.from("space_plans").update({ external_ref: `${ref}:${existing.id}` }).eq("id", existing.id);
      spaces.add(existing.space_id as string);
      rowId = undefined;
    }

    const startsAt = rowId ? existing!.starts_at : purchased.toISOString();
    const row = {
      space_id: spaceId,
      source: "play",
      frames,
      starts_at: startsAt,
      ends_at: endsAt && endsAt > new Date(startsAt) ? endsAt.toISOString() : new Date(new Date(startsAt).getTime() + 1000).toISOString(),
      external_ref: ref,
      payer_id: userId,
      // Always 'smile_frames_3:monthly' (RevenueCat keys by product, the
      // base plan comes separately), the app compares against this.
      store_product: key.includes(":") ? key : s.product_plan_identifier ? `${product}:${s.product_plan_identifier}` : key,
      will_renew: !s.unsubscribe_detected_at && !refunded,
      billing_issue: !!s.billing_issues_detected_at,
    };
    if (rowId) {
      await admin.from("space_plans").update(row).eq("id", rowId);
    } else {
      await admin.from("space_plans").insert(row);
    }
    spaces.add(spaceId);
    synced++;
  }

  let parked = 0;
  let unparked = 0;
  for (const spaceId of spaces) {
    const { data, error } = await admin.rpc("reconcile_play_cover", { p_space: spaceId });
    if (error) {
      console.error(`play-sync: reconcile ${spaceId} failed: ${error.message}`);
      continue;
    }
    parked += Number(data?.parked ?? 0);
    unparked += Number(data?.unparked ?? 0);
  }
  return { synced, parked, unparked };
}
