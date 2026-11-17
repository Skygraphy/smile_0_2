// Google Play Frame plans, from the app (2026-11-17, migrations/0105).
//   action "prepare" {space_id, product}: right before buying -- checks the
//     rules and remembers which Space this product is for.
//   action "sync": right after buying -- reads RevenueCat and updates the
//     Space's plan at once (the webhook does the same a little later).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { syncPlaySubscriber } from "../_shared/play-sync.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const asUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const me = userData.user.id;

  let body: { action?: string; space_id?: string; product?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  if (body.action === "sync") {
    try {
      return jsonResponse({ ok: true, ...(await syncPlaySubscriber(admin, me)) });
    } catch (e) {
      console.error(`play-subscription sync: ${e}`);
      return jsonResponse({ error: "sync_failed" }, 502);
    }
  }

  if (body.action !== "prepare") return jsonResponse({ error: "unknown_action" }, 400);
  const spaceId = body.space_id ?? "";
  const product = body.product ?? "";
  if (!spaceId || !/^smile_frames_[0-9]+$/.test(product)) return jsonResponse({ error: "missing_fields" }, 400);

  // Only the Space's Admin or a Co-Admin.
  const [{ data: owned }, { data: co }] = await Promise.all([
    admin.from("spaces").select("id").eq("id", spaceId).eq("owner_id", me).is("deleted_at", null).maybeSingle(),
    admin.from("space_co_owners").select("space_id, spaces!inner(deleted_at)").eq("space_id", spaceId).eq("user_id", me)
      .is("spaces.deleted_at", null).maybeSingle(),
  ]);
  if (!owned && !co) return jsonResponse({ error: "not_space_manager" }, 403);

  // One payer per Space.
  const { data: payer } = await admin.rpc("space_payer", { p_space: spaceId });
  if (payer && payer !== me) {
    const { data: p } = await admin.from("profiles").select("display_name").eq("user_id", payer).maybeSingle();
    return jsonResponse({ error: "other_payer", payer_name: p?.display_name ?? null }, 409);
  }

  // Google allows each product once per account: is it already running
  // for another Space of mine?
  const { data: link } = await admin.from("play_links").select("space_id").eq("user_id", me).eq("product", product).maybeSingle();
  if (link && link.space_id !== spaceId) {
    const { data: running } = await admin.from("space_plans").select("id, will_renew, ends_at")
      .eq("external_ref", `rc:${me}:${product}`).maybeSingle();
    if (running && running.will_renew !== false && running.ends_at && new Date(running.ends_at) > new Date()) {
      const { data: s } = await admin.from("spaces").select("name").eq("id", link.space_id).maybeSingle();
      return jsonResponse({ error: "product_in_use", space_name: s?.name ?? null }, 409);
    }
  }

  const { error } = await admin.from("play_links").upsert(
    { user_id: me, product, space_id: spaceId, updated_at: new Date().toISOString() },
    { onConflict: "user_id,product" },
  );
  if (error) return jsonResponse({ error: "prepare_failed" }, 500);
  return jsonResponse({ ok: true });
});
