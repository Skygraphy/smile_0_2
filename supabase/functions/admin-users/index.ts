// Verwaltung on smileapp.app (migrations/0114, 2026-11-21): who works there.
//
//   me      anyone signed in: the caller's role and rights, or 403 (the page
//           shows "Kein Zugang").
//   list    Super-Admin: everyone in the Verwaltung.
//   add     Super-Admin: {email, can_feedback, can_vouchers} -- an existing
//           Smile account becomes an Admin.
//   update  Super-Admin: {user_id, can_feedback, can_vouchers}.
//   remove  Super-Admin: {user_id}.
//
// The Super-Admin itself is entered in the database directly and can never
// be given, changed or removed here.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { adminAccess } from "../_shared/admin-access.ts";
import { findUserIdByEmail } from "../_shared/find-user.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface Body {
  action?: string;
  email?: string;
  user_id?: string;
  can_feedback?: boolean;
  can_vouchers?: boolean;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return jsonResponse({ error: "missing_authorization" }, 401);
  const asUser = createClient(supabaseUrl, serviceRoleKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await asUser.auth.getUser();
  if (userError || !userData.user) return jsonResponse({ error: "invalid_session" }, 401);
  const me = userData.user;

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const access = await adminAccess(admin, me.id);
  if (!access) return jsonResponse({ error: "not_admin" }, 403);

  if (body.action === "me") {
    const { data: p } = await admin.from("profiles").select("display_name").eq("user_id", me.id).maybeSingle();
    return jsonResponse({ ...access, name: p?.display_name ?? null, email: me.email ?? null });
  }

  if (!access.manageAdmins) return jsonResponse({ error: "forbidden" }, 403);

  switch (body.action) {
    case "list": {
      const { data: rows, error } = await admin
        .from("admin_users")
        .select("user_id, role, can_feedback, can_vouchers, created_at")
        .order("created_at");
      if (error) return jsonResponse({ error: "list_failed" }, 500);
      const ids = (rows ?? []).map((r) => r.user_id as string);
      const names = new Map<string, string | null>();
      if (ids.length > 0) {
        const { data } = await admin.from("profiles").select("user_id, display_name").in("user_id", ids);
        for (const p of data ?? []) names.set(p.user_id as string, (p.display_name as string | null) ?? null);
      }
      const admins = [];
      for (const r of rows ?? []) {
        const { data: u } = await admin.auth.admin.getUserById(r.user_id);
        admins.push({ ...r, name: names.get(r.user_id) ?? null, email: u?.user?.email ?? null });
      }
      // Super-Admin first.
      admins.sort((a, b) => (a.role === b.role ? 0 : a.role === "super_admin" ? -1 : 1));
      return jsonResponse({ admins });
    }
    case "add": {
      const email = (body.email ?? "").trim();
      if (!email.includes("@")) return jsonResponse({ error: "invalid_email" }, 400);
      const userId = await findUserIdByEmail(admin, email);
      if (!userId) return jsonResponse({ error: "no_account" }, 404);
      const { data: existing } = await admin.from("admin_users").select("role").eq("user_id", userId).maybeSingle();
      if (existing) return jsonResponse({ error: "already_admin" }, 409);
      const { error } = await admin.from("admin_users").insert({
        user_id: userId,
        role: "admin",
        can_feedback: !!body.can_feedback,
        can_vouchers: !!body.can_vouchers,
        created_by: me.id,
      });
      if (error) return jsonResponse({ error: "insert_failed" }, 500);
      return jsonResponse({ status: "ok", user_id: userId });
    }
    case "update": {
      if (!body.user_id) return jsonResponse({ error: "invalid" }, 400);
      const patch: Record<string, boolean> = {};
      if (typeof body.can_feedback === "boolean") patch.can_feedback = body.can_feedback;
      if (typeof body.can_vouchers === "boolean") patch.can_vouchers = body.can_vouchers;
      // Only Admins -- the Super-Admin row is never touched here.
      const { data, error } = await admin
        .from("admin_users")
        .update(patch)
        .eq("user_id", body.user_id)
        .eq("role", "admin")
        .select("user_id");
      if (error) return jsonResponse({ error: "update_failed" }, 500);
      if (!data?.length) return jsonResponse({ error: "not_found" }, 404);
      return jsonResponse({ status: "ok" });
    }
    case "remove": {
      if (!body.user_id) return jsonResponse({ error: "invalid" }, 400);
      const { data, error } = await admin
        .from("admin_users")
        .delete()
        .eq("user_id", body.user_id)
        .eq("role", "admin")
        .select("user_id");
      if (error) return jsonResponse({ error: "delete_failed" }, 500);
      if (!data?.length) return jsonResponse({ error: "not_found" }, 404);
      return jsonResponse({ status: "ok" });
    }
    default:
      return jsonResponse({ error: "unknown_action" }, 400);
  }
});
