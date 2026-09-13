import '../main.dart';

/// Channel creation goes through the `create_channel` Postgres function
/// (0030_multi_space_channels.sql) rather than a direct insert: `channels`
/// no longer carries a `space_id` column to check an insert policy against
/// -- a channel can be linked to more than one Space via `space_channels`
/// -- so the function does both inserts atomically and checks
/// Space-Owner-or-staff authorization itself. The existing
/// on_channel_created trigger still auto-joins the creator as
/// channel_admin so they can immediately post into their own channel.
class ChannelService {
  Future<List<Map<String, dynamic>>> listChannels(String spaceId) async {
    final rows = await supabase
        .from('space_channels')
        .select('channels(id, name)')
        .eq('space_id', spaceId)
        .order('created_at');
    return rows
        .map((row) => row['channels'] as Map<String, dynamic>)
        .toList()
        .cast<Map<String, dynamic>>();
  }

  Future<void> createChannel({required String spaceId, required String name}) async {
    await supabase.rpc('create_channel', params: {'p_space_id': spaceId, 'p_name': name});
  }
}
