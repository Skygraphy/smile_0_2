// Pure diff/eviction logic for the offline media cache -- no I/O, easy to
// unit test. Dart port of smile_0_1's MediaCache.kt/MediaCacheSync.

class RemoteMediaEntry {
  const RemoteMediaEntry({
    required this.mediaItemId,
    required this.mediaType,
    required this.sortOrder,
    required this.displayUrl,
  });

  final String mediaItemId;
  final String mediaType;
  final int sortOrder;
  final String? displayUrl;
}

class CachedMediaEntry {
  const CachedMediaEntry({
    required this.mediaItemId,
    required this.mediaType,
    required this.sortOrder,
    required this.fileName,
    required this.fileSizeBytes,
    required this.cachedAt,
  });

  final String mediaItemId;
  final String mediaType;
  final int sortOrder;
  final String fileName;
  final int fileSizeBytes;
  final DateTime cachedAt;

  Map<String, dynamic> toJson() => {
        'media_item_id': mediaItemId,
        'media_type': mediaType,
        'sort_order': sortOrder,
        'file_name': fileName,
        'file_size_bytes': fileSizeBytes,
        'cached_at': cachedAt.toUtc().toIso8601String(),
      };

  factory CachedMediaEntry.fromJson(Map<String, dynamic> json) => CachedMediaEntry(
        mediaItemId: json['media_item_id'] as String,
        mediaType: json['media_type'] as String,
        sortOrder: json['sort_order'] as int,
        fileName: json['file_name'] as String,
        fileSizeBytes: json['file_size_bytes'] as int,
        cachedAt: DateTime.parse(json['cached_at'] as String),
      );

  CachedMediaEntry copyWith({int? sortOrder}) => CachedMediaEntry(
        mediaItemId: mediaItemId,
        mediaType: mediaType,
        sortOrder: sortOrder ?? this.sortOrder,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
        cachedAt: cachedAt,
      );
}

class CacheDiff {
  const CacheDiff({required this.toDownload, required this.toDelete});

  final List<RemoteMediaEntry> toDownload;
  final List<CachedMediaEntry> toDelete;
}

class MediaCacheSync {
  /// What's missing locally (toDownload) and what's no longer in the
  /// remote batch and should be removed (toDelete, e.g. hidden/unassigned
  /// server-side since the last sync).
  static CacheDiff diff(List<RemoteMediaEntry> remote, List<CachedMediaEntry> local) {
    final remoteIds = remote.map((e) => e.mediaItemId).toSet();
    final localIds = local.map((e) => e.mediaItemId).toSet();

    final toDownload = remote.where((e) => !localIds.contains(e.mediaItemId)).toList();
    final toDelete = local.where((e) => !remoteIds.contains(e.mediaItemId)).toList();

    return CacheDiff(toDownload: toDownload, toDelete: toDelete);
  }

  /// Oldest-by-sortOrder-first eviction once the cache exceeds [maxBytes].
  /// Returns the entries to remove; caller deletes the underlying files.
  static List<CachedMediaEntry> entriesToEvictForCap(List<CachedMediaEntry> cached, int? maxBytes) {
    if (maxBytes == null) return const [];
    final sorted = [...cached]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    var total = cached.fold<int>(0, (sum, e) => sum + e.fileSizeBytes);
    final toEvict = <CachedMediaEntry>[];
    for (final entry in sorted) {
      if (total <= maxBytes) break;
      toEvict.add(entry);
      total -= entry.fileSizeBytes;
    }
    return toEvict;
  }
}
