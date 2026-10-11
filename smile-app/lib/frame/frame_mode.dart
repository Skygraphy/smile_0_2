import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'services/frame_credentials_store.dart';

/// One app for everything (decided 2026-10-11): a device runs Smile either
/// as a person's app or as a Frame -- never both at once. It is a Frame
/// exactly while it holds a Frame's credentials (FrameCredentialsStore),
/// the same rule the former Smile-Frame app used at start.
///
/// Only in Frame mode: the screen stays on and shows over the lock screen,
/// and the app comes back after a reboot (MainActivity.kt,
/// BootCompletedReceiver.kt read the marker file below).
class FrameMode {
  FrameMode._();

  /// null until checked at start; then true (Frame) or false (person).
  static final active = ValueNotifier<bool?>(null);

  static const _window = MethodChannel('smile/frame_window');

  static Future<void> detect() async {
    final provisioned = await FrameCredentialsStore().isProvisioned();
    await _apply(provisioned);
  }

  /// Just paired: from here on this device is a Frame.
  static Future<void> enter() => _apply(true);

  /// Unpaired (the Frame was deleted or revoked for good): a normal Smile
  /// app again, starting at the sign-in.
  static Future<void> leave() async {
    try {
      await FrameCredentialsStore().clear();
    } catch (_) {}
    await _apply(false);
  }

  static Future<void> _apply(bool frame) async {
    try {
      final marker = File('${(await getApplicationSupportDirectory()).path}/frame_mode');
      if (frame) {
        await marker.writeAsString('1');
      } else if (await marker.exists()) {
        await marker.delete();
      }
    } catch (_) {}
    try {
      await _window.invokeMethod<void>('setFrameMode', frame);
    } catch (_) {}
    active.value = frame;
  }
}
