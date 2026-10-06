import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'sync_bus.dart';

/// Real system notifications while the app is OPEN -- FCM only shows its
/// own notification payloads while the app is in the background or closed.
/// "Alles komplett interaktiv" (decision 2026-10-05): an open app must not
/// swallow an invite or a new photo into a SnackBar that is easy to miss.
///
/// The one exception mirrors WhatsApp: a new photo in the album the user
/// is looking at right now is already on screen, so it isn't announced.
class ForegroundNotifications {
  ForegroundNotifications._();

  /// Same id as the manifest's default_notification_channel_id, so pushes
  /// arriving while the app is closed use the same channel (heads-up).
  static const channelId = 'smile_events';

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Set by the open album feed (and cleared when it closes).
  static String? openAlbumId;

  static Future<void> init({required void Function(Map<String, dynamic> data) onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_smile')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        onTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            'Smile',
            description: 'Neue Fotos, Einladungen, Anfragen und Änderungen in deinen Alben und Spaces',
            importance: Importance.high,
          ),
        );
  }

  static Future<void> show(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final data = message.data;
    // The server kept a copy for the Neuigkeiten history (migrations/0059):
    // an open Neuigkeiten picks it up right away.
    SyncBus.emit(const SyncEvent(tables: {'user_notifications'}, channelIds: {}, spaceIds: {}));
    if (data['type'] == 'new_photo' && data['channel_id'] != null && data['channel_id'] == openAlbumId) return;
    await _plugin.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Smile',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_smile',
        ),
      ),
      payload: jsonEncode(data),
    );
  }
}
