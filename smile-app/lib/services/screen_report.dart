import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:smile_design_system/smile_design_system.dart';

/// "Screenshot melden" (2026-11-21): someone takes a screenshot in Smile
/// (Android 14+ tells us, MainActivity.kt) -> a short hint "Melden" -> the
/// Hilfe & Feedback form opens with that screen attached, "Etwas geht
/// nicht" chosen, and where it happened plus the app's last errors along.
///
/// The picture is Smile's own screen ([boundaryKey] around the whole app),
/// so no access to the gallery is needed.
class ScreenReport {
  ScreenReport._();

  static const _channel = MethodChannel('smile/screen_capture');

  /// Around the whole app (MaterialApp.builder).
  static final boundaryKey = GlobalKey();

  /// Knows the screen on top (MaterialApp.navigatorObservers).
  static final observer = _TopRouteObserver();

  static bool _started = false;
  static bool _busy = false;

  /// [open] shows the form: (picture, where it happened).
  static void start({
    required GlobalKey<ScaffoldMessengerState> messenger,
    required void Function(Uint8List picture, String? screen) open,
  }) {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'captured' || _busy) return;
      final screen = currentScreen();
      // A screenshot of the form itself is no report.
      if (screen == 'FeedbackScreen') return;
      _busy = true;
      try {
        final picture = await capture();
        if (picture == null) return;
        final state = messenger.currentState;
        final context = messenger.currentContext;
        if (state == null || context == null || !context.mounted) return;
        final t = SmileTexts.of(context);
        state.hideCurrentSnackBar();
        state.showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(picture, width: 26, height: 44, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.screenshotTaken, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(t.screenshotAsk),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(label: t.screenshotReport, onPressed: () => open(picture, screen)),
        ));
      } catch (e) {
        debugPrint('ScreenReport: $e');
      } finally {
        _busy = false;
      }
    });
  }

  /// Smile's own screen right now as a JPEG (at most ~1080 px wide).
  static Future<Uint8List?> capture() async {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || boundary.size.isEmpty) return null;
    final view = ui.PlatformDispatcher.instance.views.first;
    final ratio = math.min(view.devicePixelRatio, 1080 / boundary.size.width);
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return await FlutterImageCompress.compressWithList(png.buffer.asUint8List(), format: CompressFormat.jpeg, quality: 80);
    } finally {
      image.dispose();
    }
  }

  /// Where it happened: a screen's own label ([FeedbackScreenLabel]), else
  /// the screen's class name (shown as is on the website).
  static String? currentScreen() {
    final route = observer.top;
    if (route is! ModalRoute) return null;
    final context = route.subtreeContext;
    if (context == null) return null;
    String? found;
    var depth = 0;
    void visit(Element e) {
      if (found != null || depth > 60) return;
      final w = e.widget;
      if (w is FeedbackScreenLabel) {
        found = (w as FeedbackScreenLabel).feedbackLabel;
        return;
      }
      final name = w.runtimeType.toString();
      if (name.endsWith('Screen') || name.endsWith('Shell')) {
        found = name;
        return;
      }
      depth++;
      e.visitChildren(visit);
      depth--;
    }

    try {
      (context as Element).visitChildren(visit);
    } catch (_) {}
    return found;
  }
}

/// A screen that says better than its class name where someone is, e.g.
/// Album „Urlaub Kroatien“ (goes to the Verwaltung only, in German).
abstract interface class FeedbackScreenLabel {
  String get feedbackLabel;
}

class _TopRouteObserver extends NavigatorObserver {
  final _stack = <Route<dynamic>>[];

  Route<dynamic>? get top => _stack.isEmpty ? null : _stack.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _stack[i] = newRoute;
    } else {
      if (oldRoute != null) _stack.remove(oldRoute);
      if (newRoute != null) _stack.add(newRoute);
    }
  }
}

/// The app's last technical errors (2026-11-21), kept in memory only and
/// sent along with a report -- seen by the Verwaltung, never by the person.
class ErrorTrail {
  ErrorTrail._();

  static const _max = 15;
  static const _maxAge = Duration(hours: 1);
  static final _entries = <({DateTime at, String text})>[];

  static void record(Object error) {
    var text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 400) text = '${text.substring(0, 397)}…';
    if (text.isEmpty) return;
    _entries.add((at: DateTime.now(), text: text));
    if (_entries.length > _max) _entries.removeAt(0);
  }

  /// Newest first, the last hour.
  static List<Map<String, String>> recent() {
    final since = DateTime.now().subtract(_maxAge);
    return [
      for (final e in _entries.reversed)
        if (e.at.isAfter(since)) {'at': e.at.toUtc().toIso8601String(), 'text': e.text},
    ];
  }
}
