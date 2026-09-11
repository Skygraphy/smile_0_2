import '../main.dart';

class SmileGroup {
  SmileGroup({required this.id, required this.name});

  final String id;
  final String name;

  factory SmileGroup.fromJson(Map<String, dynamic> json) =>
      SmileGroup(id: json['id'] as String, name: json['name'] as String);
}

class GroupMember {
  GroupMember({required this.id, required this.userId, required this.email});

  final String id;
  final String userId;
  final String? email;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        email: json['email'] as String?,
      );
}

class MyGroupMembership {
  MyGroupMembership({
    required this.groupId,
    required this.groupName,
    required this.ownerEmail,
    required this.channels,
  });

  final String groupId;
  final String groupName;
  final String? ownerEmail;
  final List<GrantedChannelSummary> channels;

  factory MyGroupMembership.fromJson(Map<String, dynamic> json) => MyGroupMembership(
        groupId: json['group_id'] as String,
        groupName: json['group_name'] as String,
        ownerEmail: json['owner_email'] as String?,
        channels: (json['channels'] as List)
            .cast<Map<String, dynamic>>()
            .map(GrantedChannelSummary.fromJson)
            .toList(),
      );
}

class GrantedChannelSummary {
  GrantedChannelSummary({required this.channelName, required this.spaceName});

  final String? channelName;
  final String? spaceName;

  factory GrantedChannelSummary.fromJson(Map<String, dynamic> json) => GrantedChannelSummary(
        channelName: json['channel_name'] as String?,
        spaceName: json['space_name'] as String?,
      );
}

class GrantableChannel {
  GrantableChannel({required this.channelId, required this.channelName, required this.spaceName});

  final String channelId;
  final String channelName;
  final String spaceName;
}

class GroupGrant {
  GroupGrant({
    required this.grantId,
    required this.channelId,
    required this.channelName,
    required this.spaceName,
  });

  final String grantId;
  final String channelId;
  final String channelName;
  final String spaceName;
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
    final rows = await supabase.from('groups').select('id, name').order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map(SmileGroup.fromJson).toList();
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

  /// Channels this user personally administers (channel_admin directly, or
  /// space_owner of the channel's Space) -- the only channels they're
  /// allowed to grant a group access to (mirrors group_channel_grants' RLS).
  Future<List<GrantableChannel>> listGrantableChannels() async {
    final asAdmin = await supabase
        .from('channel_memberships')
        .select('channel_id, channels(name, spaces(name))')
        .eq('role', 'channel_admin');
    final ownedSpaceIds = (await supabase.from('space_owners').select('space_id'))
        .map((row) => row['space_id'] as String)
        .toList();
    final asOwner = ownedSpaceIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await supabase.from('channels').select('id, name, spaces(name)').inFilter('space_id', ownedSpaceIds);

    final byChannelId = <String, GrantableChannel>{};
    for (final row in asAdmin) {
      final channel = row['channels'] as Map<String, dynamic>;
      final space = channel['spaces'] as Map<String, dynamic>;
      byChannelId[row['channel_id'] as String] = GrantableChannel(
        channelId: row['channel_id'] as String,
        channelName: channel['name'] as String,
        spaceName: space['name'] as String,
      );
    }
    for (final row in asOwner) {
      final space = row['spaces'] as Map<String, dynamic>;
      byChannelId[row['id'] as String] = GrantableChannel(
        channelId: row['id'] as String,
        channelName: row['name'] as String,
        spaceName: space['name'] as String,
      );
    }
    return byChannelId.values.toList();
  }

  Future<List<GroupGrant>> listGrants(String groupId) async {
    final rows = await supabase
        .from('group_channel_grants')
        .select('id, channel_id, channels(name, spaces(name))')
        .eq('group_id', groupId);
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final channel = row['channels'] as Map<String, dynamic>;
      final space = channel['spaces'] as Map<String, dynamic>;
      return GroupGrant(
        grantId: row['id'] as String,
        channelId: row['channel_id'] as String,
        channelName: channel['name'] as String,
        spaceName: space['name'] as String,
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
