// Kapitel 7: Frame bedienen, Teil am Tablet (X200). Läuft gleichzeitig mit
// ch07_test.dart am Handy: verbindet sich selbst mit dem Frame Wohnzimmer
// (nicht Teil des Kapitels), dann macht es nach jedem Signal des Handys (pN)
// sein Bild und antwortet (fN). Setzt nichts zurück.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/frame/frame.dart' as frame;
import 'package:smile_app/main.dart' as app;

import 'support/backend.dart';
import 'support/chapter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 7: Frame bedienen (Tablet)', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding, id: 'ch07f', title: 'Frame bedienen (Tablet)', intro: '', device: 'X200');
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
      await eventually(() async {
        final rows = await TestBackend.select('frames', 'select=pairing_code&name=eq.Wohnzimmer');
        code = rows.isEmpty ? null : (rows.first as Map)['pairing_code'] as String?;
        return code != null;
      }, seconds: 600);
      if (code == null) throw TestFailure('Anna hat keinen Frame angelegt');
      await c.waitFor('Dieses Gerät als Frame verwenden', seconds: 30);
      await frame.becomeFrame(code!);
      c.screen('Frame: Diashow');
      // The album's name shows on the photo (top left) once one is there.
      if (!await eventually(() => c.find_('~Geburtstage').evaluate().isNotEmpty, seconds: 120)) {
        throw TestFailure('Der Frame zeigt keine Fotos');
      }
      await c.letLoad(seconds: 3);
      await TestBackend.signal('f0');
      await c.start();

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final center = Offset(size.width / 2, size.height / 2);

      /// Shows the button bar (a tap on the picture), until [expected] is there.
      Future<bool> bar(String expected) async {
        for (var i = 0; i < 20; i++) {
          if (c.find_(expected).evaluate().isNotEmpty) return true;
          await tester.tapAt(center);
          await c.letLoad(seconds: 1.5);
        }
        return c.find_(expected).evaluate().isNotEmpty;
      }

      /// One picture of what the phone just did ([n]: its signal).
      Future<void> after(int n, String title, String doIt, String expect, String explain,
          {Future<void> Function()? checks, String kind = 'Hauptweg', Future<void> Function()? then}) async {
        await c.awaitSignal('p$n', seconds: 600);
        c.clearMessages();
        c.step(title, doIt, expect, kind: kind, explain: explain);
        await c.letLoad(seconds: 3);
        await checks?.call();
        await c.snap();
        // Steps of the tablet's own, before the phone goes on.
        await then?.call();
        await TestBackend.signal('f$n');
      }

      Future<List<Map>> wohnzimmer() async =>
          (await TestBackend.select('frames', 'select=*&name=eq.Wohnzimmer')).cast<Map>();

      /// A button of the bar: shown first, then tapped.
      Future<void> press(String label) async {
        await bar(label);
        await tester.tap(c.find_(label).last, warnIfMissed: false);
        c.logTap(label);
        await c.settle();
      }

      /// One step at the tablet itself (Oma Hilde, with Alles selbst).
      Future<void> own(String title, String doIt, String expect, String explain, Future<void> Function() act,
          {String kind = 'Hauptweg'}) async {
        c.clearMessages();
        c.step(title, doIt, expect, kind: kind, explain: explain);
        await act();
        await c.letLoad(seconds: 1.5);
        await c.snap();
      }

      Future<void> ownButtons() async {
        await own('Am Tablet selbst: Weiter', 'Am Tablet auf den Bildschirm tippen, dann Weiter.', 'Das nächste Foto.',
            'Mit Alles selbst kann man am Frame alles selbst machen.', () => press('Weiter'));
        await own('Am Tablet selbst: Zurück', 'Am Tablet Zurück antippen.', 'Wieder das vorige Foto.', 'Ein Foto zurück.',
            () => press('Zurück'));
        await own('Am Tablet selbst: Pause', 'Am Tablet Pause antippen.', 'Der Knopf heißt jetzt Abspielen, das Foto bleibt stehen.',
            'Anhalten direkt am Frame.', () async {
          await press('Pause');
          await c.check('Abspielen', () => eventually(() => c.find_('Abspielen').evaluate().isNotEmpty, seconds: 5));
        });
        await own('Am Tablet selbst: Abspielen', 'Am Tablet Abspielen antippen.', 'Die Diashow läuft weiter.', 'Weiter geht es.',
            () => press('Abspielen'));
        await own('Am Tablet selbst: Neueste', 'Am Tablet Neueste antippen.', 'Der Frame spielt die neuesten Fotos und Videos.',
            'Was zuletzt dazugekommen ist.', () => press('Neueste'));
        await own('Am Tablet selbst: Merken', 'Am Tablet Merken antippen.', 'Der Knopf heißt jetzt Gemerkt: das Foto ist ein Lieblingsbild.',
            'Lieblingsbilder kann man auch direkt am Frame merken.', () async {
          final before = (await TestBackend.select('frame_favorites', 'select=media_item_id')).length;
          await press('Merken');
          await c.check('Server: ein Lieblingsbild mehr', () => eventually(() async =>
              (await TestBackend.select('frame_favorites', 'select=media_item_id')).length == before + 1));
        });
        await own('Am Tablet selbst: Lieblingsbilder', 'Am Tablet Lieblingsbilder antippen.',
            'Der Frame spielt eine Runde mit den Lieblingsbildern; das eben gemerkte Foto ist dabei.',
            'Die Lieblingsbilder als eigene Runde.', () async {
          await press('Lieblingsbilder');
          await c.check('Gemerkt-Knopf', () => bar('Gemerkt'));
        });
        await own('Am Tablet selbst: nicht mehr merken', 'Am Tablet Gemerkt antippen.', 'Der Knopf heißt wieder Merken: das Foto ist kein Lieblingsbild mehr.',
            'Ein Lieblingsbild lässt sich am Frame auch wieder zurücknehmen.', () async {
          final before = (await TestBackend.select('frame_favorites', 'select=media_item_id')).length;
          await press('Gemerkt');
          await c.check('Server: ein Lieblingsbild weniger', () => eventually(() async =>
              (await TestBackend.select('frame_favorites', 'select=media_item_id')).length == before - 1));
        }, kind: 'Abzweigung');
        await own('Am Tablet selbst: Album', 'Am Tablet Album antippen.', 'Album wählen mit Sommerurlaub 2026 und Geburtstage.',
            'Alle Alben, die der Frame hat.', () async {
          await press('Album');
          c.screen('Frame: Album wählen');
          await c.check('Album wählen', () => c.waitFor('Album wählen', seconds: 5));
        });
        await own('Am Tablet selbst: Album, daneben tippen', 'Am Tablet oben neben die Auswahl tippen.', 'Die Auswahl schließt sich, das Album bleibt.',
            'Nichts passiert.', () async {
          await c.tapAt(const Offset(40, 40), 'Schließen');
          c.screen('Frame: Diashow');
          await c.check('Zu', () => c.gone('Album wählen', seconds: 5));
        }, kind: 'Abzweigung');
        await own('Am Tablet selbst: anderes Album', 'Am Tablet wieder Album, dann Sommerurlaub 2026 antippen.', 'Der Frame zeigt jetzt Sommerurlaub 2026.',
            'Das Album wechselt sofort.', () async {
          await press('Album');
          c.screen('Frame: Album wählen');
          await c.waitFor('Album wählen', seconds: 5);
          await tester.tap(find.text('Sommerurlaub 2026').last, warnIfMissed: false);
          c.logTap('Sommerurlaub 2026');
          await c.settle();
          c.screen('Frame: Diashow');
          await c.check('Sommerurlaub', () => eventually(() => c.find_('~Sommerurlaub 2026').evaluate().isNotEmpty, seconds: 10));
        });
        await own('Am Tablet selbst: Übersicht', 'Am Tablet Übersicht antippen.', 'Alle Fotos des Albums klein nebeneinander, unten Zurück zur Diashow.',
            'Zum Stöbern.', () async {
          await press('Übersicht');
          await c.check('Übersicht', () => c.waitFor('Zurück zur Diashow', seconds: 5));
        });
        await own('Am Tablet selbst: zurück zur Diashow', 'Am Tablet Zurück zur Diashow antippen.', 'Wieder die Diashow.',
            'Die Übersicht schließt sich.', () async {
          await c.tap('Zurück zur Diashow');
          await c.check('Diashow', () => c.gone('Zurück zur Diashow', seconds: 5));
        });
        await own('Am Tablet selbst: Dauer', 'Am Tablet Dauer antippen.', 'Wie lange soll ein Foto zu sehen sein? mit 5, 10, 20 Sekunden und 1 Minute.',
            'Die Anzeigedauer direkt am Frame.', () async {
          await press('Dauer');
          c.screen('Frame: Dauer');
          await c.check('Frage', () => c.waitFor('Wie lange soll ein Foto', seconds: 5));
        });
        await own('Am Tablet selbst: Dauer, daneben tippen', 'Am Tablet oben neben die Frage tippen.', 'Die Frage schließt sich, die Dauer bleibt.',
            'Nichts passiert.', () async {
          await c.tapAt(const Offset(40, 40), 'Schließen');
          c.screen('Frame: Diashow');
          await c.check('Zu', () => c.gone('Wie lange soll ein Foto', seconds: 5));
        }, kind: 'Abzweigung');
        await own('Am Tablet selbst: 20 Sekunden', 'Am Tablet wieder Dauer, dann 20 Sekunden antippen.', 'Die Frage schließt sich; jedes Foto steht jetzt 20 Sekunden.',
            'Gilt auch in der App unter Wiedergabe.', () async {
          await press('Dauer');
          c.screen('Frame: Dauer');
          await c.waitFor('Wie lange soll ein Foto', seconds: 5);
          await tester.tap(find.text('20 Sekunden').last, warnIfMissed: false);
          c.logTap('20 Sekunden');
          await c.settle();
          c.screen('Frame: Diashow');
          await c.check('Server: 20 Sekunden', () => eventually(() async => (await wohnzimmer()).first['slideshow_interval_seconds'] == 20));
        });
        await own('Am Tablet selbst: Titel aus', 'Am Tablet Titel antippen.', 'Titel unter den Fotos werden nicht mehr gezeigt.',
            'Für alle, die nur die Fotos sehen möchten.', () async {
          await press('Titel');
          await c.check('Server: Titel aus', () => eventually(() async => (await wohnzimmer()).first['show_captions'] == false));
        });
        await own('Am Tablet selbst: Titel an', 'Am Tablet noch einmal Titel antippen.', 'Titel werden wieder gezeigt.', 'Und wieder an.',
            () async {
          await press('Titel');
          await c.check('Server: Titel an', () => eventually(() async => (await wohnzimmer()).first['show_captions'] == true));
        }, kind: 'Abzweigung');
        await own('Am Tablet selbst: Einstellungen', 'Am Tablet Einstellungen antippen.',
            'Die Wiedergabe-Einstellungen groß am Frame: Was läuft, Reihenfolge, Videos, Füllen und mehr.',
            'Alles, was in der App unter Wiedergabe steht (Kapitel 8 prüft es einzeln).', () async {
          await press('Einstellungen');
          c.screen('Frame: Einstellungen');
          await c.check('Einstellungen', () => c.waitFor('Was läuft', seconds: 5));
        });
        await own('Am Tablet selbst: Einstellungen schließen', 'Am Tablet oben neben die Einstellungen tippen.', 'Wieder die Diashow.',
            'Die Einstellungen schließen sich.', () async {
          await c.tapAt(const Offset(40, 40), 'Schließen');
          c.screen('Frame: Diashow');
          await c.check('Zu', () => c.gone('Was läuft', seconds: 5));
        }, kind: 'Abzweigung');
      }

      await after(2, 'Am Tablet: Sommerurlaub', 'Am Tablet hinschauen.', 'Der Frame zeigt jetzt das Foto aus Sommerurlaub 2026.',
          'Der Wechsel am Handy kommt sofort am Frame an.',
          checks: () => c.check('Sommerurlaub', () => eventually(() => c.find_('~Sommerurlaub 2026').evaluate().isNotEmpty, seconds: 20)));
      await after(3, 'Am Tablet: wieder Geburtstage', 'Am Tablet hinschauen.', 'Der Frame zeigt wieder Geburtstage.',
          'Zurück zum ersten Album.', kind: 'Abzweigung',
          checks: () => c.check('Geburtstage', () => eventually(() => c.find_('~Geburtstage').evaluate().isNotEmpty, seconds: 20)));
      await after(7, 'Am Tablet: das nächste Foto', 'Am Tablet hinschauen.', 'Der Frame zeigt das nächste Foto.',
          'Der Weiter-Knopf am Handy wirkt wie ein Weiter am Frame.');
      await after(8, 'Am Tablet: angehalten', 'Am Tablet hinschauen.', 'Der Frame steht und zeigt unten Pause.',
          'Bis Anna wieder Abspielen tippt, bleibt das Foto stehen.',
          checks: () => c.check('Pause', () => eventually(() => c.find_('Pause').evaluate().isNotEmpty, seconds: 20)));
      await after(9, 'Am Tablet: läuft wieder', 'Am Tablet hinschauen.', 'Pause ist weg, die Diashow läuft weiter.',
          'Die Diashow geht weiter.',
          checks: () => c.check('Keine Pause mehr', () => eventually(() => c.find_('Pause').evaluate().isEmpty, seconds: 20)));
      await after(10, 'Am Tablet: das vorige Foto', 'Am Tablet hinschauen.', 'Der Frame zeigt das vorige Foto.', 'Ein Foto zurück.');
      await after(11, 'Am Tablet: die neuesten Fotos', 'Am Tablet hinschauen.', 'Der Frame spielt die neuesten Fotos und Videos.',
          'Nach der Runde geht es mit dem Album weiter.');
      await after(12, 'Am Tablet: Sommerurlaub über die Fernbedienung', 'Am Tablet hinschauen.', 'Der Frame zeigt Sommerurlaub 2026.',
          'Ein Tipp auf ein Album in der Fernbedienung zeigt es sofort.',
          checks: () => c.check('Sommerurlaub', () => eventually(() => c.find_('~Sommerurlaub 2026').evaluate().isNotEmpty, seconds: 20)));
      await after(13, 'Am Tablet: Stufe 2', 'Am Tablet auf den Bildschirm tippen.', 'Unten Pause und ein großer Weiter-Knopf.',
          'Mehr gibt es auf dieser Stufe nicht.',
          checks: () async {
            await c.check('Weiter', () => bar('Weiter'));
            await c.check('Pause', () => c.find_('Pause').evaluate().isNotEmpty);
            await c.check('Kein Zurück', () => c.find_('Zurück').evaluate().isEmpty);
          });
      await after(14, 'Am Tablet: Stufe 3', 'Am Tablet auf den Bildschirm tippen.', 'Unten Zurück, Pause, Weiter, Neueste und Merken.',
          'Die Stufe Einfach.',
          checks: () async {
            await c.check('Zurück', () => bar('Zurück'));
            await c.check('Neueste', () => c.find_('Neueste').evaluate().isNotEmpty);
            await c.check('Merken', () => c.find_('Merken').evaluate().isNotEmpty);
          });
      await after(15, 'Am Tablet: Stufe 4', 'Am Tablet auf den Bildschirm tippen.', 'Dazu Album, Übersicht, Dauer und Titel.',
          'Die Stufe Komfort.',
          checks: () async {
            await c.check('Übersicht', () => bar('Übersicht'));
            await c.check('Dauer', () => c.find_('Dauer').evaluate().isNotEmpty);
          });
      await after(16, 'Am Tablet: Stufe 5', 'Am Tablet auf den Bildschirm tippen.', 'Dazu Einstellungen.', 'Alles, was es gibt.',
          checks: () => c.check('Einstellungen', () => bar('Einstellungen')), then: ownButtons);
      await after(17, 'Am Tablet: ohne Weiter', 'Am Tablet auf den Bildschirm tippen.', 'Alle Knöpfe wie eben, nur Weiter fehlt.',
          'Der einzelne Schalter wirkt sofort.', kind: 'Abzweigung',
          checks: () async {
            await c.check('Weiter weg', () => eventually(() async {
              await bar('Pause');
              return c.find_('Weiter').evaluate().isEmpty;
            }, seconds: 30));
          });
      await after(18, 'Am Tablet: wieder nur zuschauen', 'Am Tablet auf den Bildschirm tippen.', 'Keine Knöpfe, die Diashow läuft einfach.',
          'Oma Hilde kann nichts verstellen.',
          checks: () => c.check('Keine Knöpfe', () async {
                // Once the level has arrived: four taps, never a button.
                await eventually(() async => (await TestBackend.select('frames', 'select=control_level&name=eq.Wohnzimmer'))
                    .every((r) => (r as Map)['control_level'] == 1), seconds: 20);
                await c.letLoad(seconds: 3);
                for (var i = 0; i < 4; i++) {
                  await tester.tapAt(center);
                  await c.letLoad(seconds: 1.5);
                  if (c.find_('Pause').evaluate().isNotEmpty || c.find_('Einstellungen').evaluate().isNotEmpty) return false;
                }
                return true;
              }));
      await after(20, 'Am Tablet: die Obstschale', 'Am Tablet hinschauen.', 'Der Frame zeigt sofort die Obstschale mit dem Titel Obst für alle.',
          'Jetzt am Frame zeigen springt direkt zu diesem Foto.',
          checks: () => c.check('Obst für alle', () => eventually(() => c.find_('~Obst für alle').evaluate().isNotEmpty, seconds: 20)));

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}
