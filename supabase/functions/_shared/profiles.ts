// Resolves display_name/avatar for a batch of user ids, the same way
// every roster function already resolves auth.users.email with the
// service-role key (profiles' own RLS is fully self-scoped, see
// migrations/0029_profiles_and_avatars.sql -- this is the one place
// allowed to read across users).
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";

export function avatarPublicUrl(avatarPath: string | null | undefined): string | null {
  if (!avatarPath) return null;
  return `${supabaseUrl}/storage/v1/object/public/avatars/${avatarPath}`;
}

export interface ResolvedProfile {
  display_name: string | null;
  avatar_url: string | null;
}

// deno-lint-ignore no-explicit-any
export async function fetchProfilesByUserId(supabaseAdmin: any, userIds: string[]): Promise<Map<string, ResolvedProfile>> {
  const map = new Map<string, ResolvedProfile>();
  const uniqueIds = [...new Set(userIds)];
  if (uniqueIds.length === 0) return map;
  const { data } = await supabaseAdmin.from("profiles").select("user_id, display_name, avatar_path").in("user_id", uniqueIds);
  for (const row of data ?? []) {
    map.set(row.user_id as string, {
      display_name: (row.display_name as string | null) ?? null,
      avatar_url: avatarPublicUrl(row.avatar_path as string | null),
    });
  }
  return map;
}
