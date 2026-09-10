import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smile_frame/main.dart';
import 'package:smile_frame/screens/pairing_screen.dart';
import 'package:smile_frame/screens/slideshow_screen.dart';
import 'package:smile_frame/services/device_credentials_store.dart';
import 'package:smile_frame/services/media_cache_store.dart';
import 'package:smile_frame/services/pairing_service.dart';
import 'package:smile_frame/services/sync_service.dart';

class MockDeviceCredentialsStore extends Mock implements DeviceCredentialsStore {}

class MockPairingService extends Mock implements PairingService {}

class MockMediaCacheStore extends Mock implements MediaCacheStore {}

class MockSyncService extends Mock implements SyncService {}

void main() {
  testWidgets('StartupGate shows PairingScreen when unprovisioned', (tester) async {
    final store = MockDeviceCredentialsStore();
    when(() => store.isProvisioned()).thenAnswer((_) async => false);
    final pairingService = MockPairingService();
    // Never resolves -- keeps PairingScreen in its initial loading state
    // without ever scheduling the periodic poll Timer, so the test has no
    // pending timers to clean up.
    when(() => pairingService.requestPairing()).thenAnswer((_) => Completer<PairingRequest>().future);

    await tester.pumpWidget(MaterialApp(
      home: StartupGate(credentialsStore: store, pairingService: pairingService),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PairingScreen), findsOneWidget);
    expect(find.text('Code wird angefordert...'), findsOneWidget);
  });

  testWidgets('StartupGate shows SlideshowScreen when a device_id is already stored', (tester) async {
    final store = MockDeviceCredentialsStore();
    when(() => store.isProvisioned()).thenAnswer((_) async => true);
    when(() => store.deviceId).thenAnswer((_) async => 'test-device-id');

    final cacheStore = MockMediaCacheStore();
    when(() => cacheStore.resolvedDirectoryPath()).thenAnswer((_) async => '/tmp/media_cache');
    when(() => cacheStore.readIndex()).thenAnswer((_) async => []);

    final syncService = MockSyncService();
    // Never resolves -- keeps SlideshowScreen in its initial "loading"
    // state deterministically, avoiding a real network call in the test.
    when(() => syncService.sync()).thenAnswer((_) => Completer<SyncResult>().future);

    await tester.pumpWidget(MaterialApp(
      home: StartupGate(credentialsStore: store, syncService: syncService, cacheStore: cacheStore),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SlideshowScreen), findsOneWidget);
  });
}
