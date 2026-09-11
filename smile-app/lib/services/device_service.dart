import '../main.dart';

class SmileDevice {
  SmileDevice({
    required this.id,
    required this.name,
    required this.lifecycleState,
    this.currentAppVersion,
    this.lastSeenAt,
    this.lastComplianceCheckAt,
    this.lastComplianceState,
    this.batteryLevel,
    this.isCharging,
  });

  final String id;
  final String name;
  final String lifecycleState; // 'unpaired' | 'pairing' | 'active' | 'offline' | 'revoked' | 'retired'
  final String? currentAppVersion;
  final DateTime? lastSeenAt;
  final DateTime? lastComplianceCheckAt;
  final String? lastComplianceState; // 'compliant' | 'drift_detected' | 'repaired' | 'unknown'
  final int? batteryLevel;
  final bool? isCharging;

  bool get isRevoked => lifecycleState == 'revoked';

  factory SmileDevice.fromJson(Map<String, dynamic> json) => SmileDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        lifecycleState: json['lifecycle_state'] as String,
        currentAppVersion: json['current_app_version'] as String?,
        lastSeenAt: json['last_seen_at'] != null ? DateTime.parse(json['last_seen_at'] as String) : null,
        lastComplianceCheckAt: json['last_compliance_check_at'] != null
            ? DateTime.parse(json['last_compliance_check_at'] as String)
            : null,
        lastComplianceState: json['last_compliance_state'] as String?,
        batteryLevel: json['battery_level'] as int?,
        isCharging: json['is_charging'] as bool?,
      );
}

class DeviceChannelAssignment {
  DeviceChannelAssignment({required this.membershipId, required this.channelId, required this.channelName});

  final String membershipId;
  final String channelId;
  final String channelName;
}

class AssignableChannel {
  AssignableChannel({required this.channelId, required this.channelName});

  final String channelId;
  final String channelName;
}

/// Backs device_list_screen.dart / device_settings_screen.dart -- the
/// minimal sliver of "device fleet management" needed to make the Frame
/// channel-switcher (Personal Mode, concept doc sect. 19) actually have
/// something to switch between: which channels of its own Space a device
/// is assigned to, and whether it may switch between them locally. Device
/// renaming/removal/compliance stay deferred to a later Phase 6 slice.
class DeviceService {
  static const _deviceColumns = 'id, name, lifecycle_state, current_app_version, last_seen_at, '
      'last_compliance_check_at, last_compliance_state, battery_level, is_charging';

  Future<List<SmileDevice>> listDevices(String spaceId) async {
    final rows = await supabase.from('devices').select(_deviceColumns).eq('space_id', spaceId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(SmileDevice.fromJson).toList();
  }

  Future<SmileDevice> getDevice(String deviceId) async {
    final row = await supabase.from('devices').select(_deviceColumns).eq('id', deviceId).single();
    return SmileDevice.fromJson(row);
  }

  Future<void> renameDevice({required String deviceId, required String name}) async {
    await supabase.from('devices').update({'name': name}).eq('id', deviceId);
  }

  /// Revoking immediately locks the device out server-side (is_own_device()
  /// requires lifecycle_state in ('active','offline')) -- every one of its
  /// own calls (get-media-batch, submit-heartbeat, ...) starts failing with
  /// device_not_active right away, well before any local action on the
  /// Frame itself. Reactivating undoes exactly that, for a revoke done by
  /// mistake -- the device's existing credentials still work once active
  /// again, no re-pairing needed.
  Future<void> setRevoked({required String deviceId, required bool revoked}) async {
    await supabase.from('devices').update({'lifecycle_state': revoked ? 'revoked' : 'active'}).eq('id', deviceId);
  }

  Future<List<DeviceChannelAssignment>> listAssignedChannels(String deviceId) async {
    final rows = await supabase
        .from('channel_memberships')
        .select('id, channel_id, channels(name)')
        .eq('device_id', deviceId)
        .eq('role', 'device')
        .order('sort_order');
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final channel = row['channels'] as Map<String, dynamic>;
      return DeviceChannelAssignment(
        membershipId: row['id'] as String,
        channelId: row['channel_id'] as String,
        channelName: channel['name'] as String,
      );
    }).toList();
  }

  /// Scoped to the device's own Space -- a Frame conceptually belongs to
  /// one Space, so only that Space's channels are offered here, even
  /// though nothing in RLS itself would stop a cross-Space assignment.
  Future<List<AssignableChannel>> listUnassignedChannelsInSpace({
    required String spaceId,
    required String deviceId,
  }) async {
    final allChannels = await supabase.from('channels').select('id, name').eq('space_id', spaceId);
    final assigned = await listAssignedChannels(deviceId);
    final assignedIds = assigned.map((a) => a.channelId).toSet();
    return (allChannels as List)
        .cast<Map<String, dynamic>>()
        .where((row) => !assignedIds.contains(row['id'] as String))
        .map((row) => AssignableChannel(channelId: row['id'] as String, channelName: row['name'] as String))
        .toList();
  }

  /// Edge-function-backed (not a bare insert) because assigning a device to
  /// a channel that already has ready photos also has to backfill
  /// media_recipients for them -- see assign-device-channel/index.ts. A
  /// device only ever gets *new* uploads for free via fanOutToDevices;
  /// nothing backfills history for it otherwise, so it would silently show
  /// nothing from before the moment it was assigned.
  Future<void> assignChannel({required String deviceId, required String channelId}) async {
    final response = await supabase.functions.invoke('assign-device-channel', body: {
      'device_id': deviceId,
      'channel_id': channelId,
    });
    final data = response.data as Map<String, dynamic>?;
    if (data?['status'] != 'assigned') {
      throw DeviceServiceException(data?['error'] as String? ?? 'unknown_error');
    }
  }

  Future<void> unassignChannel(String membershipId) async {
    await supabase.from('channel_memberships').delete().eq('id', membershipId);
  }

  Future<bool> getChannelSwitchEnabled(String deviceId) async {
    final row =
        await supabase.from('device_policies').select('channel_switch_enabled').eq('device_id', deviceId).maybeSingle();
    return row?['channel_switch_enabled'] as bool? ?? false;
  }

  Future<void> setChannelSwitchEnabled({required String deviceId, required bool enabled}) async {
    await supabase.from('device_policies').update({'channel_switch_enabled': enabled}).eq('device_id', deviceId);
  }
}

class DeviceServiceException implements Exception {
  DeviceServiceException(this.code);

  final String code;

  @override
  String toString() => 'DeviceServiceException($code)';
}
