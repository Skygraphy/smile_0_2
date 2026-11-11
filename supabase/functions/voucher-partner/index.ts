// A partner's view of their voucher cards (2026-11-11, migrations/0102):
// smileapp.app/partner/<token>. No account -- the secret token is the key.
// Shows only which cards are redeemed and when; nothing about the families.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);
  let body: { token?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  const token = typeof body.token === "string" ? body.token.trim() : "";
  if (token.length < 16 || token.length > 64) return jsonResponse({ error: "not_found" }, 404);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const { data: batch } = await supabaseAdmin
    .from("voucher_batches")
    .select("id, name, card_name, frames, months, redeem_until, blocked_at")
    .eq("partner_token", token)
    .maybeSingle();
  if (!batch) return jsonResponse({ error: "not_found" }, 404);
  const { data: codes } = await supabaseAdmin
    .from("voucher_codes")
    .select("last4, redeemed_at, blocked_at, created_at")
    .eq("batch_id", batch.id)
    .order("created_at")
    .order("last4");
  return jsonResponse({
    name: batch.card_name ?? batch.name,
    frames: batch.frames,
    months: batch.months,
    redeem_until: batch.redeem_until,
    blocked: batch.blocked_at != null,
    cards: (codes ?? []).map((c) => ({
      last4: c.last4,
      redeemed_at: c.redeemed_at,
      blocked: c.blocked_at != null,
    })),
  });
});
