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
}
