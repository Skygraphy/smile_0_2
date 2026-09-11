import 'dart:math';

import '../main.dart';

class ChannelMember {
  ChannelMember({
    required this.membershipId,
    required this.userId,
    required this.email,
    required this.role,
    required this.viaGroupName,
  });

  final String membershipId;
  final String userId;
  final String? email;
  final String role;
  // Set when this row exists because of a Phase 6b group grant (see
  // migrations/0020_groups.sql), not a direct invite/add -- null otherwise.
  final String? viaGroupName;

  bool get isGroupDerived => viaGroupName != null;

  factory ChannelMember.fromJson(Map<String, dynamic> json) => ChannelMember(
        membershipId: json['membership_id'] as String,
        userId: json['user_id'] as String,
        email: json['email'] as String?,
        role: json['role'] as String,
        viaGroupName: json['via_group_name'] as String?,
      );
}

class SpaceMemberCandidate {
  SpaceMemberCandidate({required this.userId, required this.email});

  final String userId;
  final String? email;

  factory SpaceMemberCandidate.fromJson(Map<String, dynamic> json) => SpaceMemberCandidate(
        userId: json['user_id'] as String,
        email: json['email'] as String?,
      );
}

class ChannelInvite {
  ChannelInvite({required this.id, required this.code, required this.expiresAt});

  final String id;
  final String code;
  final DateTime expiresAt;

  factory ChannelInvite.fromJson(Map<String, dynamic> json) => ChannelInvite(
        id: json['id'] as String,
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

class ChannelRoster {
  ChannelRoster({
    required this.members,
    required this.spaceId,
    required this.callerIsAdmin,
    required this.callerIsSpaceOwner,
  });

  final List<ChannelMember> members;
  final String spaceId;
  final bool callerIsAdmin;
  final bool callerIsSpaceOwner;
}

enum ChannelJoinStatus { joined, alreadyMember, pendingApproval }

class ChannelJoinResult {
  ChannelJoinResult({required this.status, required this.channelId, required this.channelName});

  final ChannelJoinStatus status;
  final String channelId;
  final String channelName;
}

class JoinRequest {
  JoinRequest({required this.id, required this.email, required this.requestedAt});

  final String id;
  final String? email;
  final DateTime requestedAt;

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
        id: json['id'] as String,
        email: json['email'] as String?,
        requestedAt: DateTime.parse(json['requested_at'] as String),
      );
}

/// Member roster/role-management (list-channel-members, list-space-members)
/// and code-based channel invites (pairing_codes with code_type =
/// 'channel_invite', claim-channel-invite) -- see the Phase 6a plan for why
/// this deviates from the concept doc's email-invite text in favor of a
/// WhatsApp-style shareable code/QR, mirroring pair_frame_screen.dart's
/// existing Frame-pairing flow.
class MembershipService {
  static const _codeCharset = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _codeLength = 8;
  static const _inviteMaxUses = 20;
  static const _inviteValidity = Duration(days: 7);

  Future<ChannelRoster> listChannelMembers(String channelId) async {
    final response = await supabase.functions.invoke('list-channel-members', body: {'channel_id': channelId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MembershipServiceException(data['error'] as String);
    final members = (data['members'] as List).cast<Map<String, dynamic>>();
    return ChannelRoster(
      members: members.map(ChannelMember.fromJson).toList(),
      spaceId: data['space_id'] as String,
      callerIsAdmin: data['caller_is_admin'] as bool,
      callerIsSpaceOwner: data['caller_is_space_owner'] as bool,
    );
  }

  Future<List<SpaceMemberCandidate>> listAddableSpaceMembers({
    required String spaceId,
    required String excludeChannelId,
  }) async {
    final response = await supabase.functions.invoke('list-space-members', body: {
      'space_id': spaceId,
      'exclude_channel_id': excludeChannelId,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MembershipServiceException(data['error'] as String);
    final candidates = (data['candidates'] as List).cast<Map<String, dynamic>>();
    return candidates.map(SpaceMemberCandidate.fromJson).toList();
  }

  Future<void> updateMemberRole(String membershipId, String role) async {
    await supabase.from('channel_memberships').update({'role': role}).eq('id', membershipId);
  }

  Future<void> removeMember(String membershipId) async {
    await supabase.from('channel_memberships').delete().eq('id', membershipId);
  }

  /// Self-service leave (migrations/0026_self_service_leave.sql) -- RLS
  /// only allows this for a direct membership (`via_group_id is null`);
  /// leaving a group-derived one has to happen via [GroupService.leaveGroup]
  /// instead, same reasoning as why channel_members_screen.dart hides the
  /// admin "Entfernen" action for those rows.
  Future<void> leaveChannel(String membershipId) async {
    await supabase.from('channel_memberships').delete().eq('id', membershipId);
  }

  Future<void> addExistingMember({
    required String channelId,
    required String userId,
    required String role,
  }) async {
    await supabase.from('channel_memberships').insert({
      'channel_id': channelId,
      'user_id': userId,
      'role': role,
    });
  }

  Future<ChannelInvite> createChannelInvite({
    required String spaceId,
    required String channelId,
    bool requiresApproval = false,
  }) async {
    final random = Random.secure();
    final code = List.generate(_codeLength, (_) => _codeCharset[random.nextInt(_codeCharset.length)]).join();
    final expiresAt = DateTime.now().toUtc().add(_inviteValidity);
    final row = await supabase
        .from('pairing_codes')
        .insert({
          'space_id': spaceId,
          'channel_id': channelId,
          'code': code,
          'code_type': 'channel_invite',
          'expires_at': expiresAt.toIso8601String(),
          'max_uses': _inviteMaxUses,
          'requires_approval': requiresApproval,
        })
        .select()
        .single();
    return ChannelInvite.fromJson(row);
  }

  Future<void> revokeInvite(String pairingCodeId) async {
    await supabase.from('pairing_codes').delete().eq('id', pairingCodeId);
  }

  Future<ChannelJoinResult> joinChannelWithCode(String code) async {
    final response = await supabase.functions.invoke('claim-channel-invite', body: {'code': code});
    final data = response.data as Map<String, dynamic>?;
    final status = switch (data?['status'] as String?) {
      'joined' => ChannelJoinStatus.joined,
      'already_member' => ChannelJoinStatus.alreadyMember,
      'pending_approval' => ChannelJoinStatus.pendingApproval,
      _ => null,
    };
    if (status == null) {
      throw ChannelInviteException(data?['error'] as String? ?? 'unknown_error');
    }
    return ChannelJoinResult(
      status: status,
      channelId: data!['channel_id'] as String,
      channelName: data['channel_name'] as String,
    );
  }

  /// Pending "Beitrittsanfragen" (Phase 6c) for a channel the caller
  /// administers -- generated by someone redeeming a `requires_approval`
  /// invite code instead of joining outright.
  Future<List<JoinRequest>> listJoinRequests(String channelId) async {
    final response = await supabase.functions.invoke('list-channel-join-requests', body: {'channel_id': channelId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MembershipServiceException(data['error'] as String);
    final requests = (data['requests'] as List).cast<Map<String, dynamic>>();
    return requests.map(JoinRequest.fromJson).toList();
  }

  Future<void> decideJoinRequest(String requestId, {required bool approve}) async {
    final response = await supabase.functions.invoke('decide-channel-join-request', body: {
      'request_id': requestId,
      'decision': approve ? 'approve' : 'reject',
    });
    final data = response.data as Map<String, dynamic>?;
    if (data?['error'] != null) throw MembershipServiceException(data!['error'] as String);
  }
}

class MembershipServiceException implements Exception {
  MembershipServiceException(this.code);

  final String code;

  @override
  String toString() => 'MembershipServiceException($code)';
}

class ChannelInviteException implements Exception {
  ChannelInviteException(this.code);

  final String code;

  String get message => switch (code) {
        'invalid_code' => 'Ungültiger Code.',
        'code_expired' => 'Der Code ist abgelaufen.',
        'code_already_used' => 'Dieser Code wurde bereits zu oft verwendet.',
        _ => 'Beitreten fehlgeschlagen.',
      };

  @override
  String toString() => 'ChannelInviteException($code)';
}
