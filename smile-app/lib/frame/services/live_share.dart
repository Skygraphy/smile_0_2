import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import 'frame_credentials_store.dart';

/// "Was sieht Oma gerade?" (2026-11-18, migrations/0107): while the Space's
/// Admin or a Co-Admin looks, the Frame sends a picture of its own screen
/// every few seconds (frame-live, action upload). The server answers whether
/// to go on and who is looking -- the Frame shows that name the whole time.
/// Nothing stays on the server; the look ends by itself after 5 minutes.
class LiveShare {
  LiveShare({http.Client? httpClient, FrameCredentialsStore? credentialsStore})
      : _http = httpClient ?? http.Client(),
        _credentials = credentialsStore ?? FrameCredentialsStore();

  final http.Client _http;
  final FrameCredentialsStore _credentials;

  static const _every = Duration(milliseconds: 1500);
  // Never longer than the server allows, even if its answers get lost.
  static const _longest = Duration(minutes: 6);

  bool _running = false;

  /// Starts sending (a push "live" arrived); does nothing while it runs.
  /// [capture] returns the screen as JPEG (PNG if that fails), [state] what the Frame does
  /// right now. [onWatcher] gets the name to show, null when it ends.
  Future<void> run({
    required Future<Uint8List?> Function() capture,
    required Map<String, dynamic> Function() state,
    required void Function(String? watcher) onWatcher,
    String? watcher,
  }) async {
    if (_running) return;
    _running = true;
    if (watcher != null) onWatcher(watcher);
    final until = DateTime.now().add(_longest);
    var failures = 0;
    try {
      while (DateTime.now().isBefore(until)) {
        final started = DateTime.now();
        final token = await _credentials.accessToken;
        if (token == null) break;
        Uint8List? png;
        try {
          png = await capture();
        } catch (e) {
          debugPrint('LiveShare: capture failed $e');
        }
        try {
          final response = await _http
              .post(
                Uri.parse(BackendConfig.functionUrl('frame-live')),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'action': 'upload',
                  'access_token': token,
                  'image': ?(png == null ? null : base64Encode(png)),
                  'state': state(),
                }),
              )
              .timeout(BackendConfig.requestTimeout);
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['go_on'] != true) break;
          failures = 0;
          final name = body['watcher'] as String?;
          if (name != null) onWatcher(name);
        } catch (e) {
          // Offline for a moment: try a few times, then stop quietly.
          if (++failures >= 5) break;
        }
        final wait = _every - DateTime.now().difference(started);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
    } finally {
      _running = false;
      onWatcher(null);
    }
  }
}
