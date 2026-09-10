import 'package:flutter_test/flutter_test.dart';
import 'package:smile_frame/services/media_cache_sync.dart';

CachedMediaEntry _cached(String id, int sortOrder, {int sizeBytes = 1000}) => CachedMediaEntry(
      mediaItemId: id,
      mediaType: 'photo',
      sortOrder: sortOrder,
      fileName: '$id.jpg',
      fileSizeBytes: sizeBytes,
      cachedAt: DateTime(2026, 1, 1),
    );

RemoteMediaEntry _remote(String id, int sortOrder) => RemoteMediaEntry(
      mediaItemId: id,
      mediaType: 'photo',
      sortOrder: sortOrder,
      displayUrl: 'https://example.com/$id.jpg',
    );

void main() {
  group('MediaCacheSync.diff', () {
    test('remote-only items are queued for download', () {
      final diff = MediaCacheSync.diff([_remote('a', 1), _remote('b', 2)], []);
      expect(diff.toDownload.map((e) => e.mediaItemId), ['a', 'b']);
      expect(diff.toDelete, isEmpty);
    });

    test('local-only items are queued for deletion', () {
      final diff = MediaCacheSync.diff([], [_cached('a', 1)]);
      expect(diff.toDownload, isEmpty);
      expect(diff.toDelete.map((e) => e.mediaItemId), ['a']);
    });

    test('items present in both are left alone', () {
      final diff = MediaCacheSync.diff([_remote('a', 1)], [_cached('a', 1)]);
      expect(diff.toDownload, isEmpty);
      expect(diff.toDelete, isEmpty);
    });

    test('mixed: new item downloaded, removed item deleted, unchanged item untouched', () {
      final diff = MediaCacheSync.diff(
        [_remote('a', 1), _remote('c', 3)],
        [_cached('a', 1), _cached('b', 2)],
      );
      expect(diff.toDownload.map((e) => e.mediaItemId), ['c']);
      expect(diff.toDelete.map((e) => e.mediaItemId), ['b']);
    });
  });

  group('MediaCacheSync.entriesToEvictForCap', () {
    test('null cap evicts nothing (unlimited)', () {
      final evicted = MediaCacheSync.entriesToEvictForCap([_cached('a', 1)], null);
      expect(evicted, isEmpty);
    });

    test('under cap evicts nothing', () {
      final cached = [_cached('a', 1, sizeBytes: 100), _cached('b', 2, sizeBytes: 100)];
      expect(MediaCacheSync.entriesToEvictForCap(cached, 1000), isEmpty);
    });

    test('over cap evicts oldest-by-sortOrder first until under the cap', () {
      final cached = [
        _cached('newest', 3, sizeBytes: 100),
        _cached('oldest', 1, sizeBytes: 100),
        _cached('middle', 2, sizeBytes: 100),
      ];
      // total 300, cap 150 -> must evict oldest (sortOrder 1) then middle (sortOrder 2) to reach 100 <= 150
      final evicted = MediaCacheSync.entriesToEvictForCap(cached, 150);
      expect(evicted.map((e) => e.mediaItemId), ['oldest', 'middle']);
    });
  });
}
