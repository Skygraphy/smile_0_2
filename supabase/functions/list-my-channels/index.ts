// Powers the channel-first home screen (channels_home_screen.dart):
// WhatsApp's own chat list shows conversations sorted by recency, not a
// Space/Frame hierarchy first. Every channel the caller can view: a direct
// channel_members row (this always includes the SCO too, auto-joined by
// the on_channel_created trigger -- migrations/0031_architecture_reset.sql),
// or a channel shared (channel_shares, view-only) into a Space they own.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { visibleChannelIds } from "../_shared/channel-access.ts";
import { avatarPublicUrl, fetchProfilesByUserId } from "../_shared/profiles.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  // Everything this person can see -- own/co-owned Spaces' channels,
  // channels they post in, channels shared into a Space they manage. The
  // single source (migrations/0047); before, this list forgot co-owners.
  const channelIds = await visibleChannelIds(supabaseAdmin, userId);
  if (channelIds.length === 0) return jsonResponse({ channels: [] });

  // Only for the "nur ansehen" label -- posting rights are membership.
  const { data: memberships } = await supabaseAdmin.from("channel_members").select("channel_id").eq("user_id", userId);
  const memberChannelIds = (memberships ?? []).map((m) => m.channel_id as string);

  const [{ data: channels, error: channelsError }, { data: shareRows }] = await Promise.all([
    // The explicit `!channels_space_id_fkey` hint is required: PostgREST
    // can also reach `spaces` from `channels` indirectly through
    // `channel_shares` (which has FKs to both), so a bare `spaces(...)`
    // embed is ambiguous (PGRST201: "more than one relationship was
    // found") the moment PostgREST's schema cache has picked up
    // channel_shares' FKs -- independent of whether any row actually
    // exists in it. This is why it wasn't caught during Phase 1-3
    // testing (done shortly after the schema reset, likely before
    // PostgREST's cache had settled) but broke on the very first real
    // walkthrough afterward.
    supabaseAdmin.from("channels").select("id, name, space_id, cover_path, cover_media_id, spaces!channels_space_id_fkey(id, name, avatar_path), created_at").in("id", channelIds),
    // Every Space this channel is shared into (not just the caller's own)
    // -- a shared channel shows both households' Space names, the same
    // reason WhatsApp shows every member of a group, not just the ones
    // you personally know.
    supabaseAdmin.from("channel_shares").select("channel_id, spaces(id, name, deleted_at)").in("channel_id", channelIds),
  ]);
  if (channelsError) return jsonResponse({ error: "fetch_failed" }, 500);

  const sharedSpacesByChannel = new Map<string, { id: string; name: string }[]>();
  for (const row of shareRows ?? []) {
    // deno-lint-ignore no-explicit-any
    const space = row.spaces as any;
    if (!space || space.deleted_at) continue;
    const channelId = row.channel_id as string;
    const list = sharedSpacesByChannel.get(channelId) ?? [];
    list.push({ id: space.id, name: space.name });
    sharedSpacesByChannel.set(channelId, list);
  }

  // Cheap two-column fetch across every candidate channel, not paged --
  // reducing to "latest per channel_id" client-side (below) is only
  // correct if this isn't silently truncated by a default row limit.
  const [{ data: mediaRows }, { data: hideRows }] = await Promise.all([
    supabaseAdmin
      .from("media_items")
      .select("id, channel_id, created_at, sender_id, media_type, storage_path_thumbnail")
      .in("channel_id", channelIds)
      .eq("processing_status", "ready")
      .order("created_at", { ascending: false })
      .limit(20000),
    // Photos the caller hid for themselves don't count, like a WhatsApp
    // message deleted "for me" no longer shows in the chat list.
    supabaseAdmin.from("media_item_hides").select("media_item_id").eq("user_id", userId),
  ]);
  const hidden = new Set((hideRows ?? []).map((r) => r.media_item_id as string));

  // Unread counter (migrations/0058): everything newer than the caller's
  // "last opened" marker, except their own posts. No marker = they never
  // opened the album since joining, so everything in it is new to them.
  const { data: readRows } = await supabaseAdmin
    .from("album_reads")
    .select("channel_id, last_seen_at")
    .eq("user_id", userId)
    .in("channel_id", channelIds);
  const lastSeen = new Map((readRows ?? []).map((r) => [r.channel_id as string, r.last_seen_at as string]));
  const unreadByChannel = new Map<string, number>();
  for (const row of mediaRows ?? []) {
    if (hidden.has(row.id as string) || row.sender_id === userId) continue;
    const channelId = row.channel_id as string;
    const seen = lastSeen.get(channelId);
    if (seen && (row.created_at as string) <= seen) continue;
    unreadByChannel.set(channelId, (unreadByChannel.get(channelId) ?? 0) + 1);
  }

  // The chat-list line ("Roman: 4 Fotos"): who posted last, and how many
  // items in a row they posted (the newest run of one sender), split into
  // photos and videos so the app can word it.
  type LastActivity = { at: string; senderId: string; photos: number; videos: number; open: boolean };
  const lastByChannel = new Map<string, LastActivity>();
  for (const row of mediaRows ?? []) {
    if (hidden.has(row.id as string)) continue;
    const channelId = row.channel_id as string;
    const sender = row.sender_id as string;
    const isVideo = row.media_type === "video";
    const last = lastByChannel.get(channelId);
    if (!last) {
      lastByChannel.set(channelId, { at: row.created_at as string, senderId: sender, photos: isVideo ? 0 : 1, videos: isVideo ? 1 : 0, open: true });
    } else if (last.open && last.senderId === sender) {
      if (isVideo) last.videos++;
      else last.photos++;
    } else {
      last.open = false;
    }
  }
  // Album cover (2026-10-07): the newest photo/video the caller can see in
  // it -- the list shows it instead of the same album icon on every row.
  const coverByChannel = new Map<string, { mediaId: string; path: string }>();
  for (const row of mediaRows ?? []) {
    if (hidden.has(row.id as string) || !row.storage_path_thumbnail) continue;
    const channelId = row.channel_id as string;
    if (!coverByChannel.has(channelId)) {
      coverByChannel.set(channelId, { mediaId: row.id as string, path: row.storage_path_thumbnail as string });
    }
  }
  // A cover chosen in the album ("Als Titelbild", migrations/0066) wins over
  // the newest photo -- as long as the caller can see it.
  for (const c of channels ?? []) {
    if (!c.cover_media_id) continue;
    const chosen = (mediaRows ?? []).find((m) => m.id === c.cover_media_id);
    if (chosen && !hidden.has(chosen.id as string) && chosen.storage_path_thumbnail) {
      coverByChannel.set(c.id as string, { mediaId: chosen.id as string, path: chosen.storage_path_thumbnail as string });
    }
  }
  const coverPaths = [...coverByChannel.values()].map((c) => c.path);
  const coverUrlByPath = new Map<string, string>();
  if (coverPaths.length > 0) {
    const { data: signed } = await supabaseAdmin.storage.from("media-thumbnails").createSignedUrls(coverPaths, 3600);
    for (const s of signed ?? []) if (s.path && s.signedUrl) coverUrlByPath.set(s.path, s.signedUrl);
  }

  const senderProfiles = await fetchProfilesByUserId(
    supabaseAdmin,
    [...new Set([...lastByChannel.values()].map((l) => l.senderId))],
  );

  const resolved = (channels ?? []).map((c) => {
    // deno-lint-ignore no-explicit-any
    const homeSpace = c.spaces as any;
    const spaces = [
      ...(homeSpace ? [{ id: homeSpace.id as string, name: homeSpace.name as string }] : []),
      ...(sharedSpacesByChannel.get(c.id as string) ?? []),
    ];
    return {
      channel_id: c.id,
      channel_name: c.name,
      spaces,
      is_member: memberChannelIds.includes(c.id as string),
      // No photo yet -> sort by the channel's own creation time, so a
      // brand-new empty channel still shows up in a sensible spot instead
      // of falling to the very bottom indefinitely.
      last_activity_at: lastByChannel.get(c.id as string)?.at ?? c.created_at,
      unread_count: unreadByChannel.get(c.id as string) ?? 0,
      cover: (() => {
        // An uploaded picture wins outright (stable public URL, no signing).
        if (c.cover_path) return { media_id: null, thumbnail_url: avatarPublicUrl(c.cover_path as string), custom: true };
        const cover = coverByChannel.get(c.id as string);
        const url = cover ? coverUrlByPath.get(cover.path) : undefined;
        return cover && url ? { media_id: cover.mediaId, thumbnail_url: url, custom: Boolean(c.cover_media_id) } : null;
      })(),
      last_post: (() => {
        const last = lastByChannel.get(c.id as string);
        if (!last) return null;
        return {
          sender_id: last.senderId,
          sender_name: senderProfiles.get(last.senderId)?.display_name ?? null,
          photos: last.photos,
          videos: last.videos,
        };
      })(),
    };
  });

  resolved.sort((a, b) => (a.last_activity_at < b.last_activity_at ? 1 : a.last_activity_at > b.last_activity_at ? -1 : 0));

  return jsonResponse({ channels: resolved });
});
