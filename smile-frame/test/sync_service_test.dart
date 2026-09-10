import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:smile_frame/services/device_credentials_store.dart';
import 'package:smile_frame/services/media_cache_store.dart';
import 'package:smile_frame/services/sync_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockDeviceCredentialsStore extends Mock implements DeviceCredentialsStore {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  late MockHttpClient httpClient;
  late MockDeviceCredentialsStore credentialsStore;
  late Directory tempDir;
  late MediaCacheStore cacheStore;
  late SyncService service;

  setUp(() async {
    httpClient = MockHttpClient();
    credentialsStore = MockDeviceCredentialsStore();
    tempDir = await Directory.systemTemp.createTemp('sync_service_test_');
    cacheStore = MediaCacheStore(cacheDirectory: tempDir);
    service = SyncService(credentialsStore: credentialsStore, cacheStore: cacheStore, httpClient: httpClient);

    when(() => credentialsStore.accessToken).thenAnswer((_) async => 'test-token');
    // No token-expiry/device-id/refresh-secret stubbed with real values --
    // _refreshIfNeeded reads all three and bails out early whenever any of
    // them is null, which keeps this test focused on the pagination loop.
    when(() => credentialsStore.accessTokenExpiresAt).thenAnswer((_) async => null);
    when(() => credentialsStore.deviceId).thenAnswer((_) async => null);
    when(() => credentialsStore.refreshSecret).thenAnswer((_) async => null);

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
            'policy': null,
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
          'policy': null,
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
          'policy': null,
          'assigned_channels': [],
          'space_name': 'Test Space',
        }),
        200,
      ),
    );

    await service.sync();

    verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).called(1);
  });
}
