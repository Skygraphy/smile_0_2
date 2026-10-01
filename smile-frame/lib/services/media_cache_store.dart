import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'cache_cipher.dart';
import 'media_cache_sync.dart';

/// Persists the cache index (JSON) and the cached media files themselves
/// under the app's own sandboxed storage directory -- the photo files
/// encrypted (CacheCipher). Dart port of smile_0_1's MediaCacheStore.kt.
class MediaCacheStore {
  MediaCacheStore({Directory? cacheDirectory, CacheCipher? cipher})
      : _cacheDirectoryOverride = cacheDirectory,
        _cipher = cipher ?? CacheCipher();

  final Directory? _cacheDirectoryOverride;
  final CacheCipher _cipher;
  Directory? _resolvedDirectory;

  Future<Directory> _directory() async {
    if (_cacheDirectoryOverride != null) return _cacheDirectoryOverride;
    if (_resolvedDirectory != null) return _resolvedDirectory!;
    final appDir = await getApplicationSupportDirectory();
    // v3 = encrypted in blocks (any size, incl. hour-long videos). Older
    // caches (v1 plain JPEG, v2 one-piece encryption) are removed outright;
    // the next sync simply downloads everything again.
    for (final legacy in ['media_cache', 'media_cache_v2']) {
      final old = Directory('${appDir.path}/$legacy');
      if (await old.exists()) await old.delete(recursive: true);
    }
    final dir = Directory('${appDir.path}/media_cache_v3');
    if (!await dir.exists()) await dir.create(recursive: true);
    _resolvedDirectory = dir;
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _directory();
    return File('${dir.path}/index.json');
  }

  Future<List<CachedMediaEntry>> readIndex() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list.map((e) => CachedMediaEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> writeIndex(List<CachedMediaEntry> entries) async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// Writes a photo/poster, encrypted. Returns its plaintext size.
  Future<int> writeMedia(String fileName, List<int> plainBytes) async =>
      _cipher.encryptBytesToFile(plainBytes, await fileFor(fileName));

  /// Writes a download straight from the network, encrypted block by block
  /// -- a video of any length never sits in memory. Returns its size.
  Future<int> writeMediaStream(String fileName, Stream<List<int>> plain) async =>
      _cipher.encryptStreamToFile(plain, await fileFor(fileName));

  /// Reads a cached photo back as plain image bytes (null if it's gone or
  /// can't be decrypted -- e.g. left over from before an un-pairing).
  Future<Uint8List?> readMedia(String fileName) async {
    try {
      final file = await fileFor(fileName);
      if (!await file.exists()) return null;
      return await _cipher.decryptToBytes(file);
    } catch (_) {
      return null;
    }
  }

  Future<File> fileFor(String fileName) async {
    final dir = await _directory();
    return File('${dir.path}/$fileName');
  }

  /// Resolved once by callers that need to build File paths synchronously
  /// afterward (e.g. in a widget build method), instead of re-resolving
  /// the platform directory on every rebuild.
  Future<String> resolvedDirectoryPath() async => (await _directory()).path;

  /// Decrypts a cached video into a playable temporary file (video_player
  /// needs a real file). Callers delete it again right after playback, and
  /// [clearPlaybackFiles] removes any left over from a crash.
  Future<File?> decryptVideoForPlayback(String fileName) async {
    try {
      final source = await fileFor(fileName);
      if (!await source.exists()) return null;
      final dir = await _playbackDirectory();
      final out = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}.mp4');
      await _cipher.decryptToFile(source, out);
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _playbackDirectory() async {
    final base = _cacheDirectoryOverride ?? await getTemporaryDirectory();
    final dir = Directory('${base.path}/playback');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> clearPlaybackFiles() async {
    final dir = await _playbackDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> deleteFile(String fileName) async {
    final file = await fileFor(fileName);
    if (await file.exists()) await file.delete();
  }
}
