import 'dart:convert';

import 'package:flutter/foundation.dart';

/// In-process signal (not a real event bus) that a live SlideshowScreen
/// registers itself with, so an incoming FCM data message can nudge its
/// already-running sync loop immediately instead of waiting for the next
/// timer tick. Dart port of smile_0_1's KioskSyncSignal.
class PushSyncSignal {
  static void Function()? onSyncRequested;

  /// The app's remote control (notify-frame, 2026-10-14): "pause", "play",
  /// "next", "back", "newest", or "show" with a media_item_id.
  static void Function(String command, Map<String, dynamic> data)? onCommand;

  /// The Frame's settings, carried along by a push after a change of the
  /// Frame (sync-fanout, 2026-10-27): shown at once, the sync follows.
  static void Function(Map<String, dynamic> settings)? onSettings;

  static void requestSync() {
    onSyncRequested?.call();
  }

  /// A push from the Frame's data messages: a command, or "sync now".
  static void handle(Map<String, dynamic> data) {
    debugPrint('SmileFrameTiming: push ${data['type']} ${data['command'] ?? ''}');
    final command = data['command'];
    if (data['type'] == 'command' && command is String) {
      onCommand?.call(command, data);
      return;
    }
    final settings = data['settings'];
    if (settings is String && settings.isNotEmpty) {
      try {
        onSettings?.call((jsonDecode(settings) as Map).cast<String, dynamic>());
      } catch (_) {
        // The sync below brings them anyway.
      }
    }
    requestSync();
  }
}
