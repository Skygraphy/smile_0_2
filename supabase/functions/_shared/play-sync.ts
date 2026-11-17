// Google Play subscriptions via RevenueCat -> space_plans (2026-11-17,
// migrations/0105). Called by the revenuecat-webhook and by the app right
// after a purchase (play-subscription, action sync). Always reads the full
// subscriber from RevenueCat, so the order or repetition of webhooks does
// not matter.
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

async function rc(path: string, init?: RequestInit) {
  return await fetch(`${RC_API}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${RC_KEY}`, "Content-Type": "application/json", ...(init?.headers ?? {}) },
  });
}

async function subscriber(userId: string): Promise<Record<string, RcSubscription>> {
  const r = await rc(`/subscribers/${encodeURIComponent(userId)}`);
  if (!r.ok) throw new Error(`revenuecat ${r.status}`);
  const j = await r.json();
  return (j?.subscriber?.subscriptions ?? {}) as Record<string, RcSubscription>;
}

export type SyncResult = { synced: number; deferred: number };

/// Brings all of this person's Smile subscriptions into space_plans.
export async function syncPlaySubscriber(admin: SupabaseClient, userId: string): Promise<SyncResult> {
  if (!RC_KEY) throw new Error("REVENUECAT_SECRET_KEY missing");
  let subs = await subscriber(userId);
  let synced = 0;
  let deferred = 0;

  for (let pass = 0; pass < 2; pass++) {
    let deferredThisPass = false;
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

      const { data: existing } = await admin.from("space_plans").select("id, starts_at, deferred_at, space_id")
        .eq("external_ref", ref).maybeSingle();

      // A product moved to another Space (bought again for a different one):
      // start a fresh row there, the old one keeps its history.
      let rowId = existing?.id as string | undefined;
      if (existing && existing.space_id !== spaceId) {
        await admin.from("space_plans").update({ external_ref: `${ref}:${existing.id}` }).eq("id", existing.id);
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
        const { data: ins } = await admin.from("space_plans").insert(row).select("id").single();
        rowId = ins?.id;
      }
      synced++;

      // Bought while the Space was still covered (trial, voucher, staff):
      // Google has charged the first period now, so the second charge is
      // moved back by what was left of that cover. Once per subscription.
      const deferredAt = existing && existing.space_id === spaceId ? existing.deferred_at : null;
      if (rowId && !deferredAt && expires && expires > new Date() && !refunded) {
        const { data: cover } = await admin.from("space_plans").select("ends_at")
          .eq("space_id", spaceId).neq("source", "play").gt("ends_at", purchased.toISOString())
          .order("ends_at", { ascending: false }).limit(1).maybeSingle();
        await admin.from("space_plans").update({ deferred_at: new Date().toISOString() }).eq("id", rowId);
        const coverEnd = cover?.ends_at ? new Date(cover.ends_at as string) : null;
        const extraMs = coverEnd ? coverEnd.getTime() - purchased.getTime() : 0;
        if (extraMs > 60 * 60 * 1000) {
          const newExpiry = expires.getTime() + extraMs;
          const r = await rc(`/subscribers/${encodeURIComponent(userId)}/subscriptions/${encodeURIComponent(product)}/defer`, {
            method: "POST",
            body: JSON.stringify({ expiry_time_ms: newExpiry }),
          });
          if (r.ok) {
            deferred++;
            deferredThisPass = true;
          } else {
            console.error(`play-sync: defer failed ${r.status} ${await r.text()}`);
          }
        }
      }
    }
    // After a deferral the expiry changed at Google: read once more.
    if (!deferredThisPass) break;
    subs = await subscriber(userId);
  }
  return { synced, deferred };
}
