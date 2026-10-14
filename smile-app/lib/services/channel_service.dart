import '../main.dart';
import 'local_changes.dart';

/// Channel creation is a plain client insert -- `channels.space_id` is a
/// real not-null column again (migrations/0031_architecture_reset.sql
/// replaced the old n:m `space_channels` join table), so `channels_owner_insert`'s
/// RLS (`is_space_owner(space_id)`) is all the authorization this needs; no
/// RPC/Edge Function required. `on_channel_created` still auto-joins the
/// creator (the SCO) into `channel_members` so they can post immediately.
/// A Frame an album is on (album page, "Läuft auf").
typedef FrameShowing = ({
  String frameId,
  String frameName,
  String? avatarPath,
  String? currentChannelId,
  String? currentAlbumName,
  String? contentMode,
  String? playingRound,
});

class ChannelService {
  Future<List<Map<String, dynamic>>> listChannels(String spaceId) async {
    final rows = await supabase.from('channels').select('id, name').eq('space_id', spaceId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Returns the new album's id (to open it right away).
  Future<String> createChannel({required String spaceId, required String name}) async {
    final row = await supabase.from('channels').insert({'space_id': spaceId, 'name': name}).select('id').single();
    LocalChanges.saved(tablesChanged({'channels'}, spaceIds: {spaceId}));
    return row['id'] as String;
  }

  /// Home Space Admin and Co-Admins only (RLS channels_owner_update).
  Future<void> renameChannel({required String channelId, required String name}) async {
    await supabase.from('channels').update({'name': name}).eq('id', channelId);
  }

  /// Frames showing this album -- RLS only returns Frames of Spaces the
  /// caller manages, so other households' Frames never show up here.
  /// The Frames this album is on, each with the album it shows right now
  /// ([currentAlbumName] null: not known yet, see migrations/0069).
  Future<List<FrameShowing>> listFramesShowing(String channelId) async {
    final rows = await supabase
        .from('frame_channels')
        .select('frame_id, frames(name, lifecycle_state, avatar_path, current_channel_id, content_mode, playing_round, '
            'current:channels!frames_current_channel_id_fkey(name))')
        .eq('channel_id', channelId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['frames'] != null && (r['frames'] as Map)['lifecycle_state'] != 'revoked')
        .map((r) => (
              frameId: r['frame_id'] as String,
              frameName: (r['frames'] as Map)['name'] as String,
              avatarPath: (r['frames'] as Map)['avatar_path'] as String?,
              currentChannelId: (r['frames'] as Map)['current_channel_id'] as String?,
              currentAlbumName: ((r['frames'] as Map)['current'] as Map?)?['name'] as String?,
              contentMode: (r['frames'] as Map)['content_mode'] as String?,
              playingRound: (r['frames'] as Map)['playing_round'] as String?,
            ))
        .toList();
  }

  /// "I opened this album" -- clears its unread counter on all of the
  /// caller's devices (migrations/0058). A repeat call is a server-side
  /// no-op, so calling it after every feed reload is fine.
  Future<void> markAlbumSeen(String channelId) async {
    await supabase.rpc('mark_album_seen', params: {'p_channel': channelId});
    LocalChanges.saved(tablesChanged({'album_reads'}));
  }

  /// Into the 30-day trash, for everyone at once (delete-space-or-channel);
  /// restorable via TrashService until purge-trash removes it for good.
  Future<void> deleteChannel(String channelId) async {
    await supabase.functions.invoke('delete-space-or-channel', body: {'kind': 'channel', 'id': channelId});
    LocalChanges.saved(tablesChanged({'channels'}, channelIds: {channelId}));
  }
}
