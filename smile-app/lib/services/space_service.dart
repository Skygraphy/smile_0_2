import '../main.dart';

/// A person with full, ongoing SCO-equivalent power over a Space, granted
/// by its founder -- migrations/0037_space_co_owners.sql. Solves the gap a
/// single `owner_id` left open: a Space representing a whole household
/// (e.g. a married couple) had exactly one person who could ever manage
/// anything, with no path forward if that person became unreachable.
class SpaceCoOwner {
  SpaceCoOwner({required this.userId, required this.displayName, required this.avatarUrl, required this.createdAt});

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  String get label => displayName ?? userId;

  factory SpaceCoOwner.fromJson(Map<String, dynamic> json) => SpaceCoOwner(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// A not-yet-answered co-owner invite, from the founder's own point of
/// view (who did I invite, and when) -- see space_co_owners_screen.dart's
/// "Ausstehende Einladungen".
class PendingCoOwnerInvite {
  PendingCoOwnerInvite({
    required this.id,
    required this.inviteeUserId,
    required this.displayName,
    required this.avatarUrl,
    required this.requestedAt,
  });

  final String id;
  final String inviteeUserId;
  final String? displayName;
  final String? avatarUrl;
  final DateTime requestedAt;

  String get label => displayName ?? inviteeUserId;

  factory PendingCoOwnerInvite.fromJson(Map<String, dynamic> json) => PendingCoOwnerInvite(
        id: json['id'] as String,
        inviteeUserId: json['invitee_user_id'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        requestedAt: DateTime.parse(json['requested_at'] as String),
      );
}

class SpaceCoOwnership {
  SpaceCoOwnership({
    required this.founderUserId,
    required this.founderDisplayName,
    required this.founderAvatarUrl,
    required this.coOwners,
    required this.pendingInvites,
    required this.callerIsFounder,
  });

  final String founderUserId;
  final String? founderDisplayName;
  final String? founderAvatarUrl;
  final List<SpaceCoOwner> coOwners;
  // Only populated for the founder -- empty for a co-owner or anyone else,
  // see list-space-co-owners/index.ts.
  final List<PendingCoOwnerInvite> pendingInvites;
  final bool callerIsFounder;

  String get founderLabel => founderDisplayName ?? founderUserId;
}

/// An invite addressed to the caller themselves, inviting them to become a
/// Space's co-owner -- migrations/0038_space_co_owner_invites.sql. Shown
/// on my_invites_screen.dart alongside channel membership/share invites.
class MyCoOwnerInvite {
  MyCoOwnerInvite({
    required this.id,
    required this.spaceId,
    required this.spaceName,
    required this.founderDisplayName,
    required this.founderAvatarUrl,
    required this.requestedAt,
  });

  final String id;
  final String spaceId;
  final String? spaceName;
  final String? founderDisplayName;
  final String? founderAvatarUrl;
  final DateTime requestedAt;

  String get founderLabel => founderDisplayName ?? 'Jemand';

  factory MyCoOwnerInvite.fromJson(Map<String, dynamic> json) => MyCoOwnerInvite(
        id: json['id'] as String,
        spaceId: json['space_id'] as String,
        spaceName: json['space_name'] as String?,
        founderDisplayName: json['founder_display_name'] as String?,
        founderAvatarUrl: json['founder_avatar_url'] as String?,
        requestedAt: DateTime.parse(json['requested_at'] as String),
      );
}

/// Space-level administration: who else manages this Space besides its
/// founder, inviting/removing co-owners, and (self-service) handing the
/// founder role itself to one of them -- mirrors WhatsApp's own "admin
/// leaves the group" behavior, where admin rights pass to another member
/// instead of the group dying. The *other* half of that analogy (the
/// founder's account being deleted outright, not a voluntary handover) is
/// handled automatically by a DB trigger, not from here -- see the
/// migration's `handle_space_owner_removal`.
class SpaceService {
  /// Administrator only (a co-owner may manage, never end the Space) --
  /// into the 30-day trash with every channel, photo and Frame of it
  /// (delete-space-or-channel); restorable via TrashService.
  Future<void> deleteSpace(String spaceId) async {
    await supabase.functions.invoke('delete-space-or-channel', body: {'kind': 'space', 'id': spaceId});
  }

  /// Founder + every co-owner of this Space (oldest-added first -- also
  /// the order `handle_space_owner_removal` promotes from if the founder's
  /// account is ever deleted, so this list already shows who'd be next in
  /// that case, not just who currently has access), plus (founder only)
  /// every not-yet-answered invite. An Edge Function because profiles has
  /// no cross-user RLS (see _shared/profiles.ts).
  Future<SpaceCoOwnership> listCoOwners(String spaceId) async {
    final response = await supabase.functions.invoke('list-space-co-owners', body: {'space_id': spaceId});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw SpaceServiceException(data['error'] as String);
    return SpaceCoOwnership(
      founderUserId: data['founder_user_id'] as String,
      founderDisplayName: data['founder_display_name'] as String?,
      founderAvatarUrl: data['founder_avatar_url'] as String?,
      coOwners: (data['co_owners'] as List).cast<Map<String, dynamic>>().map(SpaceCoOwner.fromJson).toList(),
      pendingInvites:
          (data['pending_invites'] as List).cast<Map<String, dynamic>>().map(PendingCoOwnerInvite.fromJson).toList(),
      callerIsFounder: data['caller_is_founder'] as bool,
    );
  }

  /// Founder-only (enforced server-side): invites a known person (by
  /// email) to become a co-owner. The invitee decides via
  /// [decideCoOwnerInvite] -- consistent with every other connection this
  /// app creates (channel membership, channel sharing), unlike this
  /// method's short-lived predecessor (addCoOwner), which granted co-owner
  /// status directly with no say from the recipient.
  Future<void> inviteCoOwner({required String spaceId, required String email}) async {
    final response = await supabase.functions.invoke('invite-space-co-owner', body: {
      'space_id': spaceId,
      'email': email,
    });
    final data = response.data as Map<String, dynamic>?;
    final status = data?['status'] as String?;
    if (status != 'invited' && status != 'already_co_owner') {
      throw SpaceServiceException(data?['error'] as String? ?? 'unknown_error');
    }
  }

  /// The founder may withdraw a not-yet-answered invite (e.g. wrong
  /// person) -- plain RLS-governed delete, see
  /// space_co_owner_invites_founder_withdraw's policy.
  Future<void> withdrawCoOwnerInvite(String inviteId) async {
    await supabase.from('space_co_owner_invites').delete().eq('id', inviteId);
  }

  /// The caller's own pending co-owner invites, across every Space --
  /// mirrors listMyInvites in membership_service.dart. An Edge Function
  /// for the same reason: the invitee can't yet see the Space's name or
  /// the founder's profile via plain RLS.
  Future<List<MyCoOwnerInvite>> listMyCoOwnerInvites() async {
    final response = await supabase.functions.invoke('list-my-space-co-owner-invites');
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw SpaceServiceException(data['error'] as String);
    return (data['invites'] as List).cast<Map<String, dynamic>>().map(MyCoOwnerInvite.fromJson).toList();
  }

  /// Only the invitee may decide -- plain RLS-governed update
  /// (space_co_owner_invites_invitee_decide), same shape as
  /// decideMembershipRequest/decideShareRequest. Accepting materializes
  /// the real space_co_owners row via a DB trigger, not here.
  Future<void> decideCoOwnerInvite(String inviteId, {required bool accept}) async {
    await supabase
        .from('space_co_owner_invites')
        .update({'status': accept ? 'accepted' : 'declined'}).eq('id', inviteId);
    // Notified server-side (notify-event 'request_decided', migrations/0050).
  }

  /// The founder may remove any co-owner; a co-owner may also remove
  /// themselves (step down) -- both are the same plain RLS-governed
  /// delete, see space_co_owners_delete's policy.
  Future<void> removeCoOwner({required String spaceId, required String userId}) async {
    await supabase.from('space_co_owners').delete().eq('space_id', spaceId).eq('user_id', userId);
  }

  /// The founder voluntarily hands the founder role to one of their
  /// existing co-owners -- the outgoing founder becomes a plain co-owner
  /// afterward instead of losing access, same as a WhatsApp admin who
  /// demotes themselves stays a member.
  Future<void> transferOwnership({required String spaceId, required String newOwnerUserId}) async {
    final response = await supabase.functions.invoke('transfer-space-ownership', body: {
      'space_id': spaceId,
      'new_owner_user_id': newOwnerUserId,
    });
    final data = response.data as Map<String, dynamic>?;
    if (data?['status'] != 'transferred') {
      throw SpaceServiceException(data?['error'] as String? ?? 'unknown_error');
    }
  }
}

class SpaceServiceException implements Exception {
  SpaceServiceException(this.code);

  final String code;

  String get message => switch (code) {
        'user_not_found' => 'Diese Person hat noch keinen Smile-Account.',
        'not_space_founder' => 'Nur der Administrator kann das tun.',
        'already_founder' => 'Diese Person ist bereits der Administrator.',
        'already_co_owner' => 'Diese Person ist bereits Co-Owner.',
        'invite_already_pending' => 'Es gibt bereits eine offene Einladung.',
        'not_a_co_owner' => 'Diese Person ist kein Co-Owner.',
        _ => 'Aktion fehlgeschlagen.',
      };

  @override
  String toString() => 'SpaceServiceException($code)';
}
