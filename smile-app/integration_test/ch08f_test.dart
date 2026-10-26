// Kapitel 8: Frame-Einstellungen und Wiedergabe, Teil am Tablet (X200).
// Läuft gleichzeitig mit ch08_test.dart am Handy: verbindet sich selbst mit
// dem Frame Wohnzimmer (nicht Teil des Kapitels), macht nach jedem Signal
// des Handys (pN) sein Bild und antwortet (fN). Zum Schluss stellt Oma Hilde
// am Tablet selbst die Wiedergabe ein (Frame: Einstellungen).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/frame/frame.dart' as frame;
import 'package:smile_app/main.dart' as app;

import 'support/backend.dart';
import 'support/chapter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 8: Frame-Einstellungen und Wiedergabe (Tablet)', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding, id: 'ch08f', title: 'Frame-Einstellungen und Wiedergabe (Tablet)', intro: '', device: 'X200');
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

    unawaited(app.main());
    try {
      // Until the phone has reset the server and created Wohnzimmer; then
      // this tablet becomes that Frame (as in chapter 6, without the steps).
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
      await TestBackend.signal('f0');
      await c.start();

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final center = Offset(size.width / 2, size.height / 2);
      // By id: the phone renames it for a while.
      Future<Map> row() async => (await TestBackend.select('frames', 'select=*&id=eq.$frameId')).first as Map;
      Future<bool> saved(String column, Object? value) => eventually(() async => (await row())[column] == value);
      Future<bool> shows(String album, {double seconds = 30}) =>
          eventually(() => c.find_('~$album').evaluate().isNotEmpty, seconds: seconds);

      /// One picture of what the phone just did ([n]: its signal).
      Future<void> after(int n, String title, String doIt, String expect, String explain,
          {Future<void> Function()? checks, String kind = 'Hauptweg', Future<void> Function()? then}) async {
        await c.awaitSignal('p$n', seconds: 900);
        c.clearMessages();
        c.step(title, doIt, expect, kind: kind, explain: explain);
        await c.letLoad(seconds: 3);
        await checks?.call();
        await c.snap();
        await then?.call();
        await TestBackend.signal('f$n');
      }

      /// Shows the button bar (a tap on the picture), until [expected] is there.
      Future<bool> bar(String expected) async {
        for (var i = 0; i < 20; i++) {
          if (c.find_(expected).evaluate().isNotEmpty) return true;
          await tester.tapAt(center);
          await c.letLoad(seconds: 1.5);
        }
        return c.find_(expected).evaluate().isNotEmpty;
      }

      /// A choice in the settings sheet (scrolled into sight first).
      Future<void> choose(String label) async {
        final f = find.text(label);
        await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
        await c.settle();
        await tester.tap(f.last, warnIfMissed: false);
        c.logTap(label);
        await c.settle();
      }

      /// One step at the tablet itself.
      Future<void> own(String title, String doIt, String expect, String explain, Future<void> Function() act,
          {String kind = 'Hauptweg'}) async {
        c.clearMessages();
        c.step(title, doIt, expect, kind: kind, explain: explain);
        await act();
        await c.letLoad(seconds: 1);
        await c.snap();
      }

      Future<void> ownSettings() async {
        await own('Am Tablet selbst: Einstellungen', 'Am Tablet auf den Bildschirm tippen, dann Einstellungen.',
            'Wiedergabe groß am Frame: Was läuft, Reihenfolge, Am Ende, Nachtruhe, Videos, Bildschirm füllen, die Schalter und Dazu.',
            'Mit Alles selbst kann Oma Hilde die Wiedergabe selbst einstellen.', () async {
          await bar('Einstellungen');
          await tester.tap(c.find_('Einstellungen').last, warnIfMissed: false);
          c.logTap('Einstellungen');
          await c.settle();
          c.screen('Frame: Einstellungen');
          await c.check('Was läuft', () => c.waitFor('Was läuft', seconds: 5));
        });
        await own('Am Tablet selbst: Was läuft', 'Am Tablet Alle Alben im Wechsel, Aktuelles, dann 50 und wieder Ein Album antippen.',
            'Bei Aktuelles erscheint Wie viele aktuelle Fotos mit 10, 20, 50 und 100; am Ende ist Ein Album gewählt.',
            'Was in der App unter Was läuft steht (Lieblingsbilder gibt es dafür als eigenen Knopf).', () async {
          await choose('Alle Alben im Wechsel');
          await c.check('Server: Wechsel', () => saved('content_mode', 'rotate'));
          await choose('Aktuelles');
          await c.check('Server: Aktuelles', () => saved('content_mode', 'recent'));
          await c.check('Wie viele', () => c.waitFor('Wie viele aktuelle Fotos', seconds: 3));
          await choose('50');
          await c.check('Server: 50', () => saved('recent_count', 50));
          await choose('20');
          await c.check('Server: 20', () => saved('recent_count', 20));
          await choose('Ein Album');
          await c.check('Server: Ein Album', () => saved('content_mode', 'album'));
        });
        await own('Am Tablet selbst: Reihenfolge', 'Am Tablet Neueste zuerst, Zufällig und Der Reihe nach antippen.',
            'Am Ende ist Der Reihe nach gewählt.', 'Jede Wahl gilt sofort.', () async {
          for (final (label, value) in const [('Neueste zuerst', 'newest'), ('Zufällig', 'shuffle'), ('Der Reihe nach', 'oldest')]) {
            await choose(label);
            await c.check('Server: $label', () => saved('play_order', value));
          }
        });
        await own('Am Tablet selbst: Am Ende', 'Am Tablet Übersicht zeigen, dann Endlosschleife antippen.', 'Am Ende ist Endlosschleife gewählt.',
            'Wie in der App.', () async {
          await choose('Übersicht zeigen');
          await c.check('Server: Übersicht', () => saved('end_behavior', 'overview'));
          await choose('Endlosschleife');
          await c.check('Server: Endlosschleife', () => saved('end_behavior', 'loop'));
        });
        await own('Am Tablet selbst: Nachtruhe', 'Am Tablet 21 – 7 Uhr, 22 – 7 Uhr, 23 – 7 Uhr, dann Aus antippen.',
            'Am Ende ist Aus gewählt.', 'Am Frame gibt es drei feste Zeiten; eigene Zeiten stellt man in der App ein.', () async {
          for (final (label, from) in const [('21 – 7 Uhr', '21:00:00'), ('22 – 7 Uhr', '22:00:00'), ('23 – 7 Uhr', '23:00:00')]) {
            await choose(label);
            await c.check('Server: $label', () => saved('quiet_from', from));
          }
          await choose('Aus');
          await c.check('Server: keine Nachtruhe', () => saved('quiet_from', null));
        });
        await own('Am Tablet selbst: Videos', 'Am Tablet Wie ein Foto, Keine Videos, dann Ganze Länge antippen.', 'Am Ende ist Ganze Länge gewählt.',
            'Wie in der App.', () async {
          for (final (label, value) in const [('Wie ein Foto (10 s)', 'photo'), ('Keine Videos', 'none'), ('Ganze Länge', 'full')]) {
            await choose(label);
            await c.check('Server: $label', () => saved('video_length', value));
          }
        });
        await own('Am Tablet selbst: Bildschirm füllen', 'Am Tablet Nie, Immer, dann Wenn passend antippen.', 'Am Ende ist Wenn passend gewählt.',
            'Wie in der App.', () async {
          for (final (label, value) in const [('Nie', 'fit'), ('Immer', 'fill'), ('Wenn passend', 'auto')]) {
            await choose(label);
            await c.check('Server: $label', () => saved('fill_mode', value));
          }
        });
        await own('Am Tablet selbst: Schalter', 'Am Tablet Langsamer Zoom, Videos mit Ton, Große Uhr mit Datum, Absender einblenden, Titel anzeigen, '
            'Neue Fotos sofort zeigen und Bild dreht sich mit je zweimal antippen.',
            'Am Ende ist alles wie vorher.', 'Ein Tipp schaltet um; gewählt ist, was koralle umrandet ist.', () async {
          for (final (label, column) in const [
            ('Langsamer Zoom', 'slow_zoom'),
            ('Videos mit Ton', 'video_sound'),
            ('Große Uhr mit Datum', 'show_clock'),
            ('Absender einblenden', 'show_sender'),
            ('Titel anzeigen', 'show_captions'),
            ('Neue Fotos sofort zeigen', 'show_new_immediately'),
            ('Bild dreht sich mit', 'rotate_with_device'),
          ]) {
            final was = (await row())[column] as bool;
            await choose(label);
            await c.check('Server: $label umgestellt', () => saved(column, !was));
            await choose(label);
            await c.check('Server: $label wie vorher', () => saved(column, was));
          }
        });
        await own('Am Tablet selbst: Einstellungen schließen', 'Am Tablet oben neben die Einstellungen tippen.', 'Wieder die Diashow.',
            'Die Einstellungen schließen sich.', () async {
          await c.tapAt(const Offset(40, 40), 'Schließen');
          c.screen('Frame: Diashow');
          await c.check('Zu', () => c.gone('Was läuft', seconds: 5));
        }, kind: 'Abzweigung');
      }

      await after(1, 'Am Tablet: alle Alben im Wechsel', 'Am Tablet hinschauen.',
          'Der Frame läuft weiter; nach dem letzten Foto eines Albums kommt das nächste Album.', 'Im Bild ändert sich erst später etwas.');
      await after(2, 'Am Tablet: Lieblingsbilder', 'Am Tablet hinschauen.', 'Der Frame zeigt nur noch das Strandfoto aus Sommerurlaub 2026.',
          'Das einzige Lieblingsbild, obwohl das Album Geburtstage eingestellt ist.',
          checks: () => c.check('Sommerurlaub', () => shows('Sommerurlaub 2026')));
      await after(3, 'Am Tablet: große Uhr', 'Am Tablet hinschauen.', 'Oben rechts groß die Uhrzeit, darunter Wochentag und Datum.',
          'Die Uhr geht mit, solange der Frame läuft.', checks: () => c.check('Uhrzeit', () {
                final now = DateTime.now();
                return shows('${now.hour.toString().padLeft(2, '0')}:', seconds: 20);
              }));
      await after(4, 'Am Tablet: ohne Absender', 'Am Tablet hinschauen.', 'Oben links steht nichts mehr, nur das Foto.',
          'Album und Absender sind ausgeblendet.',
          checks: () => c.check('Kein Album oben', () => eventually(() => c.find_('~Geburtstage').evaluate().isEmpty, seconds: 20)));
      await after(5, 'Am Tablet: mit Absender', 'Am Tablet hinschauen.', 'Oben links wieder Geburtstage und wer das Foto geschickt hat.',
          'Wieder wie vorher.', kind: 'Abzweigung', checks: () => c.check('Geburtstage oben', () => shows('Geburtstage')));
      await after(6, 'Am Tablet: Nachtruhe', 'Am Tablet hinschauen.', 'Der Bildschirm ist dunkel.',
          'Bis Hell ab bleibt er dunkel; ein Tipp ändert daran nichts.',
          checks: () => c.check('Kein Foto mehr', () => eventually(() => c.find_('~Geburtstage').evaluate().isEmpty, seconds: 90)));
      await after(7, 'Am Tablet: wieder hell', 'Am Tablet hinschauen.', 'Der Frame zeigt wieder Fotos.', 'Ohne Nachtruhe läuft er weiter.',
          checks: () => c.check('Geburtstage', () => shows('Geburtstage', seconds: 90)));
      await after(8, 'Am Tablet: Sommerurlaub', 'Am Tablet hinschauen.', 'Der Frame zeigt Sommerurlaub 2026.',
          'Jetzt zeigen auf der Seite des Frames wirkt sofort.', checks: () => c.check('Sommerurlaub', () => shows('Sommerurlaub 2026')));
      await after(9, 'Am Tablet: Album entfernt', 'Am Tablet hinschauen.', 'Der Frame zeigt wieder Geburtstage.',
          'Sommerurlaub 2026 ist nicht mehr auf dem Frame.', checks: () => c.check('Geburtstage', () => shows('Geburtstage')));
      await after(10, 'Am Tablet: widerrufen', 'Am Tablet hinschauen.', 'Dieser Frame wurde widerrufen. Ein Admin des Space kann ihn in der Smile-App wieder aktivieren.',
          'Die Fotos sind vom Tablet gelöscht.',
          checks: () => c.check('Widerrufen', () => eventually(() => c.find_('Dieser Frame wurde widerrufen').evaluate().isNotEmpty, seconds: 60)));
      await after(11, 'Am Tablet: wieder aktiv', 'Am Tablet hinschauen.', 'Die Diashow läuft wieder mit den Fotos von Geburtstage.',
          'Das Tablet lädt die Fotos neu.', checks: () => c.check('Geburtstage', () => shows('Geburtstage', seconds: 120)));
      await after(12, 'Am Tablet: Alles selbst', 'Am Tablet auf den Bildschirm tippen.', 'Unten alle Knöpfe, ganz rechts Einstellungen.',
          'Jetzt kann Oma Hilde selbst einstellen.', checks: () => c.check('Einstellungen', () => bar('Einstellungen')), then: ownSettings);

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 35)));
}
