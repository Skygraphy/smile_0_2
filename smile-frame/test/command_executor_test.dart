import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smile_frame/services/command_executor.dart';
import 'package:smile_frame/services/compliance_service.dart';
import 'package:smile_frame/services/kiosk_lockdown.dart';
import 'package:smile_frame/services/media_cache_store.dart';
import 'package:smile_frame/services/media_cache_sync.dart';
import 'package:smile_frame/services/sync_service.dart';

class MockSyncService extends Mock implements SyncService {}

class MockMediaCacheStore extends Mock implements MediaCacheStore {}

class MockComplianceService extends Mock implements ComplianceService {}

class MockKioskLockdown extends Mock implements KioskLockdown {}

void main() {
  late MockSyncService syncService;
  late MockMediaCacheStore cacheStore;
  late MockComplianceService complianceService;
  late MockKioskLockdown kioskLockdown;
  late CommandExecutor executor;

  setUp(() {
    syncService = MockSyncService();
    cacheStore = MockMediaCacheStore();
    complianceService = MockComplianceService();
    kioskLockdown = MockKioskLockdown();
    executor = CommandExecutor(
      syncService: syncService,
      cacheStore: cacheStore,
      complianceService: complianceService,
      kioskLockdown: kioskLockdown,
    );
    when(() => complianceService.reportCommandStatus(
          commandId: any(named: 'commandId'),
          status: any(named: 'status'),
          resultDetail: any(named: 'resultDetail'),
        )).thenAnswer((_) async {});
  });

  test('refresh_policy triggers a sync and reports completed', () async {
    when(() => syncService.sync()).thenAnswer(
      (_) async => SyncResult(channelId: null, entries: const [], policy: null, assignedChannels: const []),
    );

    await executor.execute(RemoteCommand(id: 'cmd-1', commandType: 'refresh_policy'));

    verify(() => syncService.sync()).called(1);
    verify(() => complianceService.reportCommandStatus(commandId: 'cmd-1', status: 'completed')).called(1);
  });

  test('clear_media_cache deletes every cached file and empties the index', () async {
    when(() => cacheStore.readIndex()).thenAnswer((_) async => [
          CachedMediaEntry(
            mediaItemId: 'a',
            mediaType: 'photo',
            sortOrder: 1,
            fileName: 'a.jpg',
            fileSizeBytes: 100,
            cachedAt: DateTime(2026),
          ),
        ]);
    when(() => cacheStore.deleteFile(any())).thenAnswer((_) async {});
    when(() => cacheStore.writeIndex(any())).thenAnswer((_) async {});

    await executor.execute(RemoteCommand(id: 'cmd-2', commandType: 'clear_media_cache'));

    verify(() => cacheStore.deleteFile('a.jpg')).called(1);
    verify(() => cacheStore.writeIndex([])).called(1);
    verify(() => complianceService.reportCommandStatus(commandId: 'cmd-2', status: 'completed')).called(1);
  });

  test('restart_app reports completed before restarting the process', () async {
    when(() => kioskLockdown.restart()).thenAnswer((_) async {});

    await executor.execute(RemoteCommand(id: 'cmd-3', commandType: 'restart_app'));

    verifyInOrder([
      () => complianceService.reportCommandStatus(commandId: 'cmd-3', status: 'completed'),
      () => kioskLockdown.restart(),
    ]);
  });

  test('force_update reports failed -- no distribution channel wired up yet', () async {
    await executor.execute(RemoteCommand(id: 'cmd-4', commandType: 'force_update'));

    verify(() => complianceService.reportCommandStatus(
          commandId: 'cmd-4',
          status: 'failed',
          resultDetail: {'reason': 'no_update_channel_configured'},
        )).called(1);
  });

  test('unknown command type reports failed', () async {
    await executor.execute(RemoteCommand(id: 'cmd-5', commandType: 'something_else'));

    verify(() => complianceService.reportCommandStatus(
          commandId: 'cmd-5',
          status: 'failed',
          resultDetail: {'reason': 'unknown_command_type'},
        )).called(1);
  });
}
