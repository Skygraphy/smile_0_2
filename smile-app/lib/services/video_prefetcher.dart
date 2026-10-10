import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../main.dart';
import 'channel_picker_service.dart';
import 'media_service.dart';
import 'sync_bus.dart';
import 'video_cache.dart';

/// In WLAN, new videos are downloaded ahead of time, like WhatsApp (decided
/// 2026-10-10) -- so they play offline even if nobody opened them yet.
/// Newest first, album by album, up to 80 % of the VideoCache limit (the
/// rest stays free for videos actually being played). Never over mobile
/// data.
class VideoPrefetcher {
  VideoPrefetcher._();

  static bool _running = false;
  static Timer? _debounce;
  static DateTime? _lastRun;

  /// Not more often than this -- every run lists every album.
  static const _minInterval = Duration(minutes: 5);

  static void start() {
    schedule(force: true);
    // New videos arrive as sync events; WLAN coming back is a chance too.
    SyncBus.stream.listen((_) => schedule());
    Connectivity().onConnectivityChanged.listen((_) => schedule(force: true));
  }

  static void schedule({bool force = false}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 15), () {
      final last = _lastRun;
      if (!force && last != null && DateTime.now().difference(last) < _minInterval) return;
      unawaited(_run());
    });
  }

  static Future<bool> _onWlan() async {
    final types = await Connectivity().checkConnectivity();
    return types.contains(ConnectivityResult.wifi) || types.contains(ConnectivityResult.ethernet);
  }

  static Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      final wlan = await _onWlan();
      debugPrint('VideoPrefetcher: run (signed in: ${supabase.auth.currentUser != null}, WLAN: $wlan)');
      if (supabase.auth.currentUser == null || !wlan) return;
      _lastRun = DateTime.now();
      final budget = (VideoCache.maxBytes * 0.8).round();
      var used = await VideoCache.usedBytes();
      final albums = await ChannelPickerService().listMyChannelsWithActivity();
      final media = MediaService();
      debugPrint('VideoPrefetcher: ${albums.length} album(s)');
      for (final album in albums) {
        final items = await media.fetchReadyMedia(album.channelId);
        final videos = items.where((i) => i.isVideo && i.isReady && i.displayUrl != null).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        debugPrint('VideoPrefetcher: ${album.channelName}: ${videos.length} video(s)');
        for (final video in videos) {
          if (await VideoCache.has(video.id)) continue;
          if (used >= budget || !await _onWlan()) return;
          final file = await VideoCache.download(video.id, video.displayUrl!);
          debugPrint('VideoPrefetcher: ${video.id} ${file == null ? "failed" : "kept"}');
          if (file != null) used += await file.length();
        }
      }
    } catch (e) {
      debugPrint('VideoPrefetcher: $e');
    } finally {
      _running = false;
    }
  }
}
