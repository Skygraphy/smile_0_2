import '../main.dart';
import 'membership_service.dart';
import 'space_service.dart';

/// What the Neuigkeiten icon shows.
class NewsStatus {
  const NewsStatus({required this.needsAnswer, required this.unseenNews});

  /// Something waits for the caller's own decision -> icon turns coral.
  final bool needsAnswer;

  /// Verlauf entries arrived since Neuigkeiten was last opened -> small
  /// coral dot (user feedback 2026-10-06: new messages went unnoticed).
  final bool unseenNews;
}

/// Backs the "Neuigkeiten" icon in the top bar. needsAnswer: an album invite
/// (posting rights or a share with one of their Spaces), a Co-Admin invite,
/// or -- as a manager -- someone asking to join or see one of their albums.
/// Requests the caller sent themselves don't count: they wait on someone
/// else. unseenNews: anything in the Verlauf newer than news_reads.seen_at
/// (migrations/0063).
class NewsService {
  NewsService({MembershipService? membershipService, SpaceService? spaceService})
      : _membershipService = membershipService ?? MembershipService(),
        _spaceService = spaceService ?? SpaceService();

  final MembershipService _membershipService;
  final SpaceService _spaceService;

  Future<NewsStatus> status() async {
    final results = await Future.wait<dynamic>([
      _membershipService.listMyInvites(includeManaged: true),
      _spaceService.listMyCoOwnerInvites(),
      supabase.from('news_reads').select('seen_at').maybeSingle(),
    ]);
    final inbox = results[0] as MyInvitesInbox;
    final coAdminInvites = results[1] as List<MyCoOwnerInvite>;
    final seenAt = (results[2] as Map<String, dynamic>?)?['seen_at'] as String?;
    var newer = supabase.from('user_notifications').select('id');
    if (seenAt != null) newer = newer.gt('created_at', seenAt);
    final unseen = await newer.limit(1);
    return NewsStatus(
      needsAnswer: coAdminInvites.isNotEmpty ||
          inbox.managedMembershipRequests.isNotEmpty ||
          inbox.managedShareRequests.isNotEmpty ||
          [...inbox.membershipRequests, ...inbox.shareRequests].any((r) => r.direction == RequestDirection.invite),
      unseenNews: (unseen as List).isNotEmpty,
    );
  }

  /// Opening Neuigkeiten counts as having seen everything in it.
  Future<void> markSeen() => supabase.rpc('mark_news_seen');
}
