import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:smile_frame/services/cache_cipher.dart';
import 'package:smile_frame/services/frame_credentials_store.dart';
import 'package:smile_frame/services/media_cache_store.dart';
import 'package:smile_frame/services/media_cache_sync.dart';
import 'package:smile_frame/services/sync_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockFrameCredentialsStore extends Mock implements FrameCredentialsStore {}

/// The Keystore-backed secure storage doesn't exist in unit tests --
/// CacheCipher just gets a fresh key each run, which is all these tests need.
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(http.Request('GET', Uri.parse('https://example.com')));
  });

  late MockHttpClient httpClient;
  late MockFrameCredentialsStore credentialsStore;
  late Directory tempDir;
  late MediaCacheStore cacheStore;
  late SyncService service;

  setUp(() async {
    httpClient = MockHttpClient();
    credentialsStore = MockFrameCredentialsStore();
    tempDir = await Directory.systemTemp.createTemp('sync_service_test_');
    final secureStorage = MockSecureStorage();
    when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => secureStorage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((_) async {});
    cacheStore = MediaCacheStore(cacheDirectory: tempDir, cipher: CacheCipher(storage: secureStorage));
    service = SyncService(credentialsStore: credentialsStore, cacheStore: cacheStore, httpClient: httpClient);

    when(() => credentialsStore.accessToken).thenAnswer((_) async => 'test-token');
    // No token-expiry/frame-id/refresh-secret stubbed with real values --
    // _refreshIfNeeded reads all three and bails out early whenever any of
    // them is null, which keeps this test focused on the pagination loop.
    when(() => credentialsStore.accessTokenExpiresAt).thenAnswer((_) async => null);
    when(() => credentialsStore.frameId).thenAnswer((_) async => null);
    when(() => credentialsStore.refreshSecret).thenAnswer((_) async => null);
    when(() => credentialsStore.preferredChannelId).thenAnswer((_) async => null);
    when(() => credentialsStore.lastSyncOkAt).thenAnswer((_) async => null);
    when(() => credentialsStore.saveLastSyncOkAt(any())).thenAnswer((_) async {});

    // Media downloads are streamed (videos of any length), posters are small gets.
    when(() => httpClient.send(any())).thenAnswer(
      (_) async => http.StreamedResponse(Stream.value([1, 2, 3]), 200),
    );
    when(() => httpClient.get(any())).thenAnswer((_) async => http.Response.bytes([1, 2, 3], 200));
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('follows next_cursor across get-media-batch pages and merges all items', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((invocation) async {
      final body = jsonDecode(invocation.namedArguments[#body] as String) as Map<String, dynamic>;
      if (body['cursor'] == null) {
        return http.Response(
          jsonEncode({
            'channel_id': 'chan-1',
            'items': [
              {
                'media_item_id': 'item-1',
                'media_type': 'photo',
                'sort_order': 1,
                'display_url': 'https://example.com/1.jpg',
              },
            ],
            'next_cursor': 100,
            'settings': null,
            'assigned_channels': [],
            'space_name': 'Test Space',
          }),
          200,
        );
      }
      expect(body['cursor'], 100);
      return http.Response(
        jsonEncode({
          'channel_id': 'chan-1',
          'items': [
            {
              'media_item_id': 'item-2',
              'media_type': 'photo',
              'sort_order': 2,
              'display_url': 'https://example.com/2.jpg',
            },
          ],
          'next_cursor': null,
          'settings': null,
          'assigned_channels': [],
          'space_name': 'Test Space',
        }),
        200,
      );
    });

    final result = await service.sync();

    verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(2);
    expect(result.entries.map((e) => e.mediaItemId).toSet(), {'item-1', 'item-2'});
    expect(result.channelId, 'chan-1');
    expect(result.spaceName, 'Test Space');
  });

  test('stops after a single page when next_cursor is null', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'channel_id': 'chan-1',
          'items': <Map<String, dynamic>>[],
          'next_cursor': null,
          'settings': null,
          'assigned_channels': [],
          'space_name': 'Test Space',
        }),
        200,
      ),
    );

    await service.sync();

    verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });

  // Architecture review 2026-09-29, weakness 7.
  test('photos are stored encrypted and read back intact', () async {
    await cacheStore.writeMedia('a.jpg', [1, 2, 3, 4, 5]);
    final onDisk = await File('${tempDir.path}/a.jpg').readAsBytes();
    expect(onDisk, isNot(equals([1, 2, 3, 4, 5])), reason: 'no plain photo bytes at rest');
    expect(await cacheStore.readMedia('a.jpg'), equals([1, 2, 3, 4, 5]));
  });

  test('after more than maxOffline without the server, the photos are wiped', () async {
    await cacheStore.writeMedia('old.jpg', [9, 9, 9]);
    await cacheStore.writeIndex([
      CachedMediaEntry(
        mediaItemId: 'old',
        mediaType: 'photo',
        sortOrder: 1,
        fileName: 'old.jpg',
        fileSizeBytes: 3,
        cachedAt: DateTime(2026),
      ),
    ]);
    when(() => credentialsStore.lastSyncOkAt)
        .thenAnswer((_) async => DateTime.now().subtract(SyncService.maxOffline + const Duration(days: 1)));
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenThrow(const SocketException('offline'));

    final result = await service.sync();

    expect(result.offlineExpired, isTrue);
    expect(await cacheStore.readIndex(), isEmpty);
    expect(await File('${tempDir.path}/old.jpg').exists(), isFalse);
  });

  test('a multi-block file (like a long video) round-trips and stays encrypted at rest', () async {
    final plain = List<int>.generate(CacheCipher.blockSize * 2 + 4321, (i) => i % 251);
    await cacheStore.writeMediaStream('clip.mp4', Stream.fromIterable([plain.sublist(0, 700000), plain.sublist(700000)]));
    final onDisk = await File('${tempDir.path}/clip.mp4').readAsBytes();
    expect(onDisk.length, plain.length + 3 * 28, reason: 'three sealed blocks');
    expect(await cacheStore.readMedia('clip.mp4'), equals(plain));
  });
}
