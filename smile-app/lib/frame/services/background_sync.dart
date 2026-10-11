import 'heartbeat_service.dart';
import 'sync_service.dart';

/// Core sync + heartbeat round with no UI dependency, so it can run from a
/// background isolate (FCM background handler) as well as from a
/// foreground caller. SlideshowScreen keeps its own injected service
/// instances for testability and does not call this -- this exists
/// specifically for contexts with no live widget tree to inject into.
Future<SyncResult> performBackgroundSync({String? fcmToken}) async {
  final syncService = SyncService();
  final heartbeatService = HeartbeatService();

  final result = await syncService.sync(fcmToken: fcmToken);
  await heartbeatService.submitHeartbeat(fcmToken: fcmToken);

  return result;
}
