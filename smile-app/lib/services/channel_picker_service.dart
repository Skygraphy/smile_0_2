import '../main.dart';

/// A Space a channel is linked to (space_channels) -- a channel can be
/// linked to more than one, e.g. shared between two households.
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
  UploadableChannel({required this.channelId, required this.channelName, required this.spaceNames});

  final String channelId;
  final String channelName;
  final List<String> spaceNames;

  String get spaceLabel => spaceNames.join(', ');
}

class ChannelWithActivity {
  ChannelWithActivity({
    required this.channelId,
    required this.channelName,
    required this.spaces,
    required this.lastActivityAt,
  });

  final String channelId;
  final String channelName;
  final List<SpaceRef> spaces;
  final DateTime lastActivityAt;

  String get spaceLabel => spaces.map((s) => s.name).join(', ');

  factory ChannelWithActivity.fromJson(Map<String, dynamic> json) => ChannelWithActivity(
        channelId: json['channel_id'] as String,
        channelName: json['channel_name'] as String,
        spaces: (json['spaces'] as List).cast<Map<String, dynamic>>().map(SpaceRef.fromJson).toList(),
        lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
      );
}

/// Every channel the caller can actually post a photo to: a
/// `channel_admin`/`contributor` membership (not `viewer`), or any channel
/// in a Space they own outright. Powers the header camera icon's "which
/// channel does this go to" step -- mirrors [GroupService.listGrantableChannels]'s
/// same owned-space-or-admin-membership merge, just with `contributor`
/// included too since posting a photo needs less privilege than
/// administering the channel.
class ChannelPickerService {
  Future<List<UploadableChannel>> listMyUploadableChannels() async {
    final memberships = await supabase
        .from('channel_memberships')
        .select('channel_id, channels(name)')
        .inFilter('role', ['channel_admin', 'contributor']);
    final ownedSpaceIds =
        (await supabase.from('space_owners').select('space_id')).map((row) => row['space_id'] as String).toList();
    final ownedChannels = ownedSpaceIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await supabase.from('space_channels').select('channel_id, channels(name)').inFilter(
            'space_id', ownedSpaceIds);

    final rows = [...memberships, ...ownedChannels];
    final channelIds = rows.map((r) => r['channel_id'] as String).toSet().toList();
    // A channel can be linked to more than one Space now -- collect every
    // linked Space's name per channel instead of relying on a single
    // nested `spaces(name)` embed (which needed the removed
    // channels.space_id FK).
    final spaceRows = channelIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await supabase.from('space_channels').select('channel_id, spaces(name)').inFilter(
            'channel_id', channelIds);
    final spaceNamesByChannel = <String, List<String>>{};
    for (final row in spaceRows) {
      final space = row['spaces'] as Map<String, dynamic>?;
      if (space == null) continue;
      (spaceNamesByChannel[row['channel_id'] as String] ??= []).add(space['name'] as String);
    }

    final byChannelId = <String, UploadableChannel>{};
    for (final row in rows) {
      final channelId = row['channel_id'] as String;
      final channel = row['channels'] as Map<String, dynamic>?;
      if (channel == null) continue;
      byChannelId[channelId] = UploadableChannel(
        channelId: channelId,
        channelName: channel['name'] as String,
        spaceNames: spaceNamesByChannel[channelId] ?? const [],
      );
    }
    return byChannelId.values.toList();
  }

  /// Every channel the caller can *see* (viewer role included, unlike
  /// [listMyUploadableChannels]), sorted by most recent photo activity --
  /// powers channels_home_screen.dart, the WhatsApp-style flat "who did I
  /// last exchange photos with" landing list, replacing the old
  /// Space-first home screen. Server-side (list-my-channels) since
  /// "latest ready media_item per channel" needs a real aggregation, not
  /// something worth approximating with a client-side limited query.
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
