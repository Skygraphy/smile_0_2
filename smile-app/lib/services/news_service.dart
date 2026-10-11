import '../main.dart';
import 'local_changes.dart';

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
  NewsService();

  /// Every tab's Neuigkeiten icon asks at the same moment: one round of
  /// requests, the same answer for all (2026-10-12: it was six at start).
  Future<NewsStatus> status() => _inflight ??= _status().whenComplete(() => _inflight = null);

  static Future<NewsStatus>? _inflight;

  /// One query (migrations/0074) instead of the whole inbox.
  Future<NewsStatus> _status() async {
    final data = await supabase.rpc('my_news_status') as Map<String, dynamic>;
    return NewsStatus(
      needsAnswer: data['needs_answer'] == true,
      unseenNews: data['unseen_news'] == true,
    );
  }

  /// Opening Neuigkeiten counts as having seen everything in it.
  Future<void> markSeen() async {
    await supabase.rpc('mark_news_seen');
    // The Neuigkeiten icon loses its dot at once (LocalChanges).
    LocalChanges.saved(tablesChanged({'news_reads'}));
  }
}
