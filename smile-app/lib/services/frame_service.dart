import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../main.dart';
import 'edge_functions.dart';
import 'frame_controls.dart';
import 'local_changes.dart';
import 'media_service.dart';

class SmileFrame {
  SmileFrame({
    required this.id,
    required this.name,
    required this.lifecycleState,
    required this.channelSwitchEnabled,
    this.videoSound = true,
    this.avatarPath,
    this.currentChannelId,
    this.pairingCode,
    this.pairingCodeExpiresAt,
    this.currentAppVersion,
    this.lastSeenAt,
    this.batteryLevel,
    this.isCharging,
    this.deviceModel,
    this.playback = const {},
  });

  final String id;
  final String name;
  final String lifecycleState; // 'pending' | 'active' | 'revoked'
  final bool channelSwitchEnabled;

  /// Play videos with sound on this Frame (migrations/0056).
  final bool videoSound;

  /// Own picture in the avatars bucket (migrations/0066), else initials.
  final String? avatarPath;

  /// The album it shows right now (migrations/0069) -- set from the app
  /// ("Jetzt zeigen") or by a switch on the Frame. Null until the Frame's
  /// first sync: then it shows its first album.
  final String? currentChannelId;
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

  /// Control level and playback settings (migrations/0075), as the row
  /// has them -- read through the getters below.
  final Map<String, dynamic> playback;

  /// 1..5, or null = "Eigene Auswahl".
  int? get controlLevel => playback['control_level'] as int?;
  Map<String, bool> get controls =>
      {for (final e in ((playback['controls'] as Map?) ?? const {}).entries) e.key as String: e.value == true};
  String get contentMode => playback['content_mode'] as String? ?? 'album';

  /// A code to unlock every button on the Frame itself is set
  /// (Kindersperre, migrations/0089).
  bool get hasUnlockCode => playback['unlock_code_hash'] != null;
  int get recentCount => playback['recent_count'] as int? ?? 20;
  String get playOrder => playback['play_order'] as String? ?? 'oldest';
  String get endBehavior => playback['end_behavior'] as String? ?? 'loop';
  int get intervalSeconds => playback['slideshow_interval_seconds'] as int? ?? 10;
  bool get showNewImmediately => playback['show_new_immediately'] as bool? ?? true;

  /// Noticing new photos on the Frame (migrations/0093).
  bool get newSound => playback['new_sound'] as bool? ?? true;
  bool get newSoundReminder => playback['new_sound_reminder'] as bool? ?? true;
  bool get newHint => playback['new_hint'] as bool? ?? true;

  /// Easy Stopping (migrations/0094): a tap on the Frame stops the picture.
  bool get easyStop => playback['easy_stop'] as bool? ?? true;

  /// A stopped photo keeps its slow zoom (migrations/0096).
  bool get pauseZoom => playback['pause_zoom'] as bool? ?? true;
  bool get showClock => playback['show_clock'] as bool? ?? false;
  bool get showSender => playback['show_sender'] as bool? ?? true;
  String? get quietFrom => playback['quiet_from'] as String?;
  String? get quietTo => playback['quiet_to'] as String?;

  /// migrations/0079: video length, filling the screen, slow zoom.
  String get videoLength => playback['video_length'] as String? ?? 'full';
  String get fillMode => playback['fill_mode'] as String? ?? 'auto';
  bool get slowZoom => playback['slow_zoom'] as bool? ?? true;
  bool get rotateWithDevice => playback['rotate_with_device'] as bool? ?? false;
  bool get showCaptions => playback['show_captions'] as bool? ?? true;

  /// A round played on the Frame right now (migrations/0077).
  String? get playingRound => playback['playing_round'] as String?;

  /// The same Frame with some settings changed (shown at once, before the
  /// server has them).
  SmileFrame withSettings(Map<String, dynamic> changes) => SmileFrame(
        id: id,
        name: name,
        lifecycleState: lifecycleState,
        channelSwitchEnabled: changes['channel_switch_enabled'] as bool? ?? channelSwitchEnabled,
        videoSound: changes['video_sound'] as bool? ?? videoSound,
        avatarPath: avatarPath,
        currentChannelId: currentChannelId,
        pairingCode: pairingCode,
        pairingCodeExpiresAt: pairingCodeExpiresAt,
        currentAppVersion: currentAppVersion,
        lastSeenAt: lastSeenAt,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        deviceModel: deviceModel,
        playback: {...playback, ...changes},
      );

  bool get isRevoked => lifecycleState == 'revoked';

  /// Frames report in at least every 2 minutes; 10 minutes of silence =
  /// offline (the dot on the Frame's tile).
  bool get isOnline =>
      lifecycleState == 'active' && lastSeenAt != null && DateTime.now().difference(lastSeenAt!) < const Duration(minutes: 10);

  SmileFrame copyWith({bool? channelSwitchEnabled, bool? videoSound}) => SmileFrame(
        id: id,
        name: name,
        lifecycleState: lifecycleState,
        channelSwitchEnabled: channelSwitchEnabled ?? this.channelSwitchEnabled,
        videoSound: videoSound ?? this.videoSound,
        avatarPath: avatarPath,
        currentChannelId: currentChannelId,
        pairingCode: pairingCode,
        pairingCodeExpiresAt: pairingCodeExpiresAt,
        currentAppVersion: currentAppVersion,
        lastSeenAt: lastSeenAt,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        deviceModel: deviceModel,
        playback: playback,
      );
  bool get isPending => lifecycleState == 'pending';

  factory SmileFrame.fromJson(Map<String, dynamic> json) => SmileFrame(
        id: json['id'] as String,
        name: json['name'] as String,
        lifecycleState: json['lifecycle_state'] as String,
        channelSwitchEnabled: json['channel_switch_enabled'] as bool? ?? false,
        videoSound: json['video_sound'] as bool? ?? true,
        avatarPath: json['avatar_path'] as String?,
        currentChannelId: json['current_channel_id'] as String?,
        pairingCode: json['pairing_code'] as String?,
        pairingCodeExpiresAt:
            json['pairing_code_expires_at'] != null ? DateTime.parse(json['pairing_code_expires_at'] as String) : null,
        currentAppVersion: json['current_app_version'] as String?,
        lastSeenAt: json['last_seen_at'] != null ? DateTime.parse(json['last_seen_at'] as String) : null,
        batteryLevel: json['battery_level'] as int?,
        isCharging: json['is_charging'] as bool?,
        deviceModel: json['device_model'] as String?,
        playback: {
          for (final key in FrameService.playbackColumns)
            if (json.containsKey(key)) key: json[key],
          if (json.containsKey('unlock_code_hash')) 'unlock_code_hash': json['unlock_code_hash'],
        },
      );
}

/// A Frame on the "Frames" tab: with its Space and what it shows.
class ManagedFrame {
  const ManagedFrame({
    required this.frame,
    required this.spaceId,
    required this.spaceName,
    this.currentAlbumName,
    this.asFrameAdmin = false,
  });

  final SmileFrame frame;
  final String spaceId;
  final String spaceName;
  final String? currentAlbumName;

  /// Only Frame-Admin of it (migrations/0089), not a manager of its Space.
  final bool asFrameAdmin;
}

/// A person who is Frame-Admin of a Frame, or invited to be.
class FrameAdminPerson {
  const FrameAdminPerson({required this.userId, this.name, this.avatarUrl, this.inviteId});

  final String userId;
  final String? name;
  final String? avatarUrl;

  /// Set for an invite not yet answered.
  final String? inviteId;

  factory FrameAdminPerson.fromJson(Map<String, dynamic> json) => FrameAdminPerson(
        userId: json['user_id'] as String,
        name: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        inviteId: json['id'] as String?,
      );
}

/// Who is Frame-Admin of a Frame, and what the caller is there.
class FrameAdmins {
  const FrameAdmins({
    required this.admins,
    required this.pending,
    required this.callerManagesSpace,
    required this.callerIsFrameAdmin,
  });

  final List<FrameAdminPerson> admins;
  final List<FrameAdminPerson> pending;
  final bool callerManagesSpace;
  final bool callerIsFrameAdmin;
}

/// An invite to become Frame-Admin, waiting for the caller's answer.
class MyFrameAdminInvite {
  const MyFrameAdminInvite({
    required this.id,
    required this.frameId,
    required this.frameName,
    this.spaceName,
    this.inviterName,
    this.inviterAvatarUrl,
  });

  final String id;
  final String frameId;
  final String frameName;
  final String? spaceName;
  final String? inviterName;
  final String? inviterAvatarUrl;

  factory MyFrameAdminInvite.fromJson(Map<String, dynamic> json) => MyFrameAdminInvite(
        id: json['id'] as String,
        frameId: json['frame_id'] as String,
        frameName: json['frame_name'] as String? ?? '',
        spaceName: json['space_name'] as String?,
        inviterName: json['inviter_display_name'] as String?,
        inviterAvatarUrl: json['inviter_avatar_url'] as String?,
      );
}

/// One of a Frame's Lieblingsbilder (migrations/0076): the photo/video,
/// who marked it (null name and [onFrame]: on the Frame itself) and when.
class FrameFavorite {
  const FrameFavorite({required this.item, required this.onFrame, required this.markedAt, this.markedByName});

  final MediaItem item;
  final bool onFrame;
  final String? markedByName;
  final DateTime markedAt;
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
  /// Control level and playback (migrations/0075).
  static const playbackColumns = [
    'control_level', 'controls', 'content_mode', 'recent_count', 'play_order', 'end_behavior', 'slideshow_interval_seconds',
    'show_new_immediately', 'show_clock', 'show_sender', 'quiet_from', 'quiet_to', 'playing_round',
    'video_length', 'fill_mode', 'slow_zoom', 'rotate_with_device', 'show_captions',
    'new_sound', 'new_sound_reminder', 'new_hint', 'easy_stop', 'pause_zoom',
  ];

  static final _frameColumns = 'id, name, lifecycle_state, channel_switch_enabled, video_sound, avatar_path, current_channel_id, pairing_code, '
      'pairing_code_expires_at, current_app_version, last_seen_at, battery_level, is_charging, device_model, unlock_code_hash, '
      '${playbackColumns.join(', ')}';

  Future<List<SmileFrame>> listFrames(String spaceId) async {
    final rows = await supabase.from('frames').select(_frameColumns).eq('space_id', spaceId).order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(SmileFrame.fromJson).toList();
  }

  /// Every Frame the caller manages, across Spaces (RLS) -- the "Frames"
  /// tab (2026-10-11), with the name of the album each shows right now.
  Future<List<ManagedFrame>> listMyFrames() async {
    final rows = await supabase
        .from('frames')
        .select('$_frameColumns, space_id, spaces(name), current:channels!frames_current_channel_id_fkey(name)')
        .neq('lifecycle_state', 'revoked')
        .order('created_at');
    final list = (rows as List).cast<Map<String, dynamic>>();
    // A Frame-Admin cannot open the Frame's Space (migrations/0089): its
    // name comes separately.
    final missing = [for (final row in list) if (row['spaces'] == null) row['id'] as String];
    final names = await _spaceNames(missing);
    return list.map((row) {
      return ManagedFrame(
        frame: SmileFrame.fromJson(row),
        spaceId: row['space_id'] as String,
        spaceName: (row['spaces'] as Map?)?['name'] as String? ?? names[row['id']] ?? '',
        currentAlbumName: (row['current'] as Map?)?['name'] as String?,
        asFrameAdmin: row['spaces'] == null,
      );
    }).toList();
  }

  Future<Map<String, String>> _spaceNames(List<String> frameIds) async {
    if (frameIds.isEmpty) return const {};
    try {
      final rows = await supabase.rpc('my_frame_space_names', params: {'p_frames': frameIds});
      return {
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['frame_id'] as String: row['space_name'] as String? ?? '',
      };
    } catch (_) {
      return const {};
    }
  }

  /// The Spaces the caller manages (Admin or Co-Admin) -- where a new
  /// Frame can be set up.
  Future<List<({String id, String name})>> listManagedSpaces() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return const [];
    final results = await Future.wait<dynamic>([
      supabase.from('spaces').select('id, name').eq('owner_id', userId).isFilter('deleted_at', null),
      supabase.from('space_co_owners').select('spaces!inner(id, name, deleted_at)').eq('user_id', userId),
    ]);
    final byId = <String, String>{};
    for (final row in (results[0] as List).cast<Map<String, dynamic>>()) {
      byId[row['id'] as String] = row['name'] as String;
    }
    for (final row in (results[1] as List).cast<Map<String, dynamic>>()) {
      final space = row['spaces'] as Map<String, dynamic>;
      if (space['deleted_at'] == null) byId[space['id'] as String] = space['name'] as String;
    }
    return [for (final e in byId.entries) (id: e.key, name: e.value)];
  }

  Future<SmileFrame> getFrame(String frameId) async {
    final row = await supabase.from('frames').select(_frameColumns).eq('id', frameId).single();
    return SmileFrame.fromJson(row);
  }

  /// A Frame plus its Space -- for opening the Frame page from somewhere
  /// other than its Space (the album page's "Läuft auf").
  Future<({SmileFrame frame, String spaceId, String spaceName})> getFrameWithSpace(String frameId) async {
    final row = await supabase.from('frames').select('$_frameColumns, space_id, spaces(name)').eq('id', frameId).single();
    final spaceName = (row['spaces'] as Map?)?['name'] as String? ?? (await _spaceNames([frameId]))[frameId] ?? '';
    return (frame: SmileFrame.fromJson(row), spaceId: row['space_id'] as String, spaceName: spaceName);
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
    LocalChanges.saved(tablesChanged({'frames'}, spaceIds: {spaceId}));
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
    LocalChanges.saved(tablesChanged({'frames'}));
  }

  /// The album switch is one of the Frame's controls (migrations/0075):
  /// changing it here changes the switch there too, and the level.
  Future<void> setChannelSwitchEnabled({required String frameId, required bool enabled}) async {
    final row = await supabase.from('frames').select('controls').eq('id', frameId).single();
    final controls = {
      for (final e in ((row['controls'] as Map?) ?? const {}).entries) e.key as String: e.value == true,
      'album': enabled,
    };
    await supabase.from('frames').update(FrameControlLevels.update(controls)).eq('id', frameId);
  }

  /// For good (delete-frame): the Frame's Space Admin or a Co-Admin. The
  /// tablet is woken and drops back to the pairing screen.
  Future<void> deleteFrame(String frameId) async {
    final response = await invokeEdge('delete-frame', body: {'frame_id': frameId});
    final data = response.data as Map<String, dynamic>?;
    if (data?['status'] != 'deleted') throw FrameServiceException(data?['error'] as String? ?? 'unknown_error');
    LocalChanges.saved(tablesChanged({'frames', 'frame_channels'}));
  }

  /// "Jetzt zeigen": the Frame switches to this album (it is woken by the
  /// frames change and syncs it).
  /// Choosing an album means: show this one -- also when the Frame played
  /// all albums in turn or the newest (2026-10-14).
  Future<void> showChannelNow({required String frameId, required String channelId}) async {
    await supabase.from('frames').update({'current_channel_id': channelId, 'content_mode': 'album'}).eq('id', frameId);
  }

  Future<void> setVideoSound({required String frameId, required bool enabled}) async {
    await supabase.from('frames').update({'video_sound': enabled}).eq('id', frameId);
  }

  /// Any of the Frame's display settings (control level, playback); the
  /// Frame is woken by the change and takes it over at once.
  Future<void> updateSettings({required String frameId, required Map<String, dynamic> changes}) async {
    await supabase.from('frames').update(changes).eq('id', frameId);
  }

  // --- Frame-Admin (migrations/0089) ------------------------------------

  Future<FrameAdmins> listFrameAdmins(String frameId) async {
    final response = await invokeEdge('list-frame-admins', body: {'frame_id': frameId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw FrameServiceException(data['error'] as String);
    List<FrameAdminPerson> people(String key) =>
        (data[key] as List).cast<Map<String, dynamic>>().map(FrameAdminPerson.fromJson).toList();
    return FrameAdmins(
      admins: people('frame_admins'),
      pending: people('pending_invites'),
      callerManagesSpace: data['caller_manages_space'] as bool? ?? false,
      callerIsFrameAdmin: data['caller_is_frame_admin'] as bool? ?? false,
    );
  }

  /// The Space's Admin or a Co-Admin invites -- the invitee decides.
  Future<void> inviteFrameAdmin({required String frameId, String? userId, String? email}) async {
    final response = await invokeEdge('invite-frame-admin', body: {'frame_id': frameId, 'user_id': ?userId, 'email': ?email});
    final data = response.data as Map<String, dynamic>?;
    final status = data?['status'] as String?;
    if (status != 'invited' && status != 'already_frame_admin') {
      throw FrameServiceException(data?['error'] as String? ?? 'unknown_error');
    }
    LocalChanges.saved(tablesChanged({'frame_admin_invites'}));
  }

  Future<void> withdrawFrameAdminInvite(String inviteId) async {
    await supabase.from('frame_admin_invites').delete().eq('id', inviteId);
    LocalChanges.saved(tablesChanged({'frame_admin_invites'}));
  }

  /// Ended by the Space's managers, or given up by the Frame-Admin.
  Future<void> removeFrameAdmin({required String frameId, required String userId}) async {
    await supabase.from('frame_admins').delete().eq('frame_id', frameId).eq('user_id', userId);
    LocalChanges.saved(tablesChanged({'frame_admins', 'frames'}));
  }

  Future<List<MyFrameAdminInvite>> listMyFrameAdminInvites() async {
    final response = await invokeEdge('list-my-frame-admin-invites');
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw FrameServiceException(data['error'] as String);
    return (data['invites'] as List).cast<Map<String, dynamic>>().map(MyFrameAdminInvite.fromJson).toList();
  }

  /// Only the invitee decides; accepting makes the frame_admins row (trigger).
  Future<void> decideFrameAdminInvite(String inviteId, {required bool accept}) async {
    await supabase.from('frame_admin_invites').update({'status': accept ? 'accepted' : 'declined'}).eq('id', inviteId);
    LocalChanges.saved(tablesChanged({'frame_admin_invites', 'frame_admins', 'frames'}));
  }

  /// The code that unlocks every button on the Frame itself (Kindersperre):
  /// only its hash is stored -- the Frame compares the same hash.
  Future<void> setUnlockCode({required String frameId, required String code}) async {
    await supabase.from('frames').update({'unlock_code_hash': unlockCodeHash(frameId, code)}).eq('id', frameId);
    LocalChanges.saved(tablesChanged({'frames'}));
  }

  /// No code any more: nothing to unlock on the Frame, as before the first.
  Future<void> removeUnlockCode(String frameId) async {
    await supabase.from('frames').update({'unlock_code_hash': null}).eq('id', frameId);
    LocalChanges.saved(tablesChanged({'frames'}));
  }

  /// sha256 of `<frame id>:<code>`, hex -- the same on the Frame
  /// (frame/services/unlock_code.dart).
  static String unlockCodeHash(String frameId, String code) => sha256.convert(utf8.encode('$frameId:$code')).toString();

  /// A Frame's Lieblingsbilder, newest marked first (list-frame-favorites).
  Future<List<FrameFavorite>> listFavorites(String frameId) async {
    final response = await invokeEdge('list-frame-favorites', body: {'frame_id': frameId});
    final items = ((response.data as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
    return [
      for (final row in items)
        FrameFavorite(
          item: MediaItem.fromJson(row['media'] as Map<String, dynamic>),
          onFrame: row['added_by'] == null,
          markedByName: row['added_by_name'] as String?,
          markedAt: DateTime.parse(row['favorited_at'] as String),
        ),
    ];
  }

  /// Which photos are Lieblingsbilder of which of these Frames
  /// (media id -> Frame ids) -- for the heart in the viewers.
  Future<Map<String, Set<String>>> favoritesOf(List<String> frameIds) async {
    if (frameIds.isEmpty) return const {};
    final rows = await supabase.from('frame_favorites').select('frame_id, media_item_id').inFilter('frame_id', frameIds);
    final result = <String, Set<String>>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      result.putIfAbsent(row['media_item_id'] as String, () => {}).add(row['frame_id'] as String);
    }
    return result;
  }

  /// A Lieblingsbild added in the app (the Frame is woken by it).
  Future<void> addFavorite({required String frameId, required String mediaItemId}) async {
    await supabase.from('frame_favorites').upsert(
      {'frame_id': frameId, 'media_item_id': mediaItemId, 'added_by': supabase.auth.currentUser?.id},
      onConflict: 'frame_id,media_item_id',
      ignoreDuplicates: true,
    );
  }

  /// Several at once -- or all of them ([mediaItemIds] null).
  Future<void> removeFavorites({required String frameId, List<String>? mediaItemIds}) async {
    var query = supabase.from('frame_favorites').delete().eq('frame_id', frameId);
    if (mediaItemIds != null) query = query.inFilter('media_item_id', mediaItemIds);
    await query;
  }

  /// The app's remote control (notify-frame, 2026-10-14): "pause", "play",
  /// "next", "back", "newest", or "show" with [mediaItemId].
  Future<void> sendCommand({required String frameId, required String command, String? mediaItemId}) async {
    await invokeEdge('notify-frame', body: {'frame_id': frameId, 'command': command, 'media_item_id': ?mediaItemId});
  }

  Future<List<FrameChannelAssignment>> listAssignedChannels(String frameId) async {
    final rows = await supabase
        .from('frame_channels')
        .select('channel_id, channels(name)')
        .eq('frame_id', frameId)
        // Same order as the Frame itself (frame_visible_channels).
        .order('sort_order')
        .order('created_at');
    // An album the caller may not see (e.g. in the trash, or someone
    // else's) comes without its channel row -- left out, like on the Frame.
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((row) => row['channels'] != null)
        .map((row) => FrameChannelAssignment(
              channelId: row['channel_id'] as String,
              channelName: (row['channels'] as Map<String, dynamic>)['name'] as String,
            ))
        .toList();
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

  /// The Frames this album could be put on from its page (2026-10-11):
  /// Frames of Spaces the caller manages (RLS) whose Space can view the
  /// album -- its own Space, or one it is shared with. Revoked ones don't
  /// count; the caller leaves out those it is already on.
  Future<List<({String frameId, String frameName, String? avatarPath, String spaceName})>> listFramesForAlbum(
    String channelId,
  ) async {
    final results = await Future.wait<dynamic>([
      supabase.from('channels').select('space_id').eq('id', channelId).maybeSingle(),
      supabase.from('channel_shares').select('space_id').eq('channel_id', channelId),
      supabase.from('frames').select('id, name, avatar_path, space_id, lifecycle_state, spaces(name)').order('created_at'),
    ]);
    final home = (results[0] as Map<String, dynamic>?)?['space_id'] as String?;
    final spaces = {
      ?home,
      for (final row in (results[1] as List).cast<Map<String, dynamic>>()) row['space_id'] as String,
    };
    return (results[2] as List)
        .cast<Map<String, dynamic>>()
        .where((r) => spaces.contains(r['space_id']) && r['lifecycle_state'] != 'revoked')
        .map((r) => (
              frameId: r['id'] as String,
              frameName: r['name'] as String,
              avatarPath: r['avatar_path'] as String?,
              spaceName: (r['spaces'] as Map?)?['name'] as String? ?? '',
            ))
        .toList();
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
    LocalChanges.saved(tablesChanged({'frame_channels', 'frames'}, channelIds: {channelId}));
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
