import 'command_executor.dart';
import 'compliance_service.dart';
import 'media_cache_store.dart';
import 'sync_service.dart';

/// Core sync + compliance-check round with no UI dependency, so it can run
/// from a background isolate (FCM background handler) as well as from a
/// foreground caller. SlideshowScreen keeps its own injected service
/// instances for testability and does not call this -- this exists
/// specifically for contexts with no live widget tree to inject into.
Future<SyncResult> performBackgroundSync({String? fcmToken}) async {
  final syncService = SyncService();
  final cacheStore = MediaCacheStore();
  final complianceService = ComplianceService();
  final commandExecutor = CommandExecutor(
    syncService: syncService,
    cacheStore: cacheStore,
    complianceService: complianceService,
  );

  final result = await syncService.sync(fcmToken: fcmToken);

  final commands = await complianceService.submitHeartbeat();
  for (final command in commands) {
    await commandExecutor.execute(command);
  }

  return result;
}
