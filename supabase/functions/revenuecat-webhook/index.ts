// RevenueCat -> Smile (2026-11-17, migrations/0105). RevenueCat calls this
// on every purchase, renewal, cancellation, billing problem, expiry and
// product change. It only says "something changed for this person"; the
// actual state is read back from RevenueCat (play-sync), so repeated or
// out-of-order calls are harmless. Protected by a shared secret that is set
// as the Authorization header in RevenueCat's webhook settings.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/cors.ts";
import { syncPlaySubscriber } from "../_shared/play-sync.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const webhookAuth = Deno.env.get("REVENUECAT_WEBHOOK_AUTH") ?? "";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  if (!webhookAuth || req.headers.get("Authorization") !== webhookAuth) return jsonResponse({ error: "unauthorized" }, 401);

  let body: { event?: { type?: string; app_user_id?: string; original_app_user_id?: string; aliases?: string[] } };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  const ev = body.event ?? {};
  if (ev.type === "TEST") return jsonResponse({ ok: true, test: true });

  const users = new Set(
    [ev.app_user_id, ev.original_app_user_id, ...(ev.aliases ?? [])].filter((u): u is string => !!u && UUID.test(u)),
  );
  const admin = createClient(supabaseUrl, serviceRoleKey);
  try {
    for (const u of users) await syncPlaySubscriber(admin, u);
  } catch (e) {
    // 5xx makes RevenueCat retry later.
    console.error(`revenuecat-webhook ${ev.type}: ${e}`);
    return jsonResponse({ error: "sync_failed" }, 500);
  }
  return jsonResponse({ ok: true, users: users.size });
});
