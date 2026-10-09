import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smile_app/services/offline.dart';
import 'package:smile_app/services/offline_http_client.dart';

// Every screen works offline with what it showed last (2026-10-09).
void main() {
  late Directory dir;
  var online = true;

  OfflineCachingClient client() => OfflineCachingClient(
        currentUserId: () => 'user-1',
        directory: dir,
        inner: MockClient((request) async {
          if (!online) throw const SocketException('Failed host lookup');
          return http.Response('{"albums":["Enkelkinder"]}', 200, headers: {'content-type': 'application/json'});
        }),
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('offline_cache_test');
    online = true;
  });

  tearDown(() => dir.delete(recursive: true));

  final listUrl = Uri.parse('https://x.supabase.co/functions/v1/list-my-channels');
  final tableUrl = Uri.parse('https://x.supabase.co/rest/v1/spaces?select=id,name');

  test('a reading request is answered from the phone while offline', () async {
    final c = client();
    expect((await c.post(listUrl, body: '{}')).body, contains('Enkelkinder'));
    expect((await c.get(tableUrl)).statusCode, 200);

    online = false;
    final offlineList = await c.post(listUrl, body: '{}');
    expect(offlineList.statusCode, 200);
    expect(offlineList.body, contains('Enkelkinder'));
    expect((await c.get(tableUrl)).statusCode, 200);
    expect(Offline.isOffline.value, isTrue);

    online = true;
    await c.get(tableUrl);
    expect(Offline.isOffline.value, isFalse);
  });

  test('changes are never answered from the phone', () async {
    final c = client();
    final patch = Uri.parse('https://x.supabase.co/rest/v1/spaces?id=eq.1');
    await c.patch(patch, body: '{"name":"A"}');
    online = false;
    expect(() => c.patch(patch, body: '{"name":"A"}'), throwsA(isA<SocketException>()));
  });

  test('something never loaded still fails offline', () async {
    online = false;
    expect(() => client().get(tableUrl), throwsA(isA<SocketException>()));
  });
}
