import 'dart:async';
import 'dart:convert';

import '../main.dart';
import 'edge_functions.dart';
import 'offline.dart';

/// A Space linked to a channel, either as its home Space or via a
/// view-only share (channel_shares).
class SpaceRef {
  SpaceRef({required this.id, required this.name});

  final String id;
  final String name;

  factory SpaceRef.fromJson(Map<String, dynamic> json) => SpaceRef(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class UploadableChannel {
  UploadableChannel({required this.channelId, required this.channelName, required this.spaceName});

  final String channelId;
  final String channelName;
  final String spaceName;
}

/// The newest run of posts in an album by one person ("Roman: 4 Fotos"),
/// as list-my-channels computes it -- the caller's hidden items excluded.
class LastPost {
  LastPost({required this.senderId, required this.senderName, required this.photos, required this.videos});

  final String senderId;
  final String? senderName;
  final int photos;
  final int videos;

  factory LastPost.fromJson(Map<String, dynamic> json) => LastPost(
        senderId: json['sender_id'] as String,
        senderName: json['sender_name'] as String?,
        photos: json['photos'] as int,
        videos: json['videos'] as int,
      );
}

class ChannelWithActivity {
  ChannelWithActivity({
    required this.channelId,
    required this.channelName,
    required this.spaces,
    required this.isMember,
    required this.lastActivityAt,
    this.lastPost,
    this.unreadCount = 0,
    this.coverMediaId,
    this.coverUrl,
    this.coverCustom = false,
  });

  final String channelId;
  final String channelName;
  final List<SpaceRef> spaces;
  // False for a channel the caller can only view via a Space they own
  // being shared into it (channel_shares) -- no posting rights.
  final bool isMember;
  final DateTime lastActivityAt;

  /// Null for an album without posts yet.
  final LastPost? lastPost;

  /// Others' posts since the caller last opened the album (migrations/0058).
  final int unreadCount;

  /// The album's cover: its newest visible photo (list-my-channels).
  final String? coverMediaId;
  final String? coverUrl;

  /// True when a manager chose the cover (own picture or "Als Titelbild").
  final bool coverCustom;

  String get spaceLabel => spaces.map((s) => s.name).join(', ');

  factory ChannelWithActivity.fromJson(Map<String, dynamic> json) => ChannelWithActivity(
        channelId: json['channel_id'] as String,
        channelName: json['channel_name'] as String,
        spaces: (json['spaces'] as List).cast<Map<String, dynamic>>().map(SpaceRef.fromJson).toList(),
        isMember: json['is_member'] as bool,
        lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
        lastPost: json['last_post'] == null ? null : LastPost.fromJson(json['last_post'] as Map<String, dynamic>),
        unreadCount: json['unread_count'] as int? ?? 0,
        coverMediaId: (json['cover'] as Map<String, dynamic>?)?['media_id'] as String?,
        coverUrl: (json['cover'] as Map<String, dynamic>?)?['thumbnail_url'] as String?,
        coverCustom: (json['cover'] as Map<String, dynamic>?)?['custom'] as bool? ?? false,
      );
}

/// Channel discovery for the two places the app needs it: which channels
/// the caller can *post* to (a `channel_members` row -- the SCO is always
/// one too, auto-joined at creation), and which channels the caller can
/// *see* at all, including view-only shares (server-side, since "latest
/// ready media_item per channel" needs real aggregation).
class ChannelPickerService {
  Future<List<UploadableChannel>> listMyUploadableChannels() async {
    // The explicit `!channels_space_id_fkey` hint is required: PostgREST
    // can also reach `spaces` from `channels` indirectly through
    // `channel_shares` (which has FKs to both), so a bare `spaces(...)`
    // embed is ambiguous (PGRST201) -- see list-my-channels/index.ts for
    // the matching server-side fix and why this wasn't caught earlier.
    final rows = await supabase
        .from('channel_members')
        .select('channel_id, channels(name, spaces!channels_space_id_fkey(name))')
        // RLS also shows the OTHER members of my albums (for member lists)
        // -- without this, an album with 3 members was listed 3 times.
        .eq('user_id', supabase.auth.currentUser!.id)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final channel = row['channels'] as Map<String, dynamic>;
      final space = channel['spaces'] as Map<String, dynamic>;
      return UploadableChannel(
        channelId: row['channel_id'] as String,
        channelName: channel['name'] as String,
        spaceName: space['name'] as String,
      );
    }).toList();
  }

  /// Every channel the caller can *see* (including view-only shares),
  /// sorted by most recent photo activity -- powers channels_home_screen.dart's
  /// WhatsApp-style flat "who did I last exchange photos with" landing list.
  ///
  /// Kept on the phone after every successful load: offline (2026-10-09)
  /// the last list is returned instead of an error.
  Future<List<ChannelWithActivity>> listMyChannelsWithActivity() {
    // Several screens ask at the same moment (album list, covers, video
    // prefetch): one request, the same answer for all (2026-10-12).
    return _inflight ??= _listMyChannelsWithActivity().whenComplete(() {
          _inflight = null;
        });
  }

  static Future<List<ChannelWithActivity>>? _inflight;

  /// The last list from the server and when it came (for the album covers
  /// every screen shows -- 2026-10-12: nine requests while clicking through).
  static List<ChannelWithActivity>? _recent;
  static DateTime? _recentAt;
  static String? _recentUser;

  /// A list at most [maxAge] old, else a fresh one.
  Future<List<ChannelWithActivity>> recentMyChannels({Duration maxAge = const Duration(seconds: 30)}) async {
    final recent = _recent;
    final at = _recentAt;
    if (recent != null && at != null && _recentUser == supabase.auth.currentUser?.id && DateTime.now().difference(at) < maxAge) {
      return recent;
    }
    return listMyChannelsWithActivity();
  }

  Future<List<ChannelWithActivity>> _listMyChannelsWithActivity() async {
    final Map<String, dynamic> data;
    try {
      final response = await invokeEdge('list-my-channels');
      data = response.data as Map<String, dynamic>;
      Offline.reachedServer();
    } catch (e) {
      if (Offline.noteFailure(e)) {
        final cached = await cachedMyChannels();
        if (cached != null) return cached;
      }
      rethrow;
    }
    if (data['error'] != null) throw ChannelPickerException(data['error'] as String);
    final channels = (data['channels'] as List).cast<Map<String, dynamic>>();
    unawaited(Offline.write(_cacheKey(), jsonEncode(channels)));
    final list = channels.map(ChannelWithActivity.fromJson).toList();
    _recent = list;
    _recentAt = DateTime.now();
    _recentUser = supabase.auth.currentUser?.id;
    return list;
  }

  /// The list as last loaded (null: never loaded on this phone).
  Future<List<ChannelWithActivity>?> cachedMyChannels() async {
    final raw = await Offline.read(_cacheKey());
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(ChannelWithActivity.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  String _cacheKey() => 'albums_cache_${supabase.auth.currentUser?.id}';
}

class ChannelPickerException implements Exception {
  ChannelPickerException(this.code);

  final String code;

  @override
  String toString() => 'ChannelPickerException($code)';
}
