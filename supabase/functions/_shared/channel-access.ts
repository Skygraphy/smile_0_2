// Channel authorization for service-role Edge Functions. Deliberately NO
// logic of its own: the decision lives once, in the database's access_*
// functions (migrations/0047_authorization_single_source.sql), which RLS
// uses too -- so an Edge Function can never again drift from what the
// database itself allows (it did, several times, before 0047).
// deno-lint-ignore no-explicit-any
export async function resolveChannelAccess(supabaseAdmin: any, channelId: string, userId: string) {
  const { data, error } = await supabaseAdmin.rpc("access_channel", { p_user: userId, p_channel: channelId });
  if (error) throw new Error(`access_channel failed: ${error.message}`);
  if (!data?.exists) {
    return { exists: false, canView: false, isMember: false, isSco: false, isAdmin: false, isStaff: false, homeSpaceId: null as string | null };
  }
  return {
    exists: true,
    canView: data.can_view as boolean,
    // Posting rights = channel_members, exactly what media_items_insert's
    // RLS requires -- a manager who isn't a member doesn't post.
    isMember: data.is_member as boolean,
    // "SCO" = manages the home Space (Administrator or co-owner).
    isSco: data.manages as boolean,
    isAdmin: data.is_admin as boolean,
    isStaff: data.is_staff as boolean,
    homeSpaceId: data.home_space_id as string,
  };
}

/** Can a household (and so its Frames) see this channel -- its own, or shared into it. */
// deno-lint-ignore no-explicit-any
export async function spaceCanViewChannel(supabaseAdmin: any, spaceId: string, channelId: string): Promise<boolean> {
  const { data, error } = await supabaseAdmin.rpc("access_space_can_view_channel", { p_space: spaceId, p_channel: channelId });
  if (error) throw new Error(`access_space_can_view_channel failed: ${error.message}`);
  return data === true;
}

/** Every channel this person can see (list-my-channels). */
// deno-lint-ignore no-explicit-any
export async function visibleChannelIds(supabaseAdmin: any, userId: string): Promise<string[]> {
  const { data, error } = await supabaseAdmin.rpc("access_visible_channel_ids", { p_user: userId });
  if (error) throw new Error(`access_visible_channel_ids failed: ${error.message}`);
  // A setof-uuid RPC comes back as a plain array of ids.
  return (data ?? []) as string[];
}
