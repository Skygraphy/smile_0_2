import 'package:flutter/services.dart';

/// Thin wrapper around the native Screen Pinning platform channel
/// (KioskLockdownPlugin.kt on Android). Failures are swallowed on purpose
/// -- pinning is a best-effort hardening layer, not something that should
/// ever crash or block the slideshow from displaying.
class KioskLockdown {
  static const _channel = MethodChannel('com.smile.frame/kiosk_lockdown');

  Future<void> pin() async {
    try {
      await _channel.invokeMethod('pin');
    } on MissingPluginException {
      // No native handler registered (e.g. running in a widget test, or on
      // a platform without this channel) -- safe to ignore.
    } on PlatformException {
      // Not available/permitted right now; the next periodic call retries.
    }
  }

  /// Returns the live pinned status, or null if it can't be determined
  /// right now -- distinct from a confirmed "not pinned". In particular,
  /// this is null when called from the FCM background handler's headless
  /// engine, which has no MainActivity and thus no native handler for this
  /// channel at all.
  Future<bool?> checkStatus() async {
    try {
      return await _channel.invokeMethod<bool>('checkStatus');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// restart_app remote command. Kills and relaunches the process -- does
  /// not return normally, so call this only after anything that must
  /// survive the restart (e.g. reporting the command as completed) is done.
  Future<void> restart() async {
    try {
      await _channel.invokeMethod('restart');
    } on MissingPluginException {
      // No native handler (e.g. widget test) -- nothing to do.
    } on PlatformException {
      // Best-effort; if this fails there's no process left to retry from.
    }
  }

  /// Shows the OS's one-time "Set as Home app?" dialog if the role isn't
  /// already held. Holding this role -- not Screen Pinning -- is what lets
  /// the Frame reappear on its own after a reboot: a system-initiated Home
  /// launch at boot is exempt from Android's background-activity-start
  /// restriction, unlike BootCompletedReceiver's direct startActivity()
  /// call. Best-effort and idempotent, same as pin() above.
  Future<void> requestHomeRoleIfNeeded() async {
    try {
      await _channel.invokeMethod('requestHomeRoleIfNeeded');
    } on MissingPluginException {
      // No native handler (e.g. widget test) -- nothing to do.
    } on PlatformException {
      // Best-effort; the next resume retries.
    }
  }
}
