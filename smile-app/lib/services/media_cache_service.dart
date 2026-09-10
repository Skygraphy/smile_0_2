import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'media_service.dart';

/// Persists the last-known feed per channel so ChannelFeedScreen can paint
/// instantly on open (like WhatsApp) instead of showing a blank spinner
/// while the network round trip (auth + DB query + URL signing) completes.
/// Signed URLs expire after an hour, so this is only ever shown briefly
/// before a background `_load()` replaces it with fresh data -- a stale
/// image just fails to load for that short window rather than corrupting
/// anything.
class MediaCacheService {
  static String _keyFor(String channelId) => 'media_feed_cache_$channelId';

  static Future<List<MediaItem>?> load(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(channelId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.cast<Map<String, dynamic>>().map(MediaItem.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String channelId, List<MediaItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(channelId), jsonEncode(items.map((item) => item.toJson()).toList()));
  }
}
