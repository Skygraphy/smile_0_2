import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'media_service.dart';
import 'video_cache.dart';

/// Photos and videos out of Smile (Ernst 2026-11-05): into the phone's
/// gallery (album "Smile") or on through the phone's share menu (WhatsApp,
/// mail, ...). In the quality they have in Smile; any member of the album.
class MediaExport {
  MediaExport._();

  static const galleryAlbum = 'Smile';

  /// Only what is there to take: ready, with a file to fetch.
  static bool canExport(MediaItem item) => item.isReady && (item.displayUrl != null || item.thumbnailUrl != null);

  /// Saves [items] in the gallery; how many made it.
  static Future<int> saveToGallery(List<MediaItem> items) async {
    if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) return 0;
    var saved = 0;
    for (final item in items) {
      try {
        final file = await _fileFor(item);
        if (item.isVideo) {
          await Gal.putVideo(file.path, album: galleryAlbum);
        } else {
          await Gal.putImage(file.path, album: galleryAlbum);
        }
        saved++;
      } catch (_) {
        // Next one; the count says how many arrived.
      }
    }
    return saved;
  }

  /// The phone's share menu with [items]; false when none could be fetched.
  static Future<bool> share(List<MediaItem> items) async {
    final files = <XFile>[];
    for (final item in items) {
      try {
        files.add(XFile((await _fileFor(item)).path));
      } catch (_) {}
    }
    if (files.isEmpty) return false;
    await SharePlus.instance.share(ShareParams(files: files));
    return true;
  }

  /// A local copy with the right file ending: the phone's own cache when it
  /// has it (videos played before, photos shown before), else downloaded.
  static Future<File> _fileFor(MediaItem item) async {
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/smile_${item.id}.${item.isVideo ? 'mp4' : 'jpg'}');
    if (await out.exists() && await out.length() > 0) return out;
    if (item.isVideo) {
      final cached = await VideoCache.cached(item.id);
      if (cached != null) return cached.copy(out.path);
      return _download(item.displayUrl!, out);
    }
    final url = item.displayUrl ?? item.thumbnailUrl!;
    try {
      final cached = await DefaultCacheManager().getSingleFile(
        url,
        key: item.displayUrl != null ? '${item.id}_display' : '${item.id}_grid',
      );
      return await cached.copy(out.path);
    } catch (_) {
      return _download(url, out);
    }
  }

  static Future<File> _download(String url, File out) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw HttpException('status ${response.statusCode}');
    return out.writeAsBytes(response.bodyBytes);
  }
}
