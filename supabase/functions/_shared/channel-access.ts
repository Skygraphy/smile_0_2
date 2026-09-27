// Mirrors the DB's own can_view_channel()/is_home_space_owner() helpers
// (migrations/0031_architecture_reset.sql) for service-role Edge Functions
// that need the same authorization decision in application code -- e.g. to
// return a clean 403 before doing real work, rather than relying solely on
// a later RLS-backed query to fail. Defense in depth, not a new
// authorization surface: every function using this still only ever reads
// or writes what the matching RLS policy would also allow for that caller.
// deno-lint-ignore no-explicit-any
export async function resolveChannelAccess(supabaseAdmin: any, channelId: string, userId: string) {
  const { data: channel } = await supabaseAdmin.from("channels").select("space_id").eq("id", channelId).maybeSingle();
  if (!channel) return { exists: false, canView: false, isMember: false, isSco: false, homeSpaceId: null as string | null };

  const [{ data: staffRow }, { data: spaceRow }, { data: memberRow }, { data: shareRow }, { data: coOwnerRow }] = await Promise.all([
    supabaseAdmin.from("staff_members").select("user_id").eq("user_id", userId).maybeSingle(),
    supabaseAdmin.from("spaces").select("owner_id").eq("id", channel.space_id).maybeSingle(),
    supabaseAdmin.from("channel_members").select("user_id").eq("channel_id", channelId).eq("user_id", userId).maybeSingle(),
    supabaseAdmin
      .from("channel_shares")
      .select("space_id, spaces!inner(owner_id)")
      .eq("channel_id", channelId)
      .eq("spaces.owner_id", userId)
      .maybeSingle(),
    // A co-owner of the channel's home Space (migrations/0037_space_co_owners.sql)
    // is just as much its SCO as the founder -- see _shared/space-access.ts's
    // doc comment for why every service-role function has to check this
    // explicitly instead of relying on RLS alone.
    supabaseAdmin.from("space_co_owners").select("user_id").eq("space_id", channel.space_id).eq("user_id", userId).maybeSingle(),
  ]);

  const isStaff = Boolean(staffRow);
  const isSco = spaceRow?.owner_id === userId || Boolean(coOwnerRow);
  const isMember = Boolean(memberRow);
  const isSharedViewer = Boolean(shareRow);

  return {
    exists: true,
    canView: isStaff || isSco || isMember || isSharedViewer,
    isMember: isMember || isSco, // the SCO is always auto-joined too, but this stays correct even if that ever changed
    isSco,
    homeSpaceId: channel.space_id as string,
  };
}
