// What an invite link is about, for the web page behind smileapp.app/i/CODE
// (2026-10-17): who invites into which album (or Space). Public -- the page
// is opened by people who don't have Smile yet; the code itself is the
// secret (six characters, valid 24 hours), and nothing beyond these two
// names is told.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const supabase = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  let code = "";
  try {
    const url = new URL(req.url);
    code = url.searchParams.get("code") ?? "";
    if (!code && req.method === "POST") code = ((await req.json()) as { code?: string }).code ?? "";
  } catch {
    // fall through with an empty code
  }
  code = code.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (!/^[A-HJ-KM-NP-Z2-9]{6}$/.test(code)) return jsonResponse({ status: "invalid" });

  const { data: invite } = await supabase
    .from("invite_codes")
    .select("kind, target_id, created_by, expires_at, revoked_at")
    .eq("code", code)
    .maybeSingle();
  if (!invite || invite.revoked_at) return jsonResponse({ status: "invalid" });
  if (new Date(invite.expires_at).getTime() < Date.now()) return jsonResponse({ status: "expired" });

  const [{ data: profile }, target] = await Promise.all([
    supabase.from("profiles").select("display_name").eq("user_id", invite.created_by).maybeSingle(),
    invite.kind === "space_co_owner"
      ? supabase.from("spaces").select("name").eq("id", invite.target_id).maybeSingle()
      : supabase.from("channels").select("name").eq("id", invite.target_id).maybeSingle(),
  ]);
  return jsonResponse({
    status: "ok",
    kind: invite.kind,
    inviter: profile?.display_name ?? null,
    target: target.data?.name ?? null,
  });
});
