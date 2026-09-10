import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'media_cache_sync.dart';

/// Persists the cache index (JSON) and the cached media files themselves
/// under the app's own sandboxed storage directory. Dart port of
/// smile_0_1's MediaCacheStore.kt.
class MediaCacheStore {
  MediaCacheStore({Directory? cacheDirectory}) : _cacheDirectoryOverride = cacheDirectory;

  final Directory? _cacheDirectoryOverride;
  Directory? _resolvedDirectory;

  Future<Directory> _directory() async {
    if (_cacheDirectoryOverride != null) return _cacheDirectoryOverride;
    if (_resolvedDirectory != null) return _resolvedDirectory!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/media_cache');
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
