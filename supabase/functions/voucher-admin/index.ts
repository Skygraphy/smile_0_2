// Voucher administration for Smile staff (2026-11-11, migrations/0102),
// used by smileapp.app/verwaltung. Every call checks voucher_admins (0103).
//
// actions:
//   list                         -> batches with counts
//   create {name, kind, frames, months, count, redeem_until, invoice_ref?, card_name?}
//                                -> the batch and its codes in plain text (only now!)
//   codes {batch_id}             -> the batch's cards (last 4, status)
//   block {batch_id} | {code_id} -> unredeemed codes stop working; redeemed ones keep running
//   unblock {batch_id} | {code_id}
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { codeHash, displayCode, newCode, newToken } from "../_shared/voucher-code.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MAX_CODES = 500;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const { data: staff } = await supabaseAdmin.from("voucher_admins").select("user_id").eq("user_id", userData.user.id).maybeSingle();
  if (!staff) return jsonResponse({ error: "not_staff" }, 403);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  switch (body.action) {
    case "list": {
      const { data: batches, error } = await supabaseAdmin
        .from("voucher_batches")
        .select("id, name, kind, frames, months, redeem_until, invoice_ref, card_name, partner_token, blocked_at, created_at")
        .order("created_at", { ascending: false });
      if (error) return jsonResponse({ error: "fetch_failed" }, 500);
      const { data: codes } = await supabaseAdmin.from("voucher_codes").select("batch_id, redeemed_at").limit(100000);
      const counts = new Map<string, { total: number; redeemed: number }>();
      for (const c of codes ?? []) {
        const e = counts.get(c.batch_id) ?? { total: 0, redeemed: 0 };
        e.total++;
        if (c.redeemed_at) e.redeemed++;
        counts.set(c.batch_id, e);
      }
      return jsonResponse({
        batches: (batches ?? []).map((b) => ({ ...b, ...(counts.get(b.id) ?? { total: 0, redeemed: 0 }) })),
      });
    }

    case "create": {
      const name = String(body.name ?? "").trim();
      const kind = String(body.kind ?? "");
      const frames = Number(body.frames);
      const months = Number(body.months);
      const count = Number(body.count);
      const redeemUntil = new Date(String(body.redeem_until ?? ""));
      if (!name || name.length > 120) return jsonResponse({ error: "invalid_name" }, 400);
      if (!["gift", "partner", "promo"].includes(kind)) return jsonResponse({ error: "invalid_kind" }, 400);
      if (!Number.isInteger(frames) || frames < 1 || frames > 100) return jsonResponse({ error: "invalid_frames" }, 400);
      if (!Number.isInteger(months) || months < 1 || months > 36) return jsonResponse({ error: "invalid_months" }, 400);
      if (!Number.isInteger(count) || count < 1 || count > MAX_CODES) return jsonResponse({ error: "invalid_count" }, 400);
      if (Number.isNaN(redeemUntil.getTime()) || redeemUntil.getTime() < Date.now()) {
        return jsonResponse({ error: "invalid_redeem_until" }, 400);
      }
      const clean = (v: unknown, max: number) => {
        const s = typeof v === "string" ? v.trim() : "";
        return s ? s.slice(0, max) : null;
      };
      const { data: batch, error } = await supabaseAdmin
        .from("voucher_batches")
        .insert({
          name,
          kind,
          frames,
          months,
          redeem_until: redeemUntil.toISOString(),
          invoice_ref: clean(body.invoice_ref, 60),
          card_name: clean(body.card_name, 80),
          partner_token: kind === "partner" ? newToken() : null,
          created_by: userData.user.id,
        })
        .select()
        .single();
      if (error || !batch) return jsonResponse({ error: "create_failed" }, 500);

      const plain = new Set<string>();
      while (plain.size < count) plain.add(newCode());
      const codes = [...plain];
      const rows = await Promise.all(codes.map(async (c) => ({
        batch_id: batch.id,
        code_hash: await codeHash(c),
        last4: c.slice(4),
      })));
      const { error: codeError } = await supabaseAdmin.from("voucher_codes").insert(rows);
      if (codeError) {
        // Practically impossible (a collision with an existing code): start over.
        await supabaseAdmin.from("voucher_batches").delete().eq("id", batch.id);
        return jsonResponse({ error: "create_failed" }, 500);
      }
      return jsonResponse({ batch, codes: codes.map(displayCode) });
    }

    case "codes": {
      const { data, error } = await supabaseAdmin
        .from("voucher_codes")
        .select("id, last4, redeemed_at, blocked_at, created_at, spaces:redeemed_space_id(name)")
        .eq("batch_id", body.batch_id)
        .order("created_at")
        .order("last4");
      if (error) return jsonResponse({ error: "fetch_failed" }, 500);
      return jsonResponse({ codes: data ?? [] });
    }

    case "block":
    case "unblock": {
      const value = body.action === "block" ? new Date().toISOString() : null;
      const table = body.code_id ? "voucher_codes" : "voucher_batches";
      const id = body.code_id ?? body.batch_id;
      if (!id) return jsonResponse({ error: "missing_fields" }, 400);
      const { error } = await supabaseAdmin.from(table).update({ blocked_at: value }).eq("id", id);
      if (error) return jsonResponse({ error: "update_failed" }, 500);
      return jsonResponse({ ok: true });
    }
  }
  return jsonResponse({ error: "unknown_action" }, 400);
});
