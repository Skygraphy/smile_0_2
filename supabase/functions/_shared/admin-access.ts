// Who may work in the Verwaltung on smileapp.app (migrations/0114).
// The Super-Admin may always do everything; an Admin what is ticked.

// deno-lint-ignore no-explicit-any
type Client = any;

export interface AdminAccess {
  role: "super_admin" | "admin";
  feedback: boolean;
  vouchers: boolean;
  manageAdmins: boolean;
}

export async function adminAccess(admin: Client, userId: string): Promise<AdminAccess | null> {
  const { data } = await admin
    .from("admin_users")
    .select("role, can_feedback, can_vouchers")
    .eq("user_id", userId)
    .maybeSingle();
  if (!data) return null;
  const sup = data.role === "super_admin";
  return {
    role: data.role,
    feedback: sup || !!data.can_feedback,
    vouchers: sup || !!data.can_vouchers,
    manageAdmins: sup,
  };
}

/** Everyone who gets the Meldungen (push on a new one). */
export async function feedbackAdminIds(admin: Client): Promise<string[]> {
  const { data } = await admin.from("admin_users").select("user_id, role, can_feedback");
  return (data ?? [])
    .filter((r: { role: string; can_feedback: boolean }) => r.role === "super_admin" || r.can_feedback)
    .map((r: { user_id: string }) => r.user_id);
}
