import '../main.dart';

/// Channel creation is Space-Owner-only (channels_owner_insert RLS policy);
/// the on_channel_created trigger then auto-joins the creator as
/// channel_admin so they can immediately post into their own channel.
class ChannelService {
  Future<List<Map<String, dynamic>>> listChannels(String spaceId) async {
    final rows = await supabase.from('channels').select('id, name').eq('space_id', spaceId).order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createChannel({required String spaceId, required String name}) async {
    await supabase.from('channels').insert({'space_id': spaceId, 'name': name});
  }
}
