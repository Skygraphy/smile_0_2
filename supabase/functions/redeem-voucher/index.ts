// Redeems a voucher code for a Space (2026-11-11, migrations/0102). Only
// the Space's Admin or a Co-Admin; each code once; at most 5 wrong codes
// per person and hour. The database does the checking and booking in one
// locked step (redeem_voucher), this only turns the typed code into its HMAC.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { codeHash, normalizeCode } from "../_shared/voucher-code.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);

  let body: { code?: string; space_id?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  if (!body.code || !body.space_id) return jsonResponse({ error: "missing_fields" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const code = normalizeCode(body.code);
  // A malformed code counts as a wrong try as well: hash something that
  // can never exist, so the database books the attempt.
  const hash = await codeHash(code ?? `invalid:${crypto.randomUUID()}`);
  const { data, error } = await supabaseAdmin.rpc("redeem_voucher", {
    p_hash: hash,
    p_space: body.space_id,
    p_user: userData.user.id,
  });
  if (error) return jsonResponse({ error: "redeem_failed" }, 500);
  if (data?.error) return jsonResponse({ error: data.error }, data.error === "rate_limited" ? 429 : 400);
  return jsonResponse(data);
});
