// Kapitel 13: Frame im Alltag, Teil am Tablet (X200).
// Läuft gleichzeitig mit ch13_test.dart am Handy: verbindet sich selbst mit
// dem Frame Wohnzimmer (wie in Kapitel 8), macht nach jedem Signal des
// Handys (pN) sein Bild und antwortet (fN). Dazwischen tippt Oma Hilde
// selbst: anhalten, neue Fotos ansehen, Code eingeben.
import 'dart:async';

import 'package:flutter/material.dart' show ModalBarrier, debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/frame/frame.dart' as frame;
import 'package:smile_app/main.dart' as app;

import 'support/backend.dart';
import 'support/chapter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 13: Frame im Alltag (Tablet)', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding, id: 'ch13f', title: 'Frame im Alltag (Tablet)', intro: '', device: 'X200');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');

    Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
      final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
      while (true) {
        try {
          if (await test()) return true;
        } catch (_) {}
        if (DateTime.now().isAfter(end)) return false;
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    /// [what] stays away for [seconds].
    Future<bool> never(String what, {double seconds = 15}) async {
      final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 300));
        if (c.find_(what).evaluate().isNotEmpty) return false;
      }
      return true;
    }

    unawaited(app.main());
    try {
      if (!await eventually(() async => (await TestBackend.select('frames', 'select=id')).isEmpty, seconds: 180)) {
        throw TestFailure('Der Server wurde nicht zurückgesetzt');
      }
      String? code;
      String? frameId;
      await eventually(() async {
        final rows = await TestBackend.select('frames', 'select=id,pairing_code&name=eq.Wohnzimmer');
        code = rows.isEmpty ? null : (rows.first as Map)['pairing_code'] as String?;
        frameId = rows.isEmpty ? null : (rows.first as Map)['id'] as String?;
        return code != null;
      }, seconds: 600);
      if (code == null) throw TestFailure('Anna hat keinen Frame angelegt');
      await c.waitFor('Dieses Gerät als Frame verwenden', seconds: 30);
      await frame.becomeFrame(code!);
      c.screen('Frame: Diashow');
      if (!await eventually(() => c.find_('~Geburtstage').evaluate().isNotEmpty, seconds: 120)) {
        throw TestFailure('Der Frame zeigt keine Fotos');
      }
      await c.letLoad(seconds: 3);
      await c.start();

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final center = Offset(size.width / 2, size.height / 2);
      Future<Map> row() async => (await TestBackend.select('frames', 'select=*&id=eq.$frameId')).first as Map;

      Future<void> tapScreen() async {
        await tester.tapAt(center);
        c.logTap('Bildschirm antippen');
        await tester.pump(const Duration(milliseconds: 300));
      }

      /// One picture of what the phone just did ([n]: its signal).
      Future<void> after(int n, String title, String doIt, String expect, String explain,
          {Future<void> Function()? checks, String kind = 'Hauptweg', Future<void> Function()? then}) async {
        await c.awaitSignal('p$n', seconds: 900);
        c.clearMessages();
        c.step(title, doIt, expect, kind: kind, explain: explain);
        await c.letLoad(seconds: 2);
        await checks?.call();
        await c.snap();
        await then?.call();
        await TestBackend.signal('f$n');
      }

      /// One step at the tablet itself (Oma Hilde).
      Future<void> own(String title, String doIt, String expect, String explain, Future<void> Function() act,
          {String kind = 'Hauptweg'}) async {
        c.clearMessages();
        c.step(title, doIt, expect, kind: kind, explain: explain);
        await act();
        await c.snap();
      }

      // ================================================================ Frisch verbunden
      await own('Am Tablet: verbunden, ohne Hinweis je Foto', 'Am Tablet hinschauen, nachdem es zum Frame wurde.',
          'Die Diashow läuft mit Geburtstage; kein Hinweis auf neue Fotos, obwohl gerade alle Fotos geladen wurden.',
          'Beim ersten Laden kommen hunderte Fotos auf einmal. Dafür gibt es keinen Hinweis und keinen Ton, nur für Fotos, die danach dazukommen.',
          () async {
        await c.check('Kein Hinweis auf Neues', () => never('antippen', seconds: 10));
      });
      await TestBackend.signal('f0');

      // ================================================================ Antippen hält an
      await after(1, 'Am Tablet: antippen hält an', 'Am Tablet einmal auf das Bild tippen.',
          'In der Mitte kurz Angehalten mit Nochmal tippen, dann geht es weiter; danach unten rechts ein kleines Zeichen.',
          'Antippen hält an: auch wer nur zuschaut, kann ein Foto anhalten und in Ruhe ansehen. Nach 10 Minuten läuft es von selbst weiter.',
          checks: () async {
        await tapScreen();
        await c.check('Angehalten', () => c.showsUp('Angehalten', seconds: 3));
        await c.check('Hinweis: nochmal tippen', () => c.showsUp('Nochmal tippen, dann geht es weiter', seconds: 1));
      }, then: () async {
        await own('Am Tablet: nochmal tippen', 'Noch einmal auf das Bild tippen.', 'Kurz Läuft weiter, die Diashow geht weiter.',
            'Der zweite Tipp lässt es weiterlaufen.', () async {
          await tapScreen();
          await c.check('Läuft weiter', () => c.showsUp('Läuft weiter', seconds: 3));
        });
      });

      await after(2, 'Am Tablet: Antippen hält nicht an', 'Am Tablet auf das Bild tippen.', 'Nichts passiert, die Diashow läuft weiter.',
          'Ausgeschaltet hält ein Tipp nichts an (bei Nur zuschauen gibt es dann gar nichts zu tippen).', kind: 'Abzweigung',
          checks: () async {
        await c.check('Einstellung angekommen', () => eventually(() async => (await row())['easy_stop'] == false, seconds: 10));
        await c.letLoad(seconds: 3);
        await tapScreen();
        await c.check('Nicht angehalten', () => c.neverShows('Angehalten', seconds: 4));
      });

      // ================================================================ Neue Fotos
      await after(3, 'Am Tablet: zwei neue Fotos', 'Am Tablet hinschauen.',
          'Unten leuchtet ein Hinweis mit Lenas Bild: 2 neue Fotos von Lena Huber, antippen. Dazu kam ein kurzer Dreiklang.',
          'Der Hinweis bleibt stehen, bis jemand tippt; bei Nur zuschauen genauso.',
          checks: () async {
        await c.check('Hinweis', () => eventually(() => c.find_('~2 neue Fotos').evaluate().isNotEmpty, seconds: 60));
        await c.check('Von Lena', () => c.waitFor('~Lena', seconds: 2));
        await c.check('antippen', () => c.waitFor('antippen', seconds: 1));
      }, then: () async {
        await own('Am Tablet: Hinweis antippen', 'Auf den Hinweis tippen.', 'Der Hinweis verschwindet, der Frame zeigt die beiden neuen Fotos.',
            'Ein Tipp zeigt, was neu ist; danach geht die Diashow wie vorher weiter.', () async {
          await tapScreen();
          await c.check('Hinweis weg', () => c.gone('~2 neue Fotos', seconds: 5));
          await c.check('Nicht angehalten', () => c.neverShows('Angehalten', seconds: 2));
          await c.letLoad(seconds: 2);
        });
      });

      await after(4, 'Am Tablet: still dazu', 'Am Tablet hinschauen, nachdem Lena noch ein Foto geschickt hat.',
          'Kein Hinweis; das Fahrrad kommt einfach mit in die Diashow.', 'Hinweis auf Neues ist aus.', kind: 'Abzweigung',
          checks: () async {
        await c.check('Kein Hinweis', () => never('antippen', seconds: 20));
      });

      // ================================================================ Heute vor einem Jahr
      await after(5, 'Am Tablet: Heute vor einem Jahr', 'Am Tablet den Hinweis auf das neue Foto antippen, dann warten, bis der Sonnenuntergang kommt.',
          'Unten links: Heute vor einem Jahr · und das Jahr.',
          'Das Foto kommt heute immer wieder als jedes 10. Bild dazwischen. Solange ein Hinweis auf Neues steht, wartet dieser Hinweis, damit sich unten nichts überlappt.',
          checks: () async {
        // The sunset arrives as a new photo: its hint first (it hides the pill).
        if (await eventually(() => c.find_('antippen').evaluate().isNotEmpty, seconds: 60)) {
          await tapScreen();
          await c.letLoad(seconds: 2);
        }
        await c.check('Hinweis unten links', () => eventually(() => c.find_('~Heute vor einem Jahr').evaluate().isNotEmpty, seconds: 240));
      });

      await after(6, 'Am Tablet: ohne Heute vor einem Jahr', 'Am Tablet hinschauen.', 'Der Hinweis unten links ist weg.',
          'Ausgeschaltet läuft das Foto wie jedes andere.', kind: 'Abzweigung',
          checks: () async {
        await c.check('Hinweis weg', () => eventually(() => c.find_('~Heute vor einem Jahr').evaluate().isEmpty, seconds: 30));
      });

      // ================================================================ Kindersperre
      final clock = Offset(size.width - 100, 60);
      // The code field opens while the finger is still down, and the
      // Navigator then cancels that finger. The test binding treats this
      // cancel as a "device" event and drops it, so the photo's zoom view
      // kept the finger and took every later touch for a pinch (2026-11-28;
      // the real app gets the cancel). While holding, such events go through.
      Future<void> holdClock() async {
        binding.shouldPropagateDevicePointerEvents = true;
        try {
          final g = await tester.startGesture(clock);
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          await tester.pump();
          await g.up();
          await tester.pump();
        } finally {
          binding.shouldPropagateDevicePointerEvents = false;
        }
      }
      await after(7, 'Am Tablet: lange auf die Uhr', 'Am Tablet oben rechts lange drücken (dort, wo die Uhr steht).',
          'Ein dunkles Feld mit Code eingeben und Ziffern 1 bis 0.',
          'Mit dem Code aus der App lässt sich der Frame entsperren, auch bei Nur zuschauen.',
          checks: () async {
        await c.check('Code angekommen', () => eventually(() async => (await row())['unlock_code_hash'] != null, seconds: 10));
        await c.letLoad(seconds: 3);
        for (var i = 0; i < 3 && c.find_('Code eingeben').evaluate().isEmpty; i++) {
          await holdClock();
          c.logTap('Lange auf die Uhr');
          await c.letLoad(seconds: 1.5);
        }
        await c.check('Code eingeben', () => c.waitFor('Code eingeben', seconds: 3));
      }, then: () async {
        Future<void> digits(String code) async {
          for (final d in code.split('')) {
            await tester.tap(find.text(d).last, warnIfMissed: false);
            c.logTap('Ziffer');
            await tester.pump(const Duration(milliseconds: 200));
          }
          await c.letLoad(seconds: 1);
        }

        await own('Am Tablet: Code-Feld schließen', 'Im Feld unten links auf ✕ tippen, dann wieder lange auf die Uhr drücken.',
            'Das Feld geht zu und beim langen Drücken wieder auf.', 'Wer sich vertippt hat oder es sich anders überlegt, schließt das Feld.',
            kind: 'Abzweigung', () async {
          await tester.tap(find.byIcon(SmileIcons.close).last, warnIfMissed: false);
          c.logTap('Schließen');
          await c.check('Zu', () => c.gone('Code eingeben', seconds: 3));
          // As before the first opening: the Frame settles a moment before a long press opens it again.
          await c.letLoad(seconds: 3);
          for (var i = 0; i < 3 && c.find_('Code eingeben').evaluate().isEmpty; i++) {
            await holdClock();
            c.logTap('Lange auf die Uhr');
            await c.letLoad(seconds: 1.5);
          }
          if (c.find_('Code eingeben').evaluate().isEmpty) {
            // Diagnosis: what a long press on the clock reaches right now.
            final path = tester.hitTestOnBinding(clock).path.map((e) => e.target.runtimeType).take(12).join(' < ');
            debugPrint('  Uhr-Treffer: $path');
            debugPrint('  Barrieren: ${find.byType(ModalBarrier).evaluate().length}');
          }
          await c.check('Wieder offen', () => c.waitFor('Code eingeben', seconds: 3));
        });
        await own('Am Tablet: falscher Code', '0000 eintippen.', 'Falscher Code; das Feld bleibt offen.',
            'Nach drei falschen Versuchen muss man eine Minute warten.', kind: 'Abzweigung', () async {
          await digits('0000');
          await c.check('Falscher Code', () => c.waitFor('Falscher Code', seconds: 3));
        });
        await own('Am Tablet: richtiger Code', '1234 eintippen.',
            'Oben Entsperrt mit einem Countdown, unten alle Knöpfe wie bei Alles selbst.',
            'Entsperrt bleibt der Frame, bis zwei Minuten lang niemand ihn berührt.', () async {
          await digits('1234');
          await c.check('Entsperrt', () => c.waitFor('Entsperrt', seconds: 5));
          await c.check('Alle Knöpfe', () => c.waitFor('Einstellungen', seconds: 3));
        });
      });

      // ================================================================ Live
      await after(8, 'Am Tablet: Anna schaut mit', 'Am Tablet hinschauen, während Anna Live ansehen geöffnet hat.',
          'Oben ein kleiner Hinweis: Anna Berger schaut mit.',
          'Wer am Frame sitzt, sieht immer, wenn jemand zuschaut.',
          checks: () async {
        await c.check('schaut mit', () => eventually(() => c.find_('~schaut mit').evaluate().isNotEmpty, seconds: 20));
        await c.check('Anna', () => c.waitFor('~Anna', seconds: 1));
      });
      await after(9, 'Am Tablet: niemand schaut mehr', 'Am Tablet hinschauen.', 'Der Hinweis ist weg.', 'Anna hat Live beendet.',
          checks: () async {
        await c.check('Hinweis weg', () => eventually(() => c.find_('~schaut mit').evaluate().isEmpty, seconds: 20));
      });
      await after(10, 'Am Tablet: läuft weiter', 'Am Tablet hinschauen.', 'Die Diashow läuft wie vorher.',
          'Der Frame merkt nichts davon, dass er gleich als offline gilt: die Testsuite stellt nur sein letztes Lebenszeichen zurück.',
          checks: () async {
        await c.check('Diashow', () => eventually(() => c.find_('~Geburtstage').evaluate().isNotEmpty || c.find_('~Sommerurlaub').evaluate().isNotEmpty, seconds: 20));
      });

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
