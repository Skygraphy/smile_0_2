import 'package:flutter/foundation.dart';

/// Measuring instead of guessing (2026-10-12, "alles ist noch viel zu
/// langsam"): milliseconds since the app started, at the moments that
/// matter. Only in the log (`adb logcat | grep SmilePerf`), never on screen.
class Perf {
  Perf._();

  static final _clock = Stopwatch()..start();
  static final Map<String, Stopwatch> _spans = {};

  /// Since the app started.
  static void mark(String what) => debugPrint('SmilePerf: ${_clock.elapsedMilliseconds} ms  $what');

  /// A span of its own, e.g. opening one album.
  static void start(String span) => _spans[span] = Stopwatch()..start();

  static void end(String span, [String? detail]) {
    final watch = _spans.remove(span);
    if (watch == null) return;
    debugPrint('SmilePerf: $span took ${watch.elapsedMilliseconds} ms${detail == null ? '' : '  $detail'}');
  }
}
