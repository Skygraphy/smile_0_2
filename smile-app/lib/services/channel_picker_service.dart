import '../main.dart';

/// A Space linked to a channel, either as its home Space or via a
/// view-only share (channel_shares).
class SpaceRef {
  SpaceRef({required this.id, required this.name});

  final String id;
  final String name;

  factory SpaceRef.fromJson(Map<String, dynamic> json) => SpaceRef(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class UploadableChannel {
  UploadableChannel({required this.channelId, required this.channelName, required this.spaceName});

  final String channelId;
  final String channelName;
  final String spaceName;
}

class ChannelWithActivity {
  ChannelWithActivity({
    required this.channelId,
    required this.channelName,
    required this.spaces,
    required this.isMember,
    required this.lastActivityAt,
  });

  final String channelId;
  final String channelName;
  final List<SpaceRef> spaces;
  // False for a channel the caller can only view via a Space they own
  // being shared into it (channel_shares) -- no posting rights.
  final bool isMember;
  final DateTime lastActivityAt;

  String get spaceLabel => spaces.map((s) => s.name).join(', ');

  factory ChannelWithActivity.fromJson(Map<String, dynamic> json) => ChannelWithActivity(
        channelId: json['channel_id'] as String,
        channelName: json['channel_name'] as String,
        spaces: (json['spaces'] as List).cast<Map<String, dynamic>>().map(SpaceRef.fromJson).toList(),
        isMember: json['is_member'] as bool,
        lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
      );
}

/// Channel discovery for the two places the app needs it: which channels
/// the caller can *post* to (a `channel_members` row -- the SCO is always
/// one too, auto-joined at creation), and which channels the caller can
/// *see* at all, including view-only shares (server-side, since "latest
/// ready media_item per channel" needs real aggregation).
class ChannelPickerService {
  Future<List<UploadableChannel>> listMyUploadableChannels() async {
    final rows = await supabase
        .from('channel_members')
        .select('channel_id, channels(name, spaces(name))')
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final channel = row['channels'] as Map<String, dynamic>;
      final space = channel['spaces'] as Map<String, dynamic>;
      return UploadableChannel(
        channelId: row['channel_id'] as String,
        channelName: channel['name'] as String,
        spaceName: space['name'] as String,
      );
    }).toList();
  }

  /// Every channel the caller can *see* (including view-only shares),
  /// sorted by most recent photo activity -- powers channels_home_screen.dart's
  /// WhatsApp-style flat "who did I last exchange photos with" landing list.
  Future<List<ChannelWithActivity>> listMyChannelsWithActivity() async {
    final response = await supabase.functions.invoke('list-my-channels');
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw ChannelPickerException(data['error'] as String);
    final channels = (data['channels'] as List).cast<Map<String, dynamic>>();
    return channels.map(ChannelWithActivity.fromJson).toList();
  }
}

class ChannelPickerException implements Exception {
  ChannelPickerException(this.code);

  final String code;

  @override
  String toString() => 'ChannelPickerException($code)';
}
