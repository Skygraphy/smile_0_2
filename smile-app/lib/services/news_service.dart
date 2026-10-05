import 'membership_service.dart';
import 'space_service.dart';

/// Backs the "Neuigkeiten" icon in the top bar: is anything waiting for
/// the caller's own decision? That is an album invite (posting rights or
/// a share with one of their Spaces), a Co-Admin invite, or -- as a
/// manager -- someone asking to join or see one of their albums. Requests
/// the caller sent themselves don't count: they wait on someone else.
class NewsService {
  NewsService({MembershipService? membershipService, SpaceService? spaceService})
      : _membershipService = membershipService ?? MembershipService(),
        _spaceService = spaceService ?? SpaceService();

  final MembershipService _membershipService;
  final SpaceService _spaceService;

  Future<bool> hasPendingForMe() async {
    final results = await Future.wait<dynamic>([
      _membershipService.listMyInvites(includeManaged: true),
      _spaceService.listMyCoOwnerInvites(),
    ]);
    final inbox = results[0] as MyInvitesInbox;
    final coAdminInvites = results[1] as List<MyCoOwnerInvite>;
    return coAdminInvites.isNotEmpty ||
        inbox.managedMembershipRequests.isNotEmpty ||
        inbox.managedShareRequests.isNotEmpty ||
        [...inbox.membershipRequests, ...inbox.shareRequests].any((r) => r.direction == RequestDirection.invite);
  }
}
