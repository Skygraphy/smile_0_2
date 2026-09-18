// Called by a Space Owner to create a new Frame record -- reversed order
// from the pre-reset schema (migrations/0031_architecture_reset.sql):
// the owner names the Frame first, like a Channel, and only afterwards
// does physical hardware bind to it via the pairing code generated here
// (claim-frame-pairing). A plain client insert would work for the row
// itself (frames_owner_insert's RLS already checks is_space_owner), but
// the pairing code has to be generated server-side with a real CSPRNG and
// checked for collisions, so this stays a dedicated function like every
// other code-issuing flow in this codebase.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { generatePairingCode } from "../_shared/device-secret.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CODE_TTL_SECONDS = 15 * 60;
const MAX_CODE_ATTEMPTS = 5;

interface CreateFrameRequest {
  space_id: string;
  name: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);

  const supabaseAsUser = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await supabaseAsUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const userId = userData.user.id;

  let body: CreateFrameRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  const name = body.name?.trim();
  if (!body.space_id || !name) return jsonResponse({ error: "space_id_and_name_required" }, 400);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  const { data: staffRow } = await supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle();
  const isStaff = Boolean(staffRow);
  if (!isStaff) {
    const { data: spaceRow } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", body.space_id).maybeSingle();
    if (!spaceRow || spaceRow.owner_id !== userId) return jsonResponse({ error: "not_space_owner" }, 403);
  }

  const expiresAt = new Date(Date.now() + CODE_TTL_SECONDS * 1000).toISOString();

  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const code = generatePairingCode();
    const { data: frame, error: insertError } = await supabaseAdmin
      .from("frames")
      .insert({ space_id: body.space_id, name, pairing_code: code, pairing_code_expires_at: expiresAt })
      .select()
      .single();

    if (!insertError && frame) {
      return jsonResponse({
        frame_id: frame.id,
        name: frame.name,
        pairing_code: frame.pairing_code,
        pairing_code_expires_at: frame.pairing_code_expires_at,
      });
    }
    // pairing_code has a unique constraint -- an extremely unlikely
    // collision retries with a freshly generated code rather than failing
    // outright.
    if (insertError && !insertError.message.includes("pairing_code")) {
      return jsonResponse({ error: "frame_creation_failed", detail: insertError.message }, 500);
    }
  }

  return jsonResponse({ error: "pairing_code_generation_failed" }, 500);
});
