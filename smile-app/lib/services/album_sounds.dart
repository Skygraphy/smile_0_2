import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Töne im Album" (2026-10-27, like WhatsApp's chat tones): a soft plop
/// when one's own photos or videos have been sent, a quieter one when
/// someone else's arrive in the album that is open. Android plays them
/// (AlbumSounds.kt) and stays quiet while the phone is on silent or vibrate;
/// never while Smile is in the background, never on a Frame.
class AlbumSounds {
  AlbumSounds._();

  static const _channel = MethodChannel('smile/sounds');
  static const _key = 'album_sounds';

  /// For the switch in Einstellungen; on unless switched off.
  static final enabled = ValueNotifier<bool>(true);

  /// Plops still to come: one per sent photo or video, a short gap apart
  /// so each one is heard (Ernst 2026-10-27: "pro Medium einen Ton").
  static int _pending = 0;
  static Timer? _sent;

  static Future<void> load() async {
    try {
      enabled.value = (await SharedPreferences.getInstance()).getBool(_key) ?? true;
    } catch (_) {}
  }

  static Future<void> setEnabled(bool on) async {
    enabled.value = on;
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, on);
    } catch (_) {}
  }

  /// One photo or video is sent: one plop, after any still waiting.
  static void sent() {
    _pending++;
    _sent ??= Timer.periodic(const Duration(milliseconds: 260), (timer) {
      if (_pending == 0) {
        timer.cancel();
        _sent = null;
        return;
      }
      _pending--;
      _play('send');
    });
  }

  /// Someone else's photos or videos arrived in the open album.
  static void received() => _play('receive');

  static void _play(String name) {
    if (!enabled.value) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    // Not there in the background sender (UploadWorker): nothing to play.
    unawaited(_channel.invokeMethod<void>('play', name).catchError((_) {}));
  }
}
