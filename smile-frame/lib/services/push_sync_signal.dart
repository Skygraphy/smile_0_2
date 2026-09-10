/// In-process signal (not a real event bus) that a live SlideshowScreen
/// registers itself with, so an incoming FCM data message can nudge its
/// already-running sync loop immediately instead of waiting for the next
/// timer tick. Dart port of smile_0_1's KioskSyncSignal.
class PushSyncSignal {
  static void Function()? onSyncRequested;

  static void requestSync() {
    onSyncRequested?.call();
  }
}
