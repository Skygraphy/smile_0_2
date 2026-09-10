import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'background_sync.dart';
import 'push_sync_signal.dart';

/// Data-only message, no notification payload (concept doc sect. 30:
/// push + polling hybrid). Runs in a freshly spawned, separate isolate
/// with none of the running app's state -- must initialize its own
/// Flutter/Firebase bindings and build its own service instances
/// (performBackgroundSync), it cannot reach into a live SlideshowScreen.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await performBackgroundSync();
}

class PushService {
  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Only fires while the app is genuinely foregrounded from FCM's own
    // point of view; observed in practice to be less reliable for this
    // kiosk app than the background handler above, which is why that path
    // does real work too instead of being a pure no-op.
    FirebaseMessaging.onMessage.listen((_) => PushSyncSignal.requestSync());
  }

  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
