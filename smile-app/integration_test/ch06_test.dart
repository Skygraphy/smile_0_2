// Kapitel 6: Frame verbinden (tools/testsuite, 2026-10-25), Teil am Handy.
// Der Teil am Tablet (X200) läuft gleichzeitig: ch06f_test.dart. Beide
// richten sich nach dem Server; tools/testsuite/merge.js legt die Schritte
// danach in der Reihenfolge zusammen, in der sie passiert sind.
// Startet dort, wo Kapitel 5 endet: Annas Startseite mit vier Alben.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frames_screen.dart';
import 'package:smile_app/screens/spaces_screen.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 6: Frame verbinden', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch06',
        title: 'Frame verbinden',
        intro: 'Anna richtet für Oma Hilde einen Frame im Wohnzimmer ein: sie gibt ihm einen Namen, sagt, wer davor sitzt, '
            'und verbindet ein Tablet mit dem Code. Danach zeigt der Frame das Album Geburtstage. Zum Schluss macht Anna ihr '
            'eigenes Handy probeweise zum Frame. Schritte am Tablet sind mit Am Tablet gekennzeichnet.');

    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    // Fresh server and phone settings BEFORE the app starts: it reads them
    // at once (a tip showed up otherwise).
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 5)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter5(tester);
      final birthdays = seed.albums['Geburtstage']!;

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<List<Map>> frames() async =>
          (await TestBackend.select('frames', 'select=id,name,pairing_code,lifecycle_state,control_level&order=created_at.asc'))
              .cast<Map>();
      Future<Map?> frameNamed(String name) async => (await frames()).where((f) => f['name'] == name).firstOrNull;
      Future<void> tapExact(String text, {bool first = false}) async {
        await c.waitFor(text, seconds: 10);
        await tester.tap(first ? find.text(text).first : find.text(text).last, warnIfMissed: false);
        c.logTap(text);
        await c.settle();
      }

      /// A tab at the bottom, again until its page is there (the start page
      /// may just be rebuilding and swallow a tap, chapter 5).
      Future<void> tab(String label, Type page) async {
        for (var i = 0; i < 4 && find.byType(page).evaluate().isEmpty; i++) {
          await tapExact(label);
          for (var t = 0; t < 30 && find.byType(page).evaluate().isEmpty; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      }

      await c.waitFor('Wanderungen', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Frame anlegen
      c.step('Ausgangslage', 'Smile ist geöffnet, Anna ist angemeldet.',
          'Die Startseite mit Wanderungen, Sommerurlaub 2026, Geburtstage und Weihnachten. Unten Alben und Spaces, noch kein Frames.',
          explain: 'So endet Kapitel 5. Noch gibt es keinen Frame.');
      await c.check('Kein Frame im Server', () async => (await frames()).isEmpty);
      await c.check('Kein Frames unten', () => c.gone('Frames', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Space öffnen', 'Unten auf Spaces, dann Familie Berger antippen.',
          'Die Seite von Familie Berger. Oben die Knöpfe, weiter unten 0 Frames mit Noch kein Frame und Frame verbinden.',
          explain: 'Ein Frame gehört immer zu einem Space und zeigt dessen Alben.');
      await tab('Spaces', SpacesScreen);
      c.screen('Spaces');
      await c.tap('Familie Berger', last: true);
      c.screen('Space');
      await c.check('Space-Seite', () => c.waitFor('Frame verbinden', seconds: 10));
      await c.check('Noch kein Frame', () => c.waitFor('Noch kein Frame', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Frame einrichten', 'Oben auf Frame tippen.',
          'Frame einrichten: Wie soll der neue Frame heißen? mit einem Namensfeld, darunter Wer schaut auf diesen Frame? mit drei '
              'Möglichkeiten, Einfach bedienen ist gewählt. Weiter geht es erst mit einem Namen.',
          explain: 'Zuerst der Name, dann wer vor dem Frame sitzt. Danach richtet sich, welche Knöpfe der Frame zeigt.');
      await tapExact('Frame', first: true);
      c.screen('Frame einrichten');
      await c.check('Frage nach dem Namen', () => c.waitFor('Wie soll der neue Frame heißen', seconds: 8));
      await c.check('Ohne Namen kein Weiter', () => c.gone('Ein anderes Gerät', seconds: 1));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Frame einrichten: zurück', 'Oben links zurück, ohne etwas einzugeben.', 'Wieder die Seite von Familie Berger, kein Frame angelegt.',
          kind: 'Abzweigung', explain: 'Ohne Namen entsteht kein Frame.');
      await c.back();
      c.screen('Space');
      await c.check('Space-Seite', () => c.waitFor('Noch kein Frame', seconds: 5));
      await c.check('Kein Frame im Server', () async => (await frames()).isEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Namen eingeben', 'Wieder auf Frame, dann Wohnzimmer eingeben.',
          'Unten erscheinen jetzt Ein anderes Gerät und Dieses Gerät.', explain: 'Mit einem Namen kann es weitergehen.');
      await tapExact('Frame', first: true);
      c.screen('Frame einrichten');
      await c.typeInto('Name', 'Wohnzimmer');
      await c.hideKeyboard();
      await c.check('Zwei Wege', () async => await c.waitFor('Ein anderes Gerät', seconds: 3) && await c.waitFor('Dieses Gerät', seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Wer schaut: alles selbst', 'Jemand, der alles selbst einstellen möchte antippen.',
          'Diese Möglichkeit ist jetzt koralle umrandet und hat den Punkt; darunter steht Stufe 5 · Alles selbst.', kind: 'Abzweigung',
          explain: 'Dann zeigt der Frame alle Knöpfe und Einstellungen.');
      await tester.scrollUntilVisible(c.find_('Jemand, der alles selbst'), 200, scrollable: find.byType(Scrollable).first);
      await c.tap('Jemand, der alles selbst');
      await c.check('Stufe 5 sichtbar', () => c.waitFor('Stufe 5', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Wer schaut: einfach bedienen', 'Einfach bedienen antippen.',
          'Wieder Einfach bedienen mit dem Punkt; darunter Stufe 3 · Einfach.', kind: 'Abzweigung',
          explain: 'Das ist die Einstellung, die ein neuer Frame von sich aus bekommt: die wichtigsten Knöpfe am Frame.');
      await c.tap('Einfach bedienen');
      await c.settle();
      await c.snap();

      c.clearMessages();
      c.step('Wer schaut: nur zuschauen', 'Nur zuschauen antippen.',
          'Jetzt hat Nur zuschauen den Punkt. Oma Hilde soll nichts bedienen müssen.',
          explain: 'Der Frame zeigt dann keine Knöpfe, alles kommt aus der App.');
      await c.tap('Nur zuschauen');
      await c.settle();
      await c.snap();

      c.clearMessages();
      c.step('Ein anderes Gerät', 'Nach unten wischen und Ein anderes Gerät antippen.',
          'Wohnzimmer verbinden: ein QR-Code, darunter ein Code aus acht Zeichen, wie man ihn am Tablet eingibt, und Warte auf den Frame.',
          explain: 'Der Frame ist angelegt. Jetzt wartet die App, bis sich ein Tablet mit diesem Code meldet. Der Code gilt 15 Minuten.');
      await tester.scrollUntilVisible(c.find_('Ein anderes Gerät'), 200, scrollable: find.byType(Scrollable).first);
      await c.tap('Ein anderes Gerät');
      c.screen('Frame-Code');
      await c.check('Frame im Server', () => eventually(() async => await frameNamed('Wohnzimmer') != null));
      final created = (await frameNamed('Wohnzimmer'))!;
      await c.check('Stufe 1 gespeichert', () => eventually(() async => (await frameNamed('Wohnzimmer'))?['control_level'] == 1));
      final code = created['pairing_code'] as String;
      await c.check('Code angezeigt', () => c.waitFor('${code.substring(0, 4)} ${code.substring(4)}', seconds: 5));
      await c.check('Wartet', () => c.waitFor('Warte auf den Frame', seconds: 2));
      await c.snap();

      // ---------------------------------------------------------------- jetzt das Tablet (ch06f)
      c.clearMessages();
      c.step('Frame verbunden', 'Warten, bis das Tablet verbunden ist.',
          'Ohne Zutun wechselt das Handy zur Fernbedienung von Wohnzimmer: der Frame ist da, bei Alben steht nur Hinzufügen.',
          explain: 'Sobald das Tablet den Code eingegeben hat, gehört es zu Familie Berger.');
      await c.check('Frame aktiv', () => eventually(() async => (await frameNamed('Wohnzimmer'))?['lifecycle_state'] == 'active', seconds: 600));
      await c.check('Fernbedienung', () => eventually(() => find.byType(FrameRemoteScreen).evaluate().isNotEmpty, seconds: 20));
      c.screen('Fernbedienung');
      await c.check('Noch kein Album', () => c.waitFor('Hinzufügen', seconds: 10));
      await c.letLoad(seconds: 3); // the tablet takes its picture of the same moment first
      await c.snap();

      c.clearMessages();
      c.step('Album auf den Frame', 'Auf Hinzufügen tippen, dann Geburtstage.',
          'Zuerst die Frage Album hinzufügen mit den Alben von Familie Berger. Danach steht Geburtstage bei den Alben, koralle umrandet: es läuft gerade.',
          explain: 'Der Frame zeigt nur Alben, die man ihm gibt. Das Tablet zeigt die Fotos gleich danach.');
      await c.tap('Hinzufügen');
      c.screen('Album hinzufügen');
      await c.check('Auswahl', () => c.waitFor('Album hinzufügen', seconds: 8));
      await c.check('Nur Alben von Familie Berger', () => c.gone('Wanderungen', seconds: 1));
      await tapExact('Geburtstage');
      c.screen('Fernbedienung');
      await c.check('Album im Server', () => eventually(() async =>
          (await TestBackend.select('frame_channels', 'select=channel_id&frame_id=eq.${created['id']}'))
              .any((r) => (r as Map)['channel_id'] == birthdays)));
      await c.check('Geburtstage bei den Alben', () => c.waitFor('Geburtstage', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Zurück zum Space', 'Oben links zurück.', 'Die Seite von Familie Berger: jetzt 1 Frame, Wohnzimmer mit grünem Punkt.',
          explain: 'Der grüne Punkt heißt: der Frame ist eingeschaltet und verbunden.');
      await c.back();
      c.screen('Space');
      await c.check('1 Frame', () => c.waitFor('1 Frame', seconds: 10));
      await c.check('Wohnzimmer', () => c.waitFor('Wohnzimmer', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Frames unten', 'Zurück und unten auf Frames tippen.',
          'Unten gibt es jetzt Frames. Die Seite zeigt Wohnzimmer mit dem Album, das gerade läuft.',
          explain: 'Sobald es einen Frame gibt, hat die App unten einen eigenen Bereich dafür.');
      await c.back();
      c.screen('Spaces');
      await tab('Frames', FramesScreen);
      c.screen('Frames');
      await c.check('Wohnzimmer', () => c.waitFor('Wohnzimmer', seconds: 10));
      await c.snap();

      // ================================================================ Dieses Gerät
      c.clearMessages();
      c.step('Noch ein Frame', 'Oben rechts auf die drei Punkte, dann Frame verbinden, Küche eingeben.',
          'Frame einrichten mit dem Namen Küche, darunter Ein anderes Gerät und Dieses Gerät.', kind: 'Abzweigung',
          explain: 'Über Frames geht es genauso. Anna verwaltet nur einen Space, darum fragt Smile nicht, für welchen.');
      await c.tap('Weitere Optionen');
      c.screen('Menü der Frames');
      await c.tap('Frame verbinden', last: true);
      c.screen('Frame einrichten');
      await c.typeInto('Name', 'Küche');
      await c.hideKeyboard();
      await c.check('Zwei Wege', () => c.waitFor('Ein anderes Gerät', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Dieses Gerät: Abbrechen', 'Nach unten wischen, Dieses Gerät antippen, dann Abbrechen.',
          'Zuerst die Frage Dieses Gerät zum Frame machen? mit der Erklärung, dass man hier abgemeldet wird. Nach Abbrechen bleibt alles.',
          kind: 'Abzweigung', explain: 'Ein Gerät ist entweder ein Handy oder ein Frame, nie beides.');
      await tester.scrollUntilVisible(find.text('Dieses Gerät'), 200, scrollable: find.byType(Scrollable).first);
      await tapExact('Dieses Gerät');
      c.screen('Zum-Frame-Frage');
      await c.check('Frage', () => c.waitFor('Dieses Gerät zum Frame machen?', seconds: 5));
      await c.tap('Abbrechen');
      c.screen('Frame einrichten');
      await c.check('Kein Frame Küche', () async => await frameNamed('Küche') == null);
      await c.snap();

      c.clearMessages();
      c.step('Dieses Gerät zum Frame', 'Dieses Gerät, dann Zum Frame machen.',
          'Das Handy wird zum Frame Küche: statt der App zeigt es jetzt die Diashow, noch ohne Fotos. Anna ist hier abgemeldet.',
          kind: 'Abzweigung',
          explain: 'Praktisch für ein altes Handy, das als Bilderrahmen dienen soll. Annas Alben und Fotos bleiben natürlich erhalten.');
      await tapExact('Dieses Gerät');
      c.screen('Zum-Frame-Frage');
      await c.waitFor('Dieses Gerät zum Frame machen?', seconds: 5);
      await c.tap('Zum Frame machen');
      c.screen('Frame: Diashow');
      await c.check('Frame Küche aktiv', () => eventually(() async => (await frameNamed('Küche'))?['lifecycle_state'] == 'active', seconds: 20));
      await c.check('Diashow ohne Fotos', () => c.waitFor('Noch keine Fotos', seconds: 20));
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
