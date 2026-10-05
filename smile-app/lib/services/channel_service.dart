import '../main.dart';

/// Channel creation is a plain client insert -- `channels.space_id` is a
/// real not-null column again (migrations/0031_architecture_reset.sql
/// replaced the old n:m `space_channels` join table), so `channels_owner_insert`'s
/// RLS (`is_space_owner(space_id)`) is all the authorization this needs; no
/// RPC/Edge Function required. `on_channel_created` still auto-joins the
/// creator (the SCO) into `channel_members` so they can post immediately.
class ChannelService {
  Future<List<Map<String, dynamic>>> listChannels(String spaceId) async {
    final rows = await supabase.from('channels').select('id, name').eq('space_id', spaceId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> createChannel({required String spaceId, required String name}) async {
    await supabase.from('channels').insert({'space_id': spaceId, 'name': name});
  }

  /// Home Space Admin and Co-Admins only (RLS channels_owner_update).
  Future<void> renameChannel({required String channelId, required String name}) async {
    await supabase.from('channels').update({'name': name}).eq('id', channelId);
  }

  /// Frames showing this album -- RLS only returns Frames of Spaces the
  /// caller manages, so other households' Frames never show up here.
  Future<List<({String frameId, String frameName})>> listFramesShowing(String channelId) async {
    final rows = await supabase
        .from('frame_channels')
        .select('frame_id, frames(name, lifecycle_state)')
        .eq('channel_id', channelId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['frames'] != null && (r['frames'] as Map)['lifecycle_state'] != 'revoked')
        .map((r) => (frameId: r['frame_id'] as String, frameName: (r['frames'] as Map)['name'] as String))
        .toList();
  }

  /// Into the 30-day trash, for everyone at once (delete-space-or-channel);
  /// restorable via TrashService until purge-trash removes it for good.
  Future<void> deleteChannel(String channelId) async {
    await supabase.functions.invoke('delete-space-or-channel', body: {'kind': 'channel', 'id': channelId});
  }
}
