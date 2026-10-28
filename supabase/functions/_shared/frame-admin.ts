// Frame-Admin (migrations/0089): someone the Space's Admin chose to decide
// everything about how ONE Frame is used. Service-role helpers.
// deno-lint-ignore no-explicit-any
type Admin = any;

export async function isFrameAdmin(supabaseAdmin: Admin, frameId: string, userId: string): Promise<boolean> {
  const { data } = await supabaseAdmin
    .from("frame_admins")
    .select("user_id")
    .eq("frame_id", frameId)
    .eq("user_id", userId)
    .maybeSingle();
  return !!data;
}

export async function frameAdminIds(supabaseAdmin: Admin, frameId: string): Promise<string[]> {
  const { data } = await supabaseAdmin.from("frame_admins").select("user_id").eq("frame_id", frameId);
  return (data ?? []).map((r: { user_id: string }) => r.user_id);
}
