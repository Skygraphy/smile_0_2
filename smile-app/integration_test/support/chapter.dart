import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';

/// Records a chapter inside the test app (2026-10-20): the same steps,
/// checks, screenshots, tappable elements and states as the former adb
/// scripts, but found in the widget tree in milliseconds instead of asking
/// the phone for seconds. The app writes screenshots and steps.json itself;
/// tools/testsuite/run.sh starts it and fetches them into `out/chNN`.
class Chapter {
  Chapter(this.tester, this.binding, {required this.id, required this.title, required this.intro}) {
    // Animations (tap ripple, page changes) run 20x faster: the screenshots
    // show the same end state, the waiting for them shrinks to nothing.
    timeDilation = 0.05;
  }

  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final String id;
  final String title;
  final String intro;

  final _steps = <Map<String, Object?>>[];
  final _taps = <List<String>>[];
  String _screen = '';
  int _no = 0;
  Map<String, Object?> _current = {};
  List<Map<String, Object?>> _checks = [];
  Object? _stateBefore;
  ui.Image? _lastShot;

  // ------------------------------------------------------------ recording

  void screen(String name) => _screen = name;

  void step(String title, String doIt, String expect, {String kind = 'Hauptweg', String explain = ''}) {
    _no++;
    _current = {'title': title, 'do': doIt, 'expect': expect, 'kind': kind, 'why': explain};
    _checks = [];
    debugPrint('Schritt $_no: $title');
  }

  Future<void> check(String desc, FutureOr<bool> Function() test) async {
    bool ok;
    try {
      ok = await test();
    } catch (e) {
      ok = false;
    }
    _checks.add({'desc': desc, 'ok': ok});
    if (!ok) debugPrint('  PRÜFUNG FEHLGESCHLAGEN: $desc');
  }

  Future<void> start() async {
    _stateBefore = await state();
  }

  /// Screenshot, tappable elements and state close the step.
  Future<void> snap() async {
    await settle();
    final img = await _grab();
    _lastShot = img;
    final file = File('${(await outDir()).path}/${_no.toString().padLeft(2, '0')}.png');
    // PNG and server state at the same time: both just wait.
    final results = await Future.wait([
      img.toByteData(format: ui.ImageByteFormat.png).then((png) => file.writeAsBytes(png!.buffer.asUint8List())),
      state(),
    ]);
    final after = results[1] as Map<String, Object?>;
    _steps.add({
      'no': _no,
      ..._current,
      'device': 'S26',
      'image': '${_no.toString().padLeft(2, '0')}.png',
      'checks': _checks,
      'screen': _screen,
      'elements': elements(),
      'stateBefore': _stateBefore,
      'stateAfter': after,
    });
    _stateBefore = after;
  }

  /// Where the chapter's results go on the phone; the PC fetches them
  /// (tools/testsuite/run.sh) once done.done or failed.txt is there.
  Future<Directory> outDir() async {
    final dir = Directory('${(await getExternalStorageDirectory())!.path}/testsuite_out/$id');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes steps.json and taps.tsv, then the signal for the PC.
  Future<void> finish({required String appVersion, Object? error}) async {
    final dir = await outDir();
    await File('${dir.path}/steps.json').writeAsString(const JsonEncoder.withIndent(' ').convert(
        {'id': id, 'title': title, 'intro': intro, 'appVersion': appVersion, 'ranAt': DateTime.now().toIso8601String(), 'steps': _steps}));
    await File('${dir.path}/taps.tsv').writeAsString('${_taps.map((t) => t.join('\t')).join('\n')}\n');
    if (error != null) await File('${dir.path}/failed.txt').writeAsString('Schritt $_no (${_current['title']}): $error');
    await File('${dir.path}/done.done').writeAsString('ok');
  }

  /// The screen as the app draws it (straight from its layer: no driver,
  /// no flicker).
  Future<ui.Image> _grab() async {
    await tester.pump();
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    // The root layer already scales to physical pixels: bounds in physical
    // pixels, no second scaling.
    return layer.toImage(Offset.zero & (view.size * tester.view.devicePixelRatio), pixelRatio: 1);
  }

  // ------------------------------------------------------------ state

  /// Server (testsuite_state) and what the app keeps on the phone, with
  /// user ids replaced so runs compare.
  Future<Map<String, Object?>> state() async {
    final server = await TestBackend.state();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final phone = <String, Object?>{};
    for (final k in prefs.getKeys().toList()..sort()) {
      final key = k.replaceAll(RegExp(r'[0-9a-f]{8}-[0-9a-f-]{27}'), '<person>');
      final v = prefs.get(k);
      if (key.contains('auth-token')) {
        phone['angemeldet'] = true;
      } else if (key.startsWith('albums_cache')) {
        try {
          phone[key] = '${(jsonDecode(v as String) as List).length} Alben';
        } catch (_) {
          phone[key] = '?';
        }
      } else {
        phone[key] = v is List ? v.join(',') : '$v';
      }
    }
    phone.putIfAbsent('angemeldet', () => false);
    return {'server': server, 'handy': Map.fromEntries(phone.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))};
  }

  // ------------------------------------------------------------ the screen

  /// Every element a user can tap right now, by its label (the coverage map).
  List<String> elements() {
    final out = <String>[];
    void visit(SemanticsNode n) {
      final d = n.getSemanticsData();
      if (d.hasAction(SemanticsAction.tap) && !n.isInvisible) {
        var label = d.label.replaceAll('\n', ' · ').trim();
        if (d.flagsCollection.isTextField) label = 'Eingabefeld${d.hint.isNotEmpty ? ': ${d.hint}' : (label.isNotEmpty ? ': $label' : '')}';
        if (RegExp(r'^[0-9 ·]+$').hasMatch(label)) label = 'Code-Kästchen';
        if (label.isNotEmpty && !out.contains(label)) out.add(label);
      }
      n.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    final root = tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode ??
        RendererBinding.instance.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
    return out;
  }

  /// Frames until nothing moves any more (at most [max]); never hangs on a
  /// spinner.
  void _slow(String what, Stopwatch sw) {
    if (sw.elapsedMilliseconds > 300) debugPrint('  langsam: $what ${sw.elapsedMilliseconds} ms');
  }

  Future<void> settle({Duration max = const Duration(seconds: 3)}) async {
    final sw = Stopwatch()..start();
    final end = DateTime.now().add(max);
    await tester.pump(const Duration(milliseconds: 50));
    while (DateTime.now().isBefore(end)) {
      if (!tester.binding.hasScheduledFrame) break;
      await tester.pump(const Duration(milliseconds: 50));
    }
    _slow('settle', sw);
  }

  /// Something with this text, label or tooltip (prefix; '~' = contains).
  Finder find_(String what) {
    final contains = what.startsWith('~');
    final w = contains ? what.substring(1) : what;
    bool match(String? s) => s != null && (contains ? s.contains(w) : s.startsWith(w));
    return find.byWidgetPredicate((widget) {
      if (widget is Text) return match(widget.data ?? widget.textSpan?.toPlainText());
      if (widget is EditableText) return match(widget.controller.text);
      if (widget is Tooltip) return match(widget.message);
      if (widget is Semantics) return match(widget.properties.label);
      return false;
    }, skipOffstage: true);
  }

  /// Waits until it is there (real time: the network answers meanwhile).
  Future<bool> waitFor(String what, {double seconds = 10}) async {
    final sw = Stopwatch()..start();
    try {
      return await _waitFor(what, seconds);
    } finally {
      _slow('waitFor $what', sw);
    }
  }

  Future<bool> _waitFor(String what, double seconds) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (true) {
      await tester.pump(const Duration(milliseconds: 60));
      if (find_(what).evaluate().isNotEmpty) return true;
      if (DateTime.now().isAfter(end)) return false;
    }
  }

  Future<bool> gone(String what, {double seconds = 5}) async {
    final sw = Stopwatch()..start();
    try {
      return await _gone(what, seconds);
    } finally {
      _slow('gone $what', sw);
    }
  }

  Future<bool> _gone(String what, double seconds) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (true) {
      await tester.pump(const Duration(milliseconds: 60));
      if (find_(what).evaluate().isEmpty) return true;
      if (DateTime.now().isAfter(end)) return false;
    }
  }

  /// Taps it (the last match with [last], e.g. a dialog button over a row
  /// of the same name); stops the chapter if it isn't there.
  Future<void> tap(String what, {double seconds = 10, bool last = false, bool twice = false}) async {
    if (!await waitFor(what, seconds: seconds)) throw TestFailure('Nicht gefunden: $what');
    final f = last ? find_(what).last : find_(what).first;
    await tester.tap(f, warnIfMissed: false);
    if (twice) await tester.tap(f, warnIfMissed: false);
    _taps.add([_screen, what.replaceFirst('~', '')]);
    await settle();
  }

  /// A tap on a spot (screen coordinates in logical pixels), logged under [label].
  Future<void> tapAt(Offset at, String label) async {
    await tester.tapAt(at);
    _taps.add([_screen, label]);
    await settle();
  }

  /// Logs a tap done directly with the tester (coverage map).
  void logTap(String label) => _taps.add([_screen, label]);

  Future<void> back() async {
    await tester.binding.handlePopRoute();
    _taps.add([_screen, 'Zurück']);
    await settle();
  }

  /// Types into the field labelled [label] ('' = the only or last field) and
  /// checks the text arrived there.
  Future<void> typeInto(String label, String text, {String? logAs}) async {
    final field = find.byWidgetPredicate((w) {
      if (w is! TextField) return false;
      if (label.isEmpty) return true;
      final d = w.decoration;
      return (d?.labelText ?? d?.hintText ?? d?.label?.toString() ?? '').startsWith(label);
    });
    if (!await _waitFinder(field)) throw TestFailure('Eingabefeld nicht gefunden: $label');
    final target = field.last;
    // Tap it first, as a person would: after hideKeyboard the field has no
    // input connection, and enterText alone then goes nowhere.
    await tester.tap(target, warnIfMissed: false);
    await settle();
    await tester.enterText(target, text);
    // Checked at once: a code field sends itself off and empties afterwards.
    final controller = tester.widget<TextField>(target).controller;
    if (controller != null && !controller.text.contains(text)) {
      throw TestFailure('Text kam nicht im Feld $label an: ${controller.text}');
    }
    _taps.add([_screen, logAs ?? 'Eingabefeld${label.isEmpty ? '' : ': $label'}']);
    await settle();
  }

  Future<bool> _waitFinder(Finder f, {double seconds = 10}) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (true) {
      await tester.pump(const Duration(milliseconds: 60));
      if (f.evaluate().isNotEmpty) return true;
      if (DateTime.now().isAfter(end)) return false;
    }
  }

  /// Closes the keyboard (as a user would before looking).
  Future<void> hideKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    // The screen only looks right once the keyboard is really gone (the
    // login hides its big S while it is open).
    final end = DateTime.now().add(const Duration(seconds: 2));
    while (tester.binding.platformDispatcher.views.first.viewInsets.bottom > 0 && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await settle();
  }

  /// The colour at [x],[y] (physical pixels) of the last screenshot is close
  /// to [hex] (each channel within 40).
  Future<bool> colorNear(int x, int y, String hex) async {
    final img = _lastShot;
    if (img == null) return false;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return false;
    final i = (y * img.width + x) * 4;
    final want = [for (var k = 1; k < 7; k += 2) int.parse(hex.substring(k, k + 2), radix: 16)];
    return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)]
        .asMap()
        .entries
        .every((e) => (e.value - want[e.key]).abs() <= 40);
  }

  /// The colour inside the [index]th widget of type [type] (e.g. 'SmileAvatar'),
  /// at [fx],[fy] as fractions of its size, is close to [hex]. Follows the
  /// layout instead of fixed pixels.
  /// Waits up to [seconds] for it: a loaded picture appears a moment later.
  Future<bool> colorIn(String type, String hex,
      {double fx = 0.2, double fy = 0.3, int index = 0, double seconds = 8}) async {
    final f = find.byWidgetPredicate((w) => w.runtimeType.toString() == type);
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (true) {
      await look();
      if (f.evaluate().length > index) {
        final r = tester.getRect(f.at(index));
        final dpr = tester.view.devicePixelRatio;
        if (await colorNear(((r.left + r.width * fx) * dpr).round(), ((r.top + r.height * fy) * dpr).round(), hex)) {
          return true;
        }
      }
      if (DateTime.now().isAfter(end)) return false;
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// Takes a screenshot only to look at it (for [colorNear] before the step's snap).
  Future<void> look() async {
    await settle();
    _lastShot = await _grab();
  }

}
