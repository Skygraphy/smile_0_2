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
    // v2 = encrypted files. The old plain-JPEG cache is removed outright;
    // the next sync simply downloads everything again, encrypted.
    final legacy = Directory('${appDir.path}/media_cache');
    if (await legacy.exists()) await legacy.delete(recursive: true);
    final dir = Directory('${appDir.path}/media_cache_v2');
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

  /// Writes a downloaded photo, encrypted.
  Future<void> writeMedia(String fileName, List<int> plainBytes) async {
    final file = await fileFor(fileName);
    await file.writeAsBytes(await _cipher.encrypt(plainBytes), flush: true);
  }

  /// Reads a cached photo back as plain image bytes (null if it's gone or
  /// can't be decrypted -- e.g. left over from before an un-pairing).
  Future<Uint8List?> readMedia(String fileName) async {
    try {
      final file = await fileFor(fileName);
      if (!await file.exists()) return null;
      return await _cipher.decrypt(await file.readAsBytes());
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

  Future<void> deleteFile(String fileName) async {
    final file = await fileFor(fileName);
    if (await file.exists()) await file.delete();
  }
}
