// Kapitel 7: Frame bedienen (tools/testsuite, 2026-10-25), Teil am Handy.
// Der Teil am Tablet läuft gleichzeitig (ch07f_test.dart). Nach jedem
// Schritt, dessen Wirkung man am Frame sieht, sendet das Handy ein Signal
// (pN); das Tablet macht sein Bild und antwortet (fN); erst dann geht es
// am Handy weiter (testsuite_signals, tools/testsuite/state.sql).
// Startet dort, wo Kapitel 6 endet: das Tablet ist der Frame Wohnzimmer
// (Nur zuschauen) und zeigt Geburtstage.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/frame_controls_screen.dart';
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frames_screen.dart';
import 'package:smile_app/screens/photo_viewer_screen.dart';
import 'package:smile_app/services/frame_controls.dart';
import 'package:smile_app/services/frame_service.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 7: Frame bedienen', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch07',
        title: 'Frame bedienen',
        intro: 'Anna steuert den Frame Wohnzimmer vom Handy aus: weiter, zurück, Pause, die neuesten Fotos. Dann probiert sie die '
            'Bedienstufen durch und sieht am Tablet, welche Knöpfe Oma Hilde dann hat. Zum Schluss zeigt sie ein bestimmtes Foto '
            'sofort am Frame und merkt eines als Lieblingsbild. Schritte am Tablet sind mit Am Tablet gekennzeichnet.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 6)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter5(tester);
      final birthdays = seed.albums['Geburtstage']!;
      final frames = FrameService();
      final created = await frames.createFrame(spaceId: seed.spaceId, name: 'Wohnzimmer');
      await frames.updateSettings(frameId: created.id, changes: FrameControlLevels.update(FrameControlLevels.preset(1)));
      await frames.assignChannel(frameId: created.id, channelId: seed.albums['Sommerurlaub 2026']!);
      await frames.assignChannel(frameId: created.id, channelId: birthdays);
      await frames.showChannelNow(frameId: created.id, channelId: birthdays);
      // The tablet claims the code by itself (ch07f) and says when it shows the photos.
      await c.awaitSignal('f0', seconds: 300);

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<Map> frameRow() async => (await TestBackend.select('frames', 'select=*&id=eq.${created.id}')).first as Map;
      Future<void> tapExact(String text, {bool first = false}) async {
        await c.waitFor(text, seconds: 10);
        await tester.tap(first ? find.text(text).first : find.text(text).last, warnIfMissed: false);
        c.logTap(text);
        await c.settle();
      }

      /// Taps until [page] is there (a rebuilding list may swallow a tap).
      Future<void> until(Type page, Future<void> Function() tap) async {
        for (var i = 0; i < 4 && find.byType(page).evaluate().isEmpty; i++) {
          await tap();
          for (var t = 0; t < 30 && find.byType(page).evaluate().isEmpty; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      }

      /// The tablet takes its picture of what this step did, then this goes on.
      Future<void> frameShows(int n) async {
        await TestBackend.signal('p$n');
        await c.awaitSignal('f$n', seconds: 120);
      }

      await c.waitFor('Wanderungen', seconds: 20);
      await c.hideKeyboard();
      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await c.waitFor('Wohnzimmer', seconds: 10);
      await c.start();

      // ================================================================ Fernbedienung
      c.step('Ausgangslage', 'Smile ist geöffnet, unten auf Frames (einmal auf Spaces und zurück).',
          'Die Frames-Seite: Wohnzimmer mit grünem Punkt, darunter Läuft gerade Geburtstage, Ton an und Album wechseln.',
          explain: 'So endet Kapitel 6, dazu läuft auch Sommerurlaub 2026 auf dem Frame mit.');
      await c.check('Läuft gerade Geburtstage', () => c.waitFor('Geburtstage', seconds: 10));
      // The tabs at the bottom, from the Frames page.
      await tapExact('Spaces');
      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await c.check('Frames', () => c.waitFor('Wohnzimmer', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Album wechseln', 'Bei Wohnzimmer auf Album wechseln, dann Sommerurlaub 2026.',
          'Zuerst die Auswahl mit den Alben des Frames, danach steht bei Läuft gerade Sommerurlaub 2026.',
          explain: 'Von der Frames-Seite aus wechselt man mit einem Tipp, welches Album am Frame läuft.');
      await c.tap('Album wechseln');
      c.screen('Album wechseln');
      await c.waitFor('Sommerurlaub 2026', seconds: 5);
      await tapExact('Sommerurlaub 2026');
      c.screen('Frames');
      await c.check('Server: Sommerurlaub läuft', () => eventually(() async =>
          (await frameRow())['current_channel_id'] == seed.albums['Sommerurlaub 2026'], seconds: 10));
      await c.snap();
      await frameShows(2);

      c.clearMessages();
      c.step('Zurück zu Geburtstage', 'Album wechseln, dann Geburtstage.', 'Bei Läuft gerade steht wieder Geburtstage.',
          kind: 'Abzweigung', explain: 'Genauso zurück.');
      await c.tap('Album wechseln');
      c.screen('Album wechseln');
      await c.waitFor('Geburtstage', seconds: 5);
      await tapExact('Geburtstage');
      c.screen('Frames');
      await c.check('Server: Geburtstage läuft', () => eventually(() async => (await frameRow())['current_channel_id'] == birthdays, seconds: 10));
      await c.snap();
      await frameShows(3);

      c.clearMessages();
      c.step('Ton aus', 'Bei Wohnzimmer auf Ton an tippen.', 'Der Knopf heißt jetzt Ton aus.', kind: 'Abzweigung',
          explain: 'Videos laufen am Frame dann ohne Ton.');
      await c.tap('Ton an');
      await c.check('Ton aus', () => c.waitFor('Ton aus', seconds: 5));
      await c.check('Server: Ton aus', () => eventually(() async => (await frameRow())['video_sound'] == false));
      await c.snap();

      c.clearMessages();
      c.step('Ton wieder an', 'Auf Ton aus tippen.', 'Wieder Ton an.', kind: 'Abzweigung', explain: 'Und wieder mit Ton.');
      await c.tap('Ton aus');
      await c.check('Ton an', () => c.waitFor('Ton an', seconds: 5));
      await c.check('Server: Ton an', () => eventually(() async => (await frameRow())['video_sound'] == true));
      await c.snap();

      c.clearMessages();
      c.step('Fernbedienung öffnen', 'Auf Wohnzimmer tippen.',
          'Die Fernbedienung: oben der Frame, darunter die Alben (Geburtstage läuft gerade), die Knöpfe Zurück, Pause, Weiter und Neueste 20 Fotos abspielen.',
          explain: 'Hier steuert Anna den Frame, egal welche Bedienstufe er hat.');
      await until(FrameRemoteScreen, () => tapExact('Wohnzimmer'));
      c.screen('Fernbedienung');
      await c.check('Knöpfe', () => c.waitFor('Neueste 20 Fotos abspielen', seconds: 8));
      await c.check('Die zwei Alben des Frames', () async =>
          await c.waitFor('Geburtstage', seconds: 5) && await c.waitFor('~Sommerurla', seconds: 1));
      await c.snap();

      Future<void> remote(String tooltip) async {
        await tester.tap(find.byTooltip(tooltip).first, warnIfMissed: false);
        c.logTap(tooltip);
        await c.settle();
      }

      c.clearMessages();
      c.step('Weiter', 'Auf den Pfeil nach rechts (Weiter) tippen.', 'Am Handy ändert sich nichts; der Frame springt zum nächsten Foto.',
          explain: 'Der Frame führt den Befehl sofort aus.');
      await remote('Weiter');
      await c.snap();
      await frameShows(7);

      c.clearMessages();
      c.step('Pause', 'Auf den Pause-Knopf in der Mitte tippen.', 'Der Knopf zeigt jetzt Abspielen; der Frame hält an und zeigt Pause.',
          explain: 'Praktisch, wenn ein Foto länger stehen bleiben soll.');
      await remote('Pause');
      await c.check('Abspielen-Knopf', () => eventually(() => find.byTooltip('Abspielen').evaluate().isNotEmpty, seconds: 3));
      await c.snap();
      await frameShows(8);

      c.clearMessages();
      c.step('Abspielen', 'Auf Abspielen tippen.', 'Wieder der Pause-Knopf; der Frame läuft weiter.', explain: 'Die Diashow geht weiter.');
      await remote('Abspielen');
      await c.check('Pause-Knopf', () => eventually(() => find.byTooltip('Pause').evaluate().isNotEmpty, seconds: 3));
      await c.snap();
      await frameShows(9);

      c.clearMessages();
      c.step('Zurück', 'Auf den Pfeil nach links (Zurück) tippen.', 'Der Frame springt zum vorigen Foto.', explain: 'Ein Foto zurück.');
      await remote('Zurück');
      await c.snap();
      await frameShows(10);

      c.clearMessages();
      c.step('Neueste 20 Fotos', 'Auf Neueste 20 Fotos abspielen tippen.',
          'Der Frame spielt die 20 neuesten Fotos und Videos aus seinen Alben.', explain: 'Zum Beispiel nach einem Fest: erst einmal das Neue.');
      await c.tap('Neueste 20 Fotos abspielen');
      await c.snap();
      await frameShows(11);

      c.clearMessages();
      c.step('Album über die Fernbedienung', 'Oben bei Alben auf Sommerurlaub 2026 tippen.',
          'Sommerurlaub 2026 ist jetzt koralle umrandet und läuft gerade; der Frame zeigt es.',
          explain: 'Ein Tipp auf ein Album der Fernbedienung zeigt es sofort am Frame.');
      await tester.scrollUntilVisible(find.text('Sommerurlaub 2026'), -300, scrollable: find.byType(Scrollable).first);
      await tapExact('Sommerurlaub 2026');
      await c.check('Server: Sommerurlaub läuft', () => eventually(() async =>
          (await frameRow())['current_channel_id'] == seed.albums['Sommerurlaub 2026'], seconds: 10));
      await c.snap();
      await frameShows(12);

      // ================================================================ Bedienstufen
      c.clearMessages();
      c.step('Bedienstufe öffnen', 'Nach unten wischen und auf Bedienstufe (Nur zuschauen) tippen.',
          'Bedienung am Frame: die Erklärung, darunter die Stufen 1 bis 5 (Nur zuschauen ist gewählt) und weiter unten einzelne Schalter.',
          explain: 'Die App steuert den Frame immer vollständig. Die Stufe legt fest, was die Person vor dem Frame selbst tun darf.');
      await tester.scrollUntilVisible(c.find_('Bedienstufe'), 300, scrollable: find.byType(Scrollable).first);
      await until(FrameControlsScreen, () => c.tap('Bedienstufe'));
      c.screen('Bedienung am Frame');
      await c.check('Stufen', () => c.waitFor('Blättern', seconds: 5));
      await c.snap();

      Future<void> level(int n, String name, int signal) async {
        // The list may have scrolled down (single switches): the level in sight first.
        await tester.scrollUntilVisible(find.text(name), -300, scrollable: find.byType(Scrollable).first);
        await c.settle();
        await tapExact(name);
        await c.check('Server: Stufe $n', () => eventually(() async => (await frameRow())['control_level'] == n));
        await c.snap();
        await frameShows(signal);
      }

      c.clearMessages();
      c.step('Stufe 2: Blättern', 'Blättern antippen.', 'Blättern ist gewählt. Am Frame gibt es jetzt Pause und einen großen Weiter-Knopf.',
          explain: 'Für jemanden, der nur selbst weiterblättern möchte.');
      await level(2, 'Blättern', 13);

      c.clearMessages();
      c.step('Stufe 3: Einfach', 'Einfach antippen.', 'Am Frame dazu Zurück, Neueste und Merken.',
          explain: 'Die Stufe, die ein neuer Frame von sich aus hat.');
      await level(3, 'Einfach', 14);

      c.clearMessages();
      c.step('Stufe 4: Komfort', 'Komfort antippen.', 'Am Frame dazu Album, Übersicht, Dauer und Titel.',
          explain: 'Wer schon etwas mehr selbst machen möchte.');
      await level(4, 'Komfort', 15);

      c.clearMessages();
      c.step('Stufe 5: Alles selbst', 'Alles selbst antippen.', 'Am Frame dazu Einstellungen: alles, was es gibt.',
          explain: 'Für jemanden, der den Frame selbst einrichten möchte.');
      await level(5, 'Alles selbst', 16);

      c.clearMessages();
      c.step('Einzelner Schalter', 'Nach unten wischen und bei Einzeln erlaubt den Schalter Weiter ausschalten.',
          'Oben ist jetzt Eigene Auswahl gewählt; am Frame fehlt der Weiter-Knopf.',
          explain: 'Jeder Knopf lässt sich auch einzeln erlauben oder verbieten.');
      final weiter = find.widgetWithText(SwitchListTile, 'Weiter');
      await tester.scrollUntilVisible(weiter, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(weiter, warnIfMissed: false);
      c.logTap('Weiter');
      await c.settle();
      await c.check('Server: eigene Auswahl', () => eventually(() async {
        final row = await frameRow();
        return row['control_level'] == null && (row['controls'] as Map)['next'] == false;
      }));
      await tester.scrollUntilVisible(c.find_('Eigene Auswahl'), -300, scrollable: find.byType(Scrollable).first);
      await c.check('Eigene Auswahl', () => c.waitFor('Eigene Auswahl', seconds: 3));
      await c.snap();
      await frameShows(17);

      c.clearMessages();
      c.step('Alle Schalter einzeln', 'Jeden Schalter bei Einzeln erlaubt einmal aus- und wieder einschalten (Weiter zuletzt wieder ein).',
          'Am Ende sind alle Schalter an, oben ist wieder Alles selbst gewählt.', kind: 'Abzweigung',
          explain: 'Jeder Schalter speichert sofort; sind alle an, ist es wieder Stufe 5.');
      for (final (key, label) in const [
        ('back', 'Zurück'),
        ('pause', 'Pause'),
        ('newest', 'Neueste Fotos'),
        ('favorite', 'Lieblingsbilder merken'),
        ('favorites', 'Lieblingsbilder abspielen'),
        ('overview', 'Übersicht'),
        ('album', 'Album wechseln'),
        ('duration', 'Anzeigedauer'),
        ('captions', 'Titel ein- oder ausblenden'),
        ('playback', 'Wiedergabe-Einstellungen'),
        ('next', 'Weiter'),
      ]) {
        final tile = find.widgetWithText(SwitchListTile, label);
        await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
        final was = tester.widget<SwitchListTile>(tile).value;
        if (key != 'next') {
          await tester.tap(tile, warnIfMissed: false);
          c.logTap(label);
          await c.settle();
          await c.check('$label aus', () => eventually(() async => (await frameRow())['controls'][key] == !was));
        }
        await tester.tap(tile, warnIfMissed: false);
        c.logTap(label);
        await c.settle();
        await c.check('$label an', () => eventually(() async => (await frameRow())['controls'][key] == true));
      }
      await c.check('Server: wieder Stufe 5', () => eventually(() async => (await frameRow())['control_level'] == 5));
      await tester.scrollUntilVisible(find.text('Alles selbst'), -300, scrollable: find.byType(Scrollable).first);
      await c.snap();

      c.clearMessages();
      c.step('Zurück zu Nur zuschauen', 'Nur zuschauen antippen.', 'Nur zuschauen ist wieder gewählt; am Frame gibt es keine Knöpfe mehr.',
          explain: 'Für Oma Hilde wieder die einfachste Stufe.');
      await level(1, 'Nur zuschauen', 18);

      // ================================================================ Jetzt am Frame zeigen, Lieblingsbild
      final obst = (await TestBackend.select('media_items', 'select=id&caption=eq.${Uri.encodeComponent('Obst für alle')}')).first['id'] as String;
      c.clearMessages();
      c.step('Foto im Album öffnen', 'Zweimal zurück, unten Alben, Geburtstage öffnen und auf die Obstschale tippen.',
          'Die Obstschale groß, oben das Herz (Lieblingsbild für den Frame) und Jetzt am Frame zeigen.',
          explain: 'Aus jedem Foto heraus geht es direkt auf den Frame.');
      await c.back();
      await c.back();
      c.screen('Frames');
      await until(ChannelFeedScreen, () async {
        await tapExact('Alben');
        await c.tap('Geburtstage');
      });
      c.screen('Album');
      await c.waitFor('Diashow', seconds: 10);
      final item = find.byKey(ValueKey(obst), skipOffstage: false);
      for (var i = 0; i < 20 && item.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
        await c.settle();
      }
      await Scrollable.ensureVisible(item.evaluate().first, alignment: 0.5);
      await c.settle();
      await until(PhotoViewerScreen, () async {
        await tester.tap(find.byKey(ValueKey(obst)), warnIfMissed: false);
        await c.settle();
      });
      c.logTap('Foto');
      c.screen('Foto');
      await c.check('Jetzt am Frame zeigen', () => eventually(() => find.byTooltip('Jetzt am Frame zeigen').evaluate().isNotEmpty, seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Jetzt am Frame zeigen', 'Auf Jetzt am Frame zeigen tippen.', 'Der Frame zeigt sofort die Obstschale mit dem Titel Obst für alle.',
          explain: 'Gut, wenn man gerade über ein bestimmtes Foto spricht.');
      await tester.tap(find.byTooltip('Jetzt am Frame zeigen').first, warnIfMissed: false);
      c.logTap('Jetzt am Frame zeigen');
      await c.settle();
      await c.snap();
      await frameShows(20);

      c.clearMessages();
      c.step('Lieblingsbild', 'Oben auf das Herz tippen.', 'Das Herz ist jetzt gefüllt und koralle; die Obstschale ist ein Lieblingsbild von Wohnzimmer.',
          explain: 'Lieblingsbilder laufen am Frame auf Wunsch als eigene Runde.');
      await tester.tap(find.byTooltip('Lieblingsbild für den Frame').first, warnIfMissed: false);
      c.logTap('Lieblingsbild für den Frame');
      await c.settle();
      await c.check('Server: Lieblingsbild', () => eventually(() async =>
          (await TestBackend.select('frame_favorites', 'select=media_item_id&frame_id=eq.${created.id}'))
              .any((r) => (r as Map)['media_item_id'] == obst)));
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}
