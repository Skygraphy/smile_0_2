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

  static OverlayEntry? _hint;
  static Timer? _hintTimer;

  /// [open] shows the form: (picture, where it happened).
  static void start({
    required GlobalKey<NavigatorState> navigator,
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
        final overlay = navigator.currentState?.overlay;
        if (picture == null || overlay == null || !overlay.mounted) return;
        _showHint(overlay, picture, () {
          _hideHint();
          open(picture, screen);
        });
      } catch (e) {
        debugPrint('ScreenReport: $e');
      } finally {
        _busy = false;
      }
    });
  }

  /// At the top: the bottom is taken by the phone's own screenshot bar
  /// and Smile's tip cards. Goes away by itself after 12 seconds (Samsung's
  /// own screenshot bar takes the touches for the first ~4).
  static void _showHint(
    OverlayState overlay,
    Uint8List picture,
    VoidCallback report,
  ) {
    _hideHint();
    final entry = OverlayEntry(
      builder: (context) => _ScreenshotHint(
        picture: picture,
        onReport: report,
        onClose: _hideHint,
      ),
    );
    _hint = entry;
    overlay.insert(entry);
    _hintTimer = Timer(const Duration(seconds: 12), _hideHint);
  }

  static void _hideHint() {
    _hintTimer?.cancel();
    _hintTimer = null;
    _hint?.remove();
    _hint = null;
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
      return await FlutterImageCompress.compressWithList(
        png.buffer.asUint8List(),
        format: CompressFormat.jpeg,
        quality: 80,
      );
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

class _ScreenshotHint extends StatelessWidget {
  const _ScreenshotHint({
    required this.picture,
    required this.onReport,
    required this.onClose,
  });

  final Uint8List picture;
  final VoidCallback onReport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    // The picture the way the screen is: wide on a tablet lying down.
    final wide = MediaQuery.sizeOf(context).aspectRatio > 1;
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * -16),
                child: child,
              ),
            ),
            child: Material(
              color: scheme.surfaceContainerHighest,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onReport,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          picture,
                          width: wide ? 56 : 28,
                          height: wide ? 33 : 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.screenshotTaken,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t.screenshotAsk,
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onReport,
                        child: Text(
                          t.screenshotReport,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(
                          SmileIcons.close,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

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
        if (e.at.isAfter(since))
          {'at': e.at.toUtc().toIso8601String(), 'text': e.text},
    ];
  }
}
