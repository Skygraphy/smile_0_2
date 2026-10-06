import '../main.dart';
import 'edge_functions.dart';

class SmileFrame {
  SmileFrame({
    required this.id,
    required this.name,
    required this.lifecycleState,
    required this.channelSwitchEnabled,
    this.videoSound = true,
    this.pairingCode,
    this.pairingCodeExpiresAt,
    this.currentAppVersion,
    this.lastSeenAt,
    this.batteryLevel,
    this.isCharging,
    this.deviceModel,
  });

  final String id;
  final String name;
  final String lifecycleState; // 'pending' | 'active' | 'revoked'
  final bool channelSwitchEnabled;

  /// Play videos with sound on this Frame (migrations/0056).
  final bool videoSound;
  final String? pairingCode;
  final DateTime? pairingCodeExpiresAt;
  final String? currentAppVersion;
  final DateTime? lastSeenAt;
  final int? batteryLevel;
  final bool? isCharging;
  // Which physical device this Frame record is actually bound to (e.g.
  // "samsung SM-P610") -- reported by the Frame itself on every heartbeat.
  // Null until the paired hardware's first heartbeat lands.
  final String? deviceModel;

  bool get isRevoked => lifecycleState == 'revoked';

  SmileFrame copyWith({bool? channelSwitchEnabled, bool? videoSound}) => SmileFrame(
        id: id,
        name: name,
        lifecycleState: lifecycleState,
        channelSwitchEnabled: channelSwitchEnabled ?? this.channelSwitchEnabled,
        videoSound: videoSound ?? this.videoSound,
        pairingCode: pairingCode,
        pairingCodeExpiresAt: pairingCodeExpiresAt,
        currentAppVersion: currentAppVersion,
        lastSeenAt: lastSeenAt,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        deviceModel: deviceModel,
      );
  bool get isPending => lifecycleState == 'pending';

  factory SmileFrame.fromJson(Map<String, dynamic> json) => SmileFrame(
        id: json['id'] as String,
        name: json['name'] as String,
        lifecycleState: json['lifecycle_state'] as String,
        channelSwitchEnabled: json['channel_switch_enabled'] as bool? ?? false,
        videoSound: json['video_sound'] as bool? ?? true,
        pairingCode: json['pairing_code'] as String?,
        pairingCodeExpiresAt:
            json['pairing_code_expires_at'] != null ? DateTime.parse(json['pairing_code_expires_at'] as String) : null,
        currentAppVersion: json['current_app_version'] as String?,
        lastSeenAt: json['last_seen_at'] != null ? DateTime.parse(json['last_seen_at'] as String) : null,
        batteryLevel: json['battery_level'] as int?,
        isCharging: json['is_charging'] as bool?,
        deviceModel: json['device_model'] as String?,
      );
}

class FrameChannelAssignment {
  FrameChannelAssignment({required this.channelId, required this.channelName});

  final String channelId;
  final String channelName;
}

class AssignableChannel {
  AssignableChannel({required this.channelId, required this.channelName});

  final String channelId;
  final String channelName;
}

/// Backs space_info_screen.dart / frame_settings_screen.dart. A Frame is
/// created here (named, like a Channel) and generates a pairing code the
/// physical Smile-Frame hardware later consumes itself
/// (claim-frame-pairing) -- reversed order from the pre-reset schema, see
/// migrations/0031_architecture_reset.sql. No MDM/compliance surface any
/// more (removed with the architecture reset): only plain operational
/// telemetry (last_seen/battery/app_version) and the channel-switch
/// display setting remain.
class FrameService {
  static const _frameColumns = 'id, name, lifecycle_state, channel_switch_enabled, video_sound, pairing_code, '
      'pairing_code_expires_at, current_app_version, last_seen_at, battery_level, is_charging, device_model';

  Future<List<SmileFrame>> listFrames(String spaceId) async {
    final rows = await supabase.from('frames').select(_frameColumns).eq('space_id', spaceId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(SmileFrame.fromJson).toList();
  }

  Future<SmileFrame> getFrame(String frameId) async {
    final row = await supabase.from('frames').select(_frameColumns).eq('id', frameId).single();
    return SmileFrame.fromJson(row);
  }

  /// Generates the pairing code server-side (create-frame) -- a real
  /// CSPRNG and collision retry, same reasoning as every other code-issuing
  /// flow in this codebase.
  Future<SmileFrame> createFrame({required String spaceId, required String name}) async {
    final response = await invokeEdge('create-frame', body: {'space_id': spaceId, 'name': name});
    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['frame_id'] == null) {
      throw FrameServiceException(data?['error'] as String? ?? 'unknown_error');
    }
    return getFrame(data['frame_id'] as String);
  }

  Future<void> renameFrame({required String frameId, required String name}) async {
    await supabase.from('frames').update({'name': name}).eq('id', frameId);
  }

  /// Revoking immediately locks the Frame out server-side (every one of
  /// its own calls -- get-media-batch, submit-heartbeat, refresh-frame-token
  /// -- requires `lifecycle_state = 'active'`). Reactivating undoes exactly
  /// that; the Frame's existing credentials still work, no re-pairing needed.
  Future<void> setRevoked({required String frameId, required bool revoked}) async {
    await supabase.from('frames').update({'lifecycle_state': revoked ? 'revoked' : 'active'}).eq('id', frameId);
  }

  Future<void> setChannelSwitchEnabled({required String frameId, required bool enabled}) async {
    await supabase.from('frames').update({'channel_switch_enabled': enabled}).eq('id', frameId);
  }

  Future<void> setVideoSound({required String frameId, required bool enabled}) async {
    await supabase.from('frames').update({'video_sound': enabled}).eq('id', frameId);
  }

  Future<List<FrameChannelAssignment>> listAssignedChannels(String frameId) async {
    final rows = await supabase
        .from('frame_channels')
        .select('channel_id, channels(name)')
        .eq('frame_id', frameId)
        .order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final channel = row['channels'] as Map<String, dynamic>;
      return FrameChannelAssignment(channelId: row['channel_id'] as String, channelName: channel['name'] as String);
    }).toList();
  }

  /// A Frame may show any channel its own Space can view: the Space's own
  /// channels, or a channel shared into it (channel_shares) -- mirrors
  /// `can_view_channel()`'s RLS. Scoped to already-unassigned channels.
  Future<List<AssignableChannel>> listUnassignedChannelsInSpace({
    required String spaceId,
    required String frameId,
  }) async {
    final results = await Future.wait([
      supabase.from('channels').select('id, name').eq('space_id', spaceId),
      supabase.from('channel_shares').select('channel_id, channels(name)').eq('space_id', spaceId),
      supabase.from('frame_channels').select('channel_id').eq('frame_id', frameId),
    ]);
    final homeChannels = (results[0] as List).cast<Map<String, dynamic>>();
    final sharedChannels = (results[1] as List).cast<Map<String, dynamic>>();
    final assignedIds = (results[2] as List).cast<Map<String, dynamic>>().map((r) => r['channel_id'] as String).toSet();

    final byId = <String, AssignableChannel>{};
    for (final row in homeChannels) {
      byId[row['id'] as String] = AssignableChannel(channelId: row['id'] as String, channelName: row['name'] as String);
    }
    for (final row in sharedChannels) {
      final channel = row['channels'] as Map<String, dynamic>;
      byId[row['channel_id'] as String] =
          AssignableChannel(channelId: row['channel_id'] as String, channelName: channel['name'] as String);
    }
    byId.removeWhere((id, _) => assignedIds.contains(id));
    return byId.values.toList();
  }

  /// Edge-function-backed (not a bare insert) so the refusal comes with a
  /// clear reason when the Frame's household can't see the channel -- see
  /// assign-frame-channel/index.ts.
  Future<void> assignChannel({required String frameId, required String channelId}) async {
    final response = await invokeEdge('assign-frame-channel', body: {
      'frame_id': frameId,
      'channel_id': channelId,
    });
    final data = response.data as Map<String, dynamic>?;
    if (data?['status'] != 'assigned') {
      throw FrameServiceException(data?['error'] as String? ?? 'unknown_error');
    }
  }

  Future<void> unassignChannel({required String frameId, required String channelId}) async {
    await supabase.from('frame_channels').delete().eq('frame_id', frameId).eq('channel_id', channelId);
  }
}

class FrameServiceException implements Exception {
  FrameServiceException(this.code);

  final String code;

  @override
  String toString() => 'FrameServiceException($code)';
}
