import 'avatar_upload.dart';
import '../main.dart';

class SmileGroup {
  SmileGroup({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;

  factory SmileGroup.fromJson(Map<String, dynamic> json) => SmileGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarUrl: avatarPathToUrl(json['avatar_path'] as String?),
      );
}

class GroupMember {
  GroupMember({required this.id, required this.userId, required this.email, required this.displayName, required this.avatarUrl});

  final String id;
  final String userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  String get label => displayName ?? email ?? userId;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        email: json['email'] as String?,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class MyGroupMembership {
  MyGroupMembership({
    required this.groupId,
    required this.groupName,
    required this.groupAvatarUrl,
    required this.ownerEmail,
    required this.ownerDisplayName,
    required this.channels,
  });

  final String groupId;
  final String groupName;
  final String? groupAvatarUrl;
  final String? ownerEmail;
  final String? ownerDisplayName;
  final List<GrantedChannelSummary> channels;

  String get ownerLabel => ownerDisplayName ?? ownerEmail ?? '';

  factory MyGroupMembership.fromJson(Map<String, dynamic> json) => MyGroupMembership(
        groupId: json['group_id'] as String,
        groupName: json['group_name'] as String,
        groupAvatarUrl: json['group_avatar_url'] as String?,
        ownerEmail: json['owner_email'] as String?,
        ownerDisplayName: json['owner_display_name'] as String?,
        channels: (json['channels'] as List)
            .cast<Map<String, dynamic>>()
            .map(GrantedChannelSummary.fromJson)
            .toList(),
      );
}

class GrantedChannelSummary {
  GrantedChannelSummary({required this.channelName, required this.spaceNames});

  final String? channelName;
  // A channel can be linked to more than one Space now -- shown joined
  // ("Oma, Opa") wherever this was a single string before.
  final List<String> spaceNames;

  String get spaceLabel => spaceNames.join(', ');

  factory GrantedChannelSummary.fromJson(Map<String, dynamic> json) => GrantedChannelSummary(
        channelName: json['channel_name'] as String?,
        spaceNames: (json['space_names'] as List?)?.cast<String>() ?? const [],
      );
}

class GrantableChannel {
  GrantableChannel({required this.channelId, required this.channelName, required this.spaceNames});

  final String channelId;
  final String channelName;
  final List<String> spaceNames;

  String get spaceLabel => spaceNames.join(', ');
}

class GroupGrant {
  GroupGrant({
    required this.grantId,
    required this.channelId,
    required this.channelName,
    required this.spaceNames,
  });

  final String grantId;
  final String channelId;
  final String channelName;
  final List<String> spaceNames;

  String get spaceLabel => spaceNames.join(', ');
}

/// Phase 6b: a personal, creator-owned distribution list of people that can
/// be granted contributor access to any number of channels the creator
/// administers, across any number of Spaces -- add someone once, they gain
/// access everywhere the group is already granted (see
/// migrations/0020_groups.sql's trigger, which materializes this into real
/// channel_memberships rows; nothing here needs to know about permissions
/// beyond that, since every existing rule already keys off that table).
class GroupService {
  Future<List<SmileGroup>> listMyGroups() async {
    final rows = await supabase.from('groups').select('id, name, avatar_path').order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(SmileGroup.fromJson).toList();
  }

  /// Optional -- SmileAvatar's initials fallback already satisfies "every
  /// group needs at least a profile picture" on its own, this just lets
  /// the owner replace it with a real photo.
  Future<String?> uploadGroupAvatarFromCamera(String groupId) =>
      _setGroupAvatar(groupId, pickAndUploadFromCamera('groups/$groupId'));

  Future<String?> uploadGroupAvatarFromGallery(String groupId) =>
      _setGroupAvatar(groupId, pickAndUploadFromGallery('groups/$groupId'));

  Future<String?> uploadGroupAvatarFromUrl(String groupId, String url) =>
      _setGroupAvatar(groupId, uploadAvatarFromUrl('groups/$groupId', url));

  Future<String?> _setGroupAvatar(String groupId, Future<String?> upload) async {
    final path = await upload;
    if (path == null) return null;
    await supabase.from('groups').update({'avatar_path': path}).eq('id', groupId);
    return avatarPathToUrl(path);
  }

  /// Read-only visibility into groups the caller is a *member* of (as
  /// opposed to [listMyGroups], which only ever returns groups they own) --
  /// otherwise a member has no way to discover a group exists, or why
  /// they suddenly have access to some channel. No management capability
  /// comes with this; that stays owner-only.
  Future<List<MyGroupMembership>> listMyGroupMemberships() async {
    final response = await supabase.functions.invoke('list-my-group-memberships');
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw GroupServiceException(data['error'] as String);
    final memberships = (data['memberships'] as List).cast<Map<String, dynamic>>();
    return memberships.map(MyGroupMembership.fromJson).toList();
  }

  /// Self-service leave (migrations/0026_self_service_leave.sql) -- deletes
  /// the caller's own group_members row, which fires the same reconcile
  /// trigger an owner's removal would (migrations/0020_groups.sql), so
  /// every channel that group granted is cleaned up automatically.
  Future<void> leaveGroup(String groupId) async {
    await supabase.from('group_members').delete().eq('group_id', groupId).eq('user_id', supabase.auth.currentUser!.id);
  }

  Future<SmileGroup> createGroup(String name) async {
    final row = await supabase
        .from('groups')
        .insert({'name': name, 'owner_id': supabase.auth.currentUser!.id})
        .select()
        .single();
    return SmileGroup.fromJson(row);
  }

  Future<void> deleteGroup(String groupId) async {
    await supabase.from('groups').delete().eq('id', groupId);
  }

  Future<List<GroupMember>> listGroupMembers(String groupId) async {
    final response = await supabase.functions.invoke('list-group-members', body: {'group_id': groupId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw GroupServiceException(data['error'] as String);
    final members = (data['members'] as List).cast<Map<String, dynamic>>();
    return members.map(GroupMember.fromJson).toList();
  }

  Future<void> addGroupMember({required String groupId, required String email}) async {
    final response = await supabase.functions.invoke('add-group-member', body: {
      'group_id': groupId,
      'email': email,
    });
    final data = response.data as Map<String, dynamic>?;
    final status = data?['status'] as String?;
    if (status != 'added' && status != 'already_member') {
      throw GroupServiceException(data?['error'] as String? ?? 'unknown_error');
    }
  }

  Future<void> removeGroupMember(String memberRowId) async {
    await supabase.from('group_members').delete().eq('id', memberRowId);
  }

  /// A channel can now be linked to more than one Space (space_channels) --
  /// this replaces the single nested `channels(spaces(name))`/`spaces(name)`
  /// embeds that relied on the old channels.space_id FK with an explicit
  /// lookup, returning every linked Space's name per channel.
  Future<Map<String, List<String>>> _spaceNamesByChannel(List<String> channelIds) async {
    if (channelIds.isEmpty) return {};
    final rows =
        await supabase.from('space_channels').select('channel_id, spaces(name)').inFilter('channel_id', channelIds);
    final result = <String, List<String>>{};
    for (final row in rows) {
      final channelId = row['channel_id'] as String;
      final space = row['spaces'] as Map<String, dynamic>?;
      if (space == null) continue;
      (result[channelId] ??= []).add(space['name'] as String);
    }
    return result;
  }

  /// Channels this user personally administers (channel_admin directly, or
  /// space_owner of any Space the channel is linked to) -- the only
  /// channels they're allowed to grant a group access to (mirrors
  /// group_channel_grants' RLS).
  Future<List<GrantableChannel>> listGrantableChannels() async {
    final asAdmin =
        await supabase.from('channel_memberships').select('channel_id, channels(name)').eq('role', 'channel_admin');
    final ownedSpaceIds =
        (await supabase.from('space_owners').select('space_id')).map((row) => row['space_id'] as String).toList();
    final asOwner = ownedSpaceIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await supabase.from('space_channels').select('channel_id, channels(name)').inFilter(
            'space_id', ownedSpaceIds);

    final channelIds = {
      ...asAdmin.map((r) => r['channel_id'] as String),
      ...asOwner.map((r) => r['channel_id'] as String),
    }.toList();
    final spaceNames = await _spaceNamesByChannel(channelIds);

    final byChannelId = <String, GrantableChannel>{};
    for (final row in [...asAdmin, ...asOwner]) {
      final channelId = row['channel_id'] as String;
      final channel = row['channels'] as Map<String, dynamic>;
      byChannelId[channelId] = GrantableChannel(
        channelId: channelId,
        channelName: channel['name'] as String,
        spaceNames: spaceNames[channelId] ?? const [],
      );
    }
    return byChannelId.values.toList();
  }

  Future<List<GroupGrant>> listGrants(String groupId) async {
    final rows =
        await supabase.from('group_channel_grants').select('id, channel_id, channels(name)').eq('group_id', groupId);
    final channelIds = rows.map((r) => r['channel_id'] as String).toList();
    final spaceNames = await _spaceNamesByChannel(channelIds);
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final channel = row['channels'] as Map<String, dynamic>;
      final channelId = row['channel_id'] as String;
      return GroupGrant(
        grantId: row['id'] as String,
        channelId: channelId,
        channelName: channel['name'] as String,
        spaceNames: spaceNames[channelId] ?? const [],
      );
    }).toList();
  }

  Future<void> grantChannel({required String groupId, required String channelId}) async {
    await supabase.from('group_channel_grants').insert({
      'group_id': groupId,
      'channel_id': channelId,
      'granted_by': supabase.auth.currentUser!.id,
    });
  }

  Future<void> revokeGrant(String grantId) async {
    await supabase.from('group_channel_grants').delete().eq('id', grantId);
  }
}

class GroupServiceException implements Exception {
  GroupServiceException(this.code);

  final String code;

  String get message => switch (code) {
        'user_not_found' => 'Diese Person hat noch keinen Smile-Account.',
        'not_group_owner' => 'Du bist nicht berechtigt, diese Gruppe zu verwalten.',
        _ => 'Aktion fehlgeschlagen.',
      };

  @override
  String toString() => 'GroupServiceException($code)';
}
