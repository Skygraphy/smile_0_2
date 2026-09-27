// Whether a user is authorized to act as this Space's SCO -- either the
// original founder (spaces.owner_id) or a co-owner the founder has added
// (space_co_owners, see migrations/0037_space_co_owners.sql). RLS's own
// is_space_owner()/is_home_space_owner() already include co-owners, but
// every service-role Edge Function that re-implements this check itself
// (bypassing RLS) has to replicate the same decision explicitly, or a
// co-owner would incorrectly get a 403 from those functions despite every
// plain RLS-governed table call already working for them.
// deno-lint-ignore no-explicit-any
export async function isSpaceOwnerOrCoOwner(supabaseAdmin: any, spaceId: string, userId: string): Promise<boolean> {
  const { data: spaceRow } = await supabaseAdmin.from("spaces").select("owner_id").eq("id", spaceId).maybeSingle();
  if (!spaceRow) return false;
  if (spaceRow.owner_id === userId) return true;
  const { data: coOwnerRow } = await supabaseAdmin
    .from("space_co_owners")
    .select("user_id")
    .eq("space_id", spaceId)
    .eq("user_id", userId)
    .maybeSingle();
  return Boolean(coOwnerRow);
}
