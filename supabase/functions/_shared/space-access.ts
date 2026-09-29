// Space authorization for service-role Edge Functions -- like
// channel-access.ts, no logic of its own: it asks the database's access_*
// functions (migrations/0047_authorization_single_source.sql), the single
// source RLS uses as well.

// deno-lint-ignore no-explicit-any
type Admin = any;

export interface SpaceAccess {
  exists: boolean;
  /** false = in the trash (migrations/0048). */
  active: boolean;
  isStaff: boolean;
  /** Administrator or co-owner. */
  manages: boolean;
  /** The Administrator (spaces.owner_id) only -- also while in the trash (may restore). */
  isAdmin: boolean;
  adminId: string | null;
}

export async function resolveSpaceAccess(supabaseAdmin: Admin, spaceId: string, userId: string): Promise<SpaceAccess> {
  const { data, error } = await supabaseAdmin.rpc("access_space", { p_user: userId, p_space: spaceId });
  if (error) throw new Error(`access_space failed: ${error.message}`);
  if (!data?.exists) return { exists: false, active: false, isStaff: false, manages: false, isAdmin: false, adminId: null };
  return {
    exists: true,
    active: data.active as boolean,
    isStaff: data.is_staff as boolean,
    manages: data.manages as boolean,
    isAdmin: data.is_admin as boolean,
    adminId: data.admin_id as string,
  };
}

/** Administrator or co-owner of this Space. */
export async function isSpaceOwnerOrCoOwner(supabaseAdmin: Admin, spaceId: string, userId: string): Promise<boolean> {
  return (await resolveSpaceAccess(supabaseAdmin, spaceId, userId)).manages;
}

export async function isStaff(supabaseAdmin: Admin, userId: string): Promise<boolean> {
  const { data, error } = await supabaseAdmin.rpc("access_is_staff", { p_user: userId });
  if (error) throw new Error(`access_is_staff failed: ${error.message}`);
  return data === true;
}

/** Everyone who manages this Space: the Administrator plus every co-owner. */
export async function spaceManagerIds(supabaseAdmin: Admin, spaceId: string): Promise<string[]> {
  const [{ data: spaceRow }, { data: coOwners }] = await Promise.all([
    supabaseAdmin.from("spaces").select("owner_id").eq("id", spaceId).maybeSingle(),
    supabaseAdmin.from("space_co_owners").select("user_id").eq("space_id", spaceId),
  ]);
  const ids: string[] = (coOwners ?? []).map((c: { user_id: string }) => c.user_id);
  if (spaceRow?.owner_id) ids.unshift(spaceRow.owner_id as string);
  return [...new Set(ids)];
}
