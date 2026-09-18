import '../main.dart';

class ChannelMember {
  ChannelMember({required this.userId, required this.displayName, required this.avatarUrl, required this.createdAt});

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  String get label => displayName ?? userId;

  factory ChannelMember.fromJson(Map<String, dynamic> json) => ChannelMember(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// A Space this channel is currently shared into (view-only) --
/// migrations/0031_architecture_reset.sql's `channel_shares`.
class SharedSpaceRef {
  SharedSpaceRef({required this.id, required this.name});

  final String id;
  final String name;

  factory SharedSpaceRef.fromJson(Map<String, dynamic> json) =>
      SharedSpaceRef(id: json['id'] as String, name: json['name'] as String);
}

class ChannelRoster {
  ChannelRoster({required this.members, required this.sharedSpaces, required this.callerIsSco});

  final List<ChannelMember> members;
  final List<SharedSpaceRef> sharedSpaces;
  final bool callerIsSco;
}

enum RequestKind { membership, share }

enum RequestDirection { invite, request }

/// One row from either `channel_membership_requests` (posting rights) or
/// `channel_share_requests` (view-only Space link) -- see
/// list-my-invites/index.ts, which resolves the channel name and the
/// counterpart's profile server-side (neither is visible to an invitee via
/// plain RLS before they've accepted, by design).
class ChannelRequest {
  ChannelRequest({
    required this.id,
    required this.kind,
    required this.channelId,
    required this.channelName,
    required this.counterpartUserId,
    required this.counterpartDisplayName,
    required this.counterpartAvatarUrl,
    required this.direction,
    required this.requestedAt,
    this.spaceId,
  });

  final String id;
  final RequestKind kind;
  final String channelId;
  final String? channelName;
  final String counterpartUserId;
  final String? counterpartDisplayName;
  final String? counterpartAvatarUrl;
  final RequestDirection direction;
  final DateTime requestedAt;
  // Share requests only -- the requester's own Space, already known for a
  // 'request'; null for an 'invite' until the invitee accepts.
  final String? spaceId;

  String get counterpartLabel => counterpartDisplayName ?? counterpartUserId;

  factory ChannelRequest.fromJson(Map<String, dynamic> json, RequestKind kind) => ChannelRequest(
        id: json['id'] as String,
        kind: kind,
        channelId: json['channel_id'] as String,
        channelName: json['channel_name'] as String?,
        counterpartUserId: json['counterpart_user_id'] as String,
        counterpartDisplayName: json['counterpart_display_name'] as String?,
        counterpartAvatarUrl: json['counterpart_avatar_url'] as String?,
        direction: json['direction'] == 'invite' ? RequestDirection.invite : RequestDirection.request,
        requestedAt: DateTime.parse(json['requested_at'] as String),
        spaceId: json['space_id'] as String?,
      );
}

/// The caller's own relationship to one channel -- powers
/// channel_feed_screen.dart's "Beitritt anfragen" affordance for someone
/// who can currently only *view* the channel (via a Space they own being
/// shared into it, see [SharedSpaceRef]) but never posted.
class MyChannelMembershipStatus {
  MyChannelMembershipStatus({required this.isMember, this.pendingRequestId});

  final bool isMember;
  // Set when the caller already has a pending self-initiated 'request'
  // row waiting on the SCO's decision -- lets the UI offer "withdraw"
  // instead of submitting a second one (which would violate the
  // partial-unique index anyway).
  final String? pendingRequestId;
}

class MyInvitesInbox {
  MyInvitesInbox({required this.membershipRequests, required this.shareRequests});

  final List<ChannelRequest> membershipRequests;
  final List<ChannelRequest> shareRequests;

  bool get isEmpty => membershipRequests.isEmpty && shareRequests.isEmpty;
}

/// Channel membership (posting rights) and view-only Space sharing, both
/// via the symmetric "Facebook friend request" invite/request/accept model
/// -- see migrations/0031_architecture_reset.sql. Deciding (accept/
/// decline) and self-initiated "request" rows are always plain,
/// RLS-governed table calls, never an Edge Function -- only the
/// email->user_id lookup an "invite" needs, and any read that has to cross
/// into another user's profile, requires one.
class MembershipService {
  Future<ChannelRoster> listChannelMembers(String channelId) async {
    final response = await supabase.functions.invoke('list-channel-members', body: {'channel_id': channelId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MembershipServiceException(data['error'] as String);
    final members = (data['members'] as List).cast<Map<String, dynamic>>();
    final sharedSpaces = (data['shared_spaces'] as List).cast<Map<String, dynamic>>();
    return ChannelRoster(
      members: members.map(ChannelMember.fromJson).toList(),
      sharedSpaces: sharedSpaces.map(SharedSpaceRef.fromJson).toList(),
      callerIsSco: data['caller_is_sco'] as bool,
    );
  }

  /// SCO-only (enforced server-side and by RLS on the resulting delete).
  Future<void> removeMember({required String channelId, required String userId}) async {
    await supabase.from('channel_members').delete().eq('channel_id', channelId).eq('user_id', userId);
  }

  /// Self-service leave -- a member removing their own row.
  Future<void> leaveChannel(String channelId) async {
    await supabase.from('channel_members').delete().eq('channel_id', channelId).eq(
        'user_id', supabase.auth.currentUser!.id);
  }

  /// SCO invites a known person (by email) to become a posting member.
  Future<void> inviteMember({required String channelId, required String email}) async {
    final response = await supabase.functions.invoke('invite-channel-member', body: {
      'channel_id': channelId,
      'email': email,
    });
    final data = response.data as Map<String, dynamic>?;
    final status = data?['status'] as String?;
    if (status != 'invited' && status != 'already_member') {
      throw ChannelRequestException(data?['error'] as String? ?? 'unknown_error');
    }
  }

  /// SCO invites a known person (by email) to view-share this channel with
  /// one of their own Spaces (which one is chosen by the invitee at
  /// accept time).
  Future<void> inviteShare({required String channelId, required String email}) async {
    final response = await supabase.functions.invoke('invite-channel-share', body: {
      'channel_id': channelId,
      'email': email,
    });
    final data = response.data as Map<String, dynamic>?;
    if (data?['status'] != 'invited') {
      throw ChannelRequestException(data?['error'] as String? ?? 'unknown_error');
    }
  }

  Future<void> decideMembershipRequest(String requestId, {required bool accept}) async {
    await supabase
        .from('channel_membership_requests')
        .update({'status': accept ? 'accepted' : 'declined'}).eq('id', requestId);
  }

  /// Deciding a share *invite* also supplies which of the caller's own
  /// Spaces to link, in the same call -- see
  /// channel_share_requests_decide's RLS. Deciding a *request* (the SCO's
  /// job) needs no [spaceId], it's already on the row.
  Future<void> decideShareRequest(String requestId, {required bool accept, String? spaceId}) async {
    await supabase.from('channel_share_requests').update({
      'status': accept ? 'accepted' : 'declined',
      'space_id': ?spaceId,
    }).eq('id', requestId);
  }

  /// A viewer (sees the channel only via a Space they own being shared
  /// into it) requesting posting rights for themselves -- the *other*
  /// symmetric half of [inviteMember]. A plain RLS-governed insert
  /// (channel_membership_requests_insert allows `direction = 'request'
  /// and user_id = auth.uid()` unconditionally), decided later by the
  /// channel's SCO via [decideMembershipRequest].
  Future<void> requestMembership(String channelId) async {
    await supabase.from('channel_membership_requests').insert({
      'channel_id': channelId,
      'user_id': supabase.auth.currentUser!.id,
      'direction': 'request',
    });
  }

  /// Whether the caller already posts here, or -- if not -- whether they
  /// already have a pending [requestMembership] waiting on the SCO.
  Future<MyChannelMembershipStatus> getMyMembershipStatus(String channelId) async {
    final userId = supabase.auth.currentUser!.id;
    final results = await Future.wait<dynamic>([
      supabase.from('channel_members').select('user_id').eq('channel_id', channelId).eq('user_id', userId),
      supabase
          .from('channel_membership_requests')
          .select('id')
          .eq('channel_id', channelId)
          .eq('user_id', userId)
          .eq('direction', 'request')
          .eq('status', 'pending'),
    ]);
    final memberRows = results[0] as List;
    final requestRows = results[1] as List;
    return MyChannelMembershipStatus(
      isMember: memberRows.isNotEmpty,
      pendingRequestId: requestRows.isNotEmpty ? requestRows.first['id'] as String : null,
    );
  }

  Future<void> withdrawMembershipRequest(String requestId) async {
    await supabase.from('channel_membership_requests').delete().eq('id', requestId);
  }

  Future<void> withdrawShareRequest(String requestId) async {
    await supabase.from('channel_share_requests').delete().eq('id', requestId);
  }

  /// The linked Space's owner unilaterally revoking their own share --
  /// channel_shares_owner_delete's RLS never lets the channel's own SCO
  /// block this.
  Future<void> revokeShare({required String channelId, required String spaceId}) async {
    await supabase.from('channel_shares').delete().eq('channel_id', channelId).eq('space_id', spaceId);
  }

  /// Every Space this channel is currently shared into, plus the channel's
  /// own name -- powers a Space owner's "Freigaben verwalten" screen (see
  /// spaces_screen.dart), which needs to work from the Space side, not the
  /// channel side, since only the linked Space's *own* owner may revoke.
  Future<List<SharedChannelSummary>> listSharedChannelsForSpace(String spaceId) async {
    final rows = await supabase.from('channel_shares').select('channel_id, channels(name)').eq('space_id', spaceId);
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final channel = row['channels'] as Map<String, dynamic>;
      return SharedChannelSummary(channelId: row['channel_id'] as String, channelName: channel['name'] as String);
    }).toList();
  }

  /// The caller's own personal inbox (no [channelId]), or -- for a
  /// channel's SCO -- every pending request/invite for that one channel
  /// (the admin view). See list-my-invites/index.ts for why this has to be
  /// an Edge Function: an invitee can't see the channel's own name via
  /// plain RLS before accepting.
  Future<MyInvitesInbox> listMyInvites({String? channelId}) async {
    final response = await supabase.functions.invoke('list-my-invites', body: {'channel_id': ?channelId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MembershipServiceException(data['error'] as String);
    final membershipRequests = (data['membership_requests'] as List).cast<Map<String, dynamic>>();
    final shareRequests = (data['share_requests'] as List).cast<Map<String, dynamic>>();
    return MyInvitesInbox(
      membershipRequests: membershipRequests.map((r) => ChannelRequest.fromJson(r, RequestKind.membership)).toList(),
      shareRequests: shareRequests.map((r) => ChannelRequest.fromJson(r, RequestKind.share)).toList(),
    );
  }
}

class SharedChannelSummary {
  SharedChannelSummary({required this.channelId, required this.channelName});

  final String channelId;
  final String channelName;
}

class MembershipServiceException implements Exception {
  MembershipServiceException(this.code);

  final String code;

  @override
  String toString() => 'MembershipServiceException($code)';
}

class ChannelRequestException implements Exception {
  ChannelRequestException(this.code);

  final String code;

  String get message => switch (code) {
        'user_not_found' => 'Diese Person hat noch keinen Smile-Account.',
        'not_channel_sco' => 'Du bist nicht berechtigt, diesen Channel zu verwalten.',
        'request_already_pending' => 'Es gibt bereits eine offene Einladung/Anfrage.',
        _ => 'Aktion fehlgeschlagen.',
      };

  @override
  String toString() => 'ChannelRequestException($code)';
}
