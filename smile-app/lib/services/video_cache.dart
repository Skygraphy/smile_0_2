import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Videos kept on the phone, like WhatsApp (decided 2026-10-10): they play
/// offline and start at once.
///  * Own videos: the converted copy made for the upload is kept
///    (MediaService.uploadVideo) -- no download at all.
///  * Others' videos: downloaded the first time they are played, and in
///    WLAN ahead of time (VideoPrefetcher).
/// At most [maxBytes]; when full, the videos not played for the longest
/// time go first -- online they still stream as before.
class VideoCache {
  VideoCache._();

  static const maxBytes = 1024 * 1024 * 1024; // 1 GB

  static Directory? _dir;
  static final Map<String, Future<File?>> _downloads = {};

  static Future<Directory> _cacheDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/video_cache');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  static Future<File> _fileFor(String mediaId) async => File('${(await _cacheDir()).path}/$mediaId.mp4');

  /// The video on the phone, or null. Marks it as just used.
  static Future<File?> cached(String mediaId) async {
    try {
      final file = await _fileFor(mediaId);
      if (!await file.exists() || await file.length() == 0) return null;
      unawaited(file.setLastModified(DateTime.now()).catchError((_) {}));
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> has(String mediaId) async {
    try {
      final file = await _fileFor(mediaId);
      return await file.exists() && await file.length() > 0;
    } catch (_) {
      return false;
    }
  }

  /// Keeps [source] (moved, not copied) as the video [mediaId].
  static Future<void> keep(String mediaId, File source) async {
    try {
      final target = await _fileFor(mediaId);
      try {
        await source.rename(target.path);
      } on FileSystemException {
        // Different volume: copy instead.
        await source.copy(target.path);
        await source.delete();
      }
      await _evict(keep: mediaId);
    } catch (e) {
      debugPrint('VideoCache: could not keep $mediaId: $e');
    }
  }

  /// Downloads the video once (several calls for the same video share one
  /// download). Returns the file, or null if it failed.
  static Future<File?> download(String mediaId, String url) {
    // A block body on purpose: "=> _downloads.remove(...)" returns the very
    // future being completed, and whenComplete then waits for itself forever.
    return _downloads[mediaId] ??= _download(mediaId, url).whenComplete(() {
      _downloads.remove(mediaId);
    });
  }

  static Future<File?> _download(String mediaId, String url) async {
    final existing = await cached(mediaId);
    if (existing != null) return existing;
    final target = await _fileFor(mediaId);
    final partial = File('${target.path}.part');
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        return null;
      }
      final sink = partial.openWrite();
      try {
        await response.stream.timeout(const Duration(seconds: 60)).pipe(sink);
      } finally {
        await sink.close().catchError((_) {});
      }
      await partial.rename(target.path);
      await _evict(keep: mediaId);
      return target;
    } catch (e) {
      debugPrint('VideoCache: download of $mediaId failed: $e');
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }

  /// Total size of the kept videos.
  static Future<int> usedBytes() async {
    var total = 0;
    await for (final entity in (await _cacheDir()).list()) {
      if (entity is File && entity.path.endsWith('.mp4')) total += await entity.length();
    }
    return total;
  }

  /// Over the limit: the least recently played go first ([keep] never).
  static Future<void> _evict({String? keep}) async {
    try {
      final files = <File>[];
      await for (final entity in (await _cacheDir()).list()) {
        if (entity is File && entity.path.endsWith('.mp4')) files.add(entity);
      }
      var total = 0;
      final info = <(File, int, DateTime)>[];
      for (final f in files) {
        final stat = await f.stat();
        total += stat.size;
        info.add((f, stat.size, stat.modified));
      }
      if (total <= maxBytes) return;
      info.sort((a, b) => a.$3.compareTo(b.$3));
      for (final (file, size, _) in info) {
        if (total <= maxBytes) break;
        if (keep != null && file.path.endsWith('/$keep.mp4')) continue;
        await file.delete();
        total -= size;
      }
    } catch (e) {
      debugPrint('VideoCache: eviction failed: $e');
    }
  }
}
