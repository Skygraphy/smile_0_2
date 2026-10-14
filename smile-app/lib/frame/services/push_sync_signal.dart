/// In-process signal (not a real event bus) that a live SlideshowScreen
/// registers itself with, so an incoming FCM data message can nudge its
/// already-running sync loop immediately instead of waiting for the next
/// timer tick. Dart port of smile_0_1's KioskSyncSignal.
class PushSyncSignal {
  static void Function()? onSyncRequested;

  /// The app's remote control (notify-frame, 2026-10-14): "pause", "play",
  /// "next", "back", "newest", or "show" with a media_item_id.
  static void Function(String command, Map<String, dynamic> data)? onCommand;

  static void requestSync() {
    onSyncRequested?.call();
  }

  /// A push from the Frame's data messages: a command, or "sync now".
  static void handle(Map<String, dynamic> data) {
    final command = data['command'];
    if (data['type'] == 'command' && command is String) {
      onCommand?.call(command, data);
      return;
    }
    requestSync();
  }
}
