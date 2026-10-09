import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app also works offline -- at least for looking at photos (decided
/// 2026-10-09): what was loaded last is kept on the phone and shown, with
/// a quiet hint instead of an error.
class Offline {
  Offline._();

  /// True while the last server request failed for lack of a connection.
  /// Screens show the offline hint while it is set.
  static final isOffline = ValueNotifier<bool>(false);

  static void reachedServer() => isOffline.value = false;

  /// No connection (as opposed to a real refusal by the server).
  static bool isConnectionError(Object error) {
    if (error is SocketException || error is TimeoutException || error is HttpException) return true;
    final text = '$error';
    return text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException') ||
        text.contains('Connection closed') ||
        text.contains('Connection refused') ||
        text.contains('Connection reset') ||
        text.contains('Network is unreachable') ||
        text.contains('AuthRetryableFetchException');
  }

  /// Notes a failed request; returns whether it was a missing connection.
  static bool noteFailure(Object error) {
    final offline = isConnectionError(error);
    if (offline) isOffline.value = true;
    return offline;
  }

  // --- Small key/value store for what to show offline -------------------
  static Future<String?> read(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, value);
    } catch (_) {}
  }
}
