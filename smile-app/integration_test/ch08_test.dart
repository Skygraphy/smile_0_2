// Kapitel 8: Frame-Einstellungen und Wiedergabe (tools/testsuite, 2026-10-26),
// Teil am Handy. Der Teil am Tablet läuft gleichzeitig (ch08f_test.dart),
// mit Signalen wie in Kapitel 7 (pN vom Handy, fN vom Tablet).
// Startet dort, wo Kapitel 6 endet: das Tablet ist der Frame Wohnzimmer
// (Nur zuschauen) mit Sommerurlaub 2026 und Geburtstage, es läuft Geburtstage.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/create_frame_screen.dart';
import 'package:smile_app/screens/frame_controls_screen.dart';
import 'package:smile_app/screens/frame_favorites_add_screen.dart';
import 'package:smile_app/screens/frame_favorites_screen.dart';
import 'package:smile_app/screens/frame_playback_screen.dart';
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frame_settings_screen.dart';
import 'package:smile_app/screens/photo_viewer_screen.dart';
import 'package:smile_app/screens/spaces_screen.dart';
import 'package:smile_app/screens/video_player_screen.dart';
import 'package:smile_app/services/frame_controls.dart';
import 'package:smile_app/services/frame_service.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 8: Frame-Einstellungen und Wiedergabe', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch08',
        title: 'Frame-Einstellungen und Wiedergabe',
        intro: 'Anna richtet den Frame Wohnzimmer ein: Lieblingsbilder, was in welcher Reihenfolge läuft, Uhr, Nachtruhe, '
            'welche Alben er zeigt, Name und Bild. Sie widerruft ihn probeweise und aktiviert ihn wieder. Zum Schluss stellt '
            'Oma Hilde am Tablet selbst die Wiedergabe ein. Schritte am Tablet sind mit Am Tablet gekennzeichnet.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 6)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter5(tester);
      final birthdays = seed.albums['Geburtstage']!;
      final summer = seed.albums['Sommerurlaub 2026']!;
      final frames = FrameService();
      final created = await frames.createFrame(spaceId: seed.spaceId, name: 'Wohnzimmer');
      await frames.updateSettings(frameId: created.id, changes: FrameControlLevels.update(FrameControlLevels.preset(1)));
      await frames.assignChannel(frameId: created.id, channelId: summer);
      await frames.assignChannel(frameId: created.id, channelId: birthdays);
      await frames.showChannelNow(frameId: created.id, channelId: birthdays);
      // The tablet claims the code by itself (ch08f) and says when it shows the photos.
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
      Future<bool> saved(String column, Object? value) => eventually(() async => (await frameRow())[column] == value);
      Future<List<String>> favorites() async =>
          (await TestBackend.select('frame_favorites', 'select=media_item_id&frame_id=eq.${created.id}'))
              .map((r) => (r as Map)['media_item_id'] as String)
              .toList();
      Future<List<String>> assigned() async =>
          (await TestBackend.select('frame_channels', 'select=channel_id&frame_id=eq.${created.id}'))
              .map((r) => (r as Map)['channel_id'] as String)
              .toList();
      final summerPhoto = (await TestBackend.select('media_items', 'select=id&channel_id=eq.$summer')).first['id'] as String;

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
        if (find.byType(page).evaluate().isEmpty) throw TestFailure('Seite erscheint nicht: $page');
      }

      /// Back until [page] is on top again.
      Future<void> backTo(Type page) async {
        for (var i = 0; i < 4; i++) {
          await c.back();
          if (find.byType(page).evaluate().isNotEmpty) return;
        }
      }

      /// The tablet takes its picture of what this step did, then this goes on.
      Future<void> frameShows(int n) async {
        await TestBackend.signal('p$n');
        await c.awaitSignal('f$n', seconds: 180);
      }

      Future<void> scrollTo(Finder f, {double by = 300}) async {
        await tester.scrollUntilVisible(f, by, scrollable: find.byType(Scrollable).first);
        await c.settle();
      }

      /// Taps a switch row by its title (scrolled into sight first).
      Future<void> flip(String title) async {
        final tile = find.widgetWithText(SwitchListTile, title);
        await scrollTo(tile);
        await tester.tap(tile, warnIfMissed: false);
        c.logTap(title);
        await c.settle();
      }

      Future<void> chip(String label) async {
        final f = find.widgetWithText(ChoiceChip, label);
        await scrollTo(f);
        await tester.tap(f, warnIfMissed: false);
        c.logTap(label);
        await c.settle();
        // Shown as chosen? Tells a lost tap from a choice the app did not save.
        await c.check('$label gewählt', () async {
          for (var i = 0; i < 20; i++) {
            if (f.evaluate().isNotEmpty && tester.widget<ChoiceChip>(f.first).selected) return true;
            await tester.pump(const Duration(milliseconds: 100));
          }
          return false;
        });
      }

      Future<void> menu() async {
        await tester.tap(find.byTooltip('Weitere Optionen').last, warnIfMissed: false);
        c.logTap('Weitere Optionen');
        await c.settle();
      }

      await c.waitFor('Wanderungen', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Über die Space-Seite
      c.step('Ausgangslage', 'Smile ist geöffnet, unten Spaces, dann Familie Berger.',
          'Die Seite von Familie Berger, weiter unten 1 Frame: Wohnzimmer, Aktiv.',
          explain: 'So endet Kapitel 6. Zum Frame kommt man über Frames unten oder über die Seite seines Space.');
      await until(SpacesScreen, () => tapExact('Spaces'));
      c.screen('Spaces');
      await c.tap('Familie Berger', last: true);
      c.screen('Space');
      await c.check('1 Frame', () => c.waitFor('1 Frame', seconds: 10));
      await scrollTo(find.text('Wohnzimmer'));
      await c.snap();

      c.clearMessages();
      c.step('Frame auf der Space-Seite', 'Auf Wohnzimmer tippen.', 'Die Fernbedienung von Wohnzimmer.',
          explain: 'Derselbe Weg wie über Frames unten.');
      await until(FrameRemoteScreen, () => tapExact('Wohnzimmer'));
      c.screen('Fernbedienung');
      await c.check('Fernbedienung', () => c.waitFor('Neueste 20 Fotos abspielen', seconds: 8));
      await c.snap();

      // ================================================================ Lieblingsbilder
      c.clearMessages();
      c.step('Lieblingsbilder: noch keine', 'Nach unten wischen, bei Lieblingsbilder auf Alle ansehen.',
          'Lieblingsbilder: Noch keine Lieblingsbilder, darunter der Hinweis und Hinzufügen.',
          explain: 'Lieblingsbilder gehören zu einem Frame. Er kann sie als eigene Runde abspielen.');
      await scrollTo(find.text('Alle ansehen'));
      await c.check('LIEBLINGSBILDER · 0', () => c.waitFor('LIEBLINGSBILDER · 0', seconds: 5));
      await until(FrameFavoritesScreen, () => tapExact('Alle ansehen'));
      c.screen('Lieblingsbilder');
      await c.check('Noch keine', () => c.waitFor('Noch keine Lieblingsbilder', seconds: 8));
      await c.snap();

      final heart = find.byIcon(SmileIcons.heart);
      Finder favoriteTiles() => find.descendant(of: find.byType(GridView), matching: find.byType(AspectRatio));
      bool viewing() => find.byType(PhotoViewerScreen).evaluate().isNotEmpty || find.byType(VideoPlayerScreen).evaluate().isNotEmpty;

      /// Opens a photo or video tile (big) until it shows.
      Future<void> open(Finder tile) async {
        for (var i = 0; i < 4 && !viewing(); i++) {
          await tester.tap(tile, warnIfMissed: false);
          for (var t = 0; t < 30 && !viewing(); t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        if (!viewing()) throw TestFailure('Foto öffnet sich nicht');
        c.logTap('Foto');
        c.screen('Foto');
      }

      final hearted = find.byIcon(SmileIcons.heartFilled);
      Finder tiles() => find.descendant(of: find.byType(GridView), matching: find.byType(ClipRRect));

      c.clearMessages();
      c.step('Lieblingsbilder hinzufügen', 'Auf Hinzufügen in der Mitte tippen.',
          'Lieblingsbilder · Wohnzimmer: oben die Alben des Frames (Sommerurlaub 2026 gewählt), darunter seine Fotos mit einem Herz unten rechts.',
          explain: 'Hier merkt man Lieblingsbilder aus allen Alben des Frames auf einmal.');
      await until(FrameFavoritesAddScreen, () => c.tap('Hinzufügen', last: true));
      c.screen('Lieblingsbilder hinzufügen');
      await chip('Sommerurlaub 2026');
      await c.check('Ein Foto mit Herz', () => eventually(() => heart.evaluate().length == 1, seconds: 10));
      await c.letLoad(seconds: 2);
      await c.snap();

      c.clearMessages();
      c.step('Herz antippen', 'Beim Strandfoto auf das Herz tippen.', 'Das Herz ist jetzt gefüllt und koralle.',
          explain: 'Ein Tipp merkt das Foto sofort für diesen Frame.');
      await tester.tap(heart.first, warnIfMissed: false);
      c.logTap('Lieblingsbild');
      await c.settle();
      await c.check('Server: Strandfoto gemerkt', () => eventually(() async => (await favorites()).contains(summerPhoto)));
      await c.check('Gefülltes Herz', () => hearted.evaluate().isNotEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Anderes Album', 'Oben auf Geburtstage tippen und bei den ersten beiden Fotos auf das Herz.',
          'Die Fotos von Geburtstage; die ersten beiden haben ein gefülltes Herz.',
          explain: 'Zwischen den Alben wechselt man oben.');
      await chip('Geburtstage');
      await c.check('Fotos von Geburtstage', () => eventually(() => heart.evaluate().length >= 4, seconds: 10));
      await tester.tap(heart.at(0), warnIfMissed: false);
      await c.settle();
      await tester.tap(heart.at(0), warnIfMissed: false);
      c.logTap('Lieblingsbild');
      await c.settle();
      await c.check('Server: drei Lieblingsbilder', () => eventually(() async => (await favorites()).length == 3));
      await c.snap();

      c.clearMessages();
      c.step('Herz zurücknehmen', 'Beim ersten Foto noch einmal auf das Herz tippen.', 'Das Herz ist wieder leer.',
          kind: 'Abzweigung', explain: 'Genauso nimmt man ein Lieblingsbild zurück.');
      await tester.tap(hearted.at(0), warnIfMissed: false);
      c.logTap('Lieblingsbild');
      await c.settle();
      await c.check('Server: zwei Lieblingsbilder', () => eventually(() async => (await favorites()).length == 2));
      await c.snap();

      c.clearMessages();
      c.step('Foto groß ansehen', 'Mitten auf das zweite Foto tippen.', 'Das Foto (oder Video) groß.', kind: 'Abzweigung',
          explain: 'Ein Tipp auf das Foto selbst (nicht auf das Herz) zeigt es groß.');
      await open(tiles().at(1));
      await c.snap();

      c.clearMessages();
      c.step('Zurück zu den Lieblingsbildern', 'Zweimal zurück.',
          'Lieblingsbilder mit zwei Fotos, darunter jeweils Anna Berger und die Uhrzeit von heute.',
          explain: 'Das zuletzt gemerkte steht vorne; darunter steht, wer es gemerkt hat (am Frame steht Am Frame).');
      await c.back();
      c.screen('Lieblingsbilder hinzufügen');
      await backTo(FrameFavoritesScreen);
      c.screen('Lieblingsbilder');
      await c.check('Zwei Lieblingsbilder', () => eventually(() => favoriteTiles().evaluate().length == 2, seconds: 10));
      await c.check('Anna Berger · heute', () => c.waitFor('Anna Berger · heute', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Lieblingsbild öffnen', 'Auf das Strandfoto (das zweite) tippen.', 'Das Strandfoto groß.',
          explain: 'Lieblingsbilder lassen sich von hier aus ansehen.');
      await open(favoriteTiles().at(1));
      await c.check('Das Strandfoto', () => find.byType(PhotoViewerScreen).evaluate().isNotEmpty);
      await c.snap();
      await backTo(FrameFavoritesScreen);
      c.screen('Lieblingsbilder');

      c.clearMessages();
      c.step('Auswählen', 'Lange auf das erste Foto drücken, dann das zweite antippen.',
          'Oben steht 2 ausgewählt, beide Fotos sind koralle umrandet.',
          explain: 'Wie bei WhatsApp: langes Drücken startet die Auswahl.');
      await tester.longPress(favoriteTiles().at(0), warnIfMissed: false);
      c.logTap('Foto lange drücken');
      await c.settle();
      await c.check('1 ausgewählt', () => c.waitFor('1 ausgewählt', seconds: 3));
      await tester.tap(favoriteTiles().at(1), warnIfMissed: false);
      c.logTap('Foto');
      await c.settle();
      await c.check('2 ausgewählt', () => c.waitFor('2 ausgewählt', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Abwählen und Alle', 'Das zweite Foto noch einmal antippen, dann oben auf Alle.',
          'Zuerst 1 ausgewählt, nach Alle wieder 2 ausgewählt.', kind: 'Abzweigung',
          explain: 'Ein Tipp nimmt ein Foto aus der Auswahl, Alle wählt alle.');
      await tester.tap(favoriteTiles().at(1), warnIfMissed: false);
      c.logTap('Foto');
      await c.settle();
      await c.check('1 ausgewählt', () => c.waitFor('1 ausgewählt', seconds: 3));
      await tester.tap(find.byTooltip('Alle'), warnIfMissed: false);
      c.logTap('Alle');
      await c.settle();
      await c.check('2 ausgewählt', () => c.waitFor('2 ausgewählt', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Auswahl beenden', 'Oben links auf das X tippen.', 'Keine Auswahl mehr, oben wieder Lieblingsbilder.',
          kind: 'Abzweigung', explain: 'Nichts wird entfernt.');
      await tester.tap(find.byIcon(SmileIcons.close).first, warnIfMissed: false);
      c.logTap('Schließen');
      await c.settle();
      await c.check('Keine Auswahl', () => c.gone('ausgewählt', seconds: 3));
      await c.check('Server: noch zwei', () async => (await favorites()).length == 2);
      await c.snap();

      c.clearMessages();
      c.step('Entfernen: Frage', 'Lange auf das erste Foto drücken, dann oben auf den Papierkorb.',
          '1 Lieblingsbild von Wohnzimmer entfernen? mit dem Hinweis, dass die Fotos in ihren Alben bleiben.',
          explain: 'Smile fragt vorher.');
      await tester.longPress(favoriteTiles().at(0), warnIfMissed: false);
      c.logTap('Foto lange drücken');
      await c.settle();
      await tester.tap(find.byTooltip('Entfernen'), warnIfMissed: false);
      c.logTap('Entfernen');
      await c.settle();
      c.screen('Lieblingsbild entfernen?');
      await c.check('Frage', () => c.waitFor('1 Lieblingsbild von Wohnzimmer entfernen?', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Entfernen: Abbrechen', 'Abbrechen antippen.', 'Die Frage schließt sich, beide Lieblingsbilder bleiben.',
          kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tap('Abbrechen');
      c.screen('Lieblingsbilder');
      await c.check('Server: noch zwei', () async => (await favorites()).length == 2);
      await c.snap();

      c.clearMessages();
      c.step('Entfernen: daneben tippen', 'Auf den Papierkorb, dann oben neben die Frage tippen.', 'Die Frage schließt sich, beide Lieblingsbilder bleiben.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await tester.tap(find.byTooltip('Entfernen'), warnIfMissed: false);
      c.logTap('Entfernen');
      await c.settle();
      c.screen('Lieblingsbild entfernen?');
      await c.waitFor('1 Lieblingsbild von Wohnzimmer entfernen?', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Lieblingsbilder');
      await c.check('Frage zu', () => c.gone('1 Lieblingsbild von Wohnzimmer entfernen?', seconds: 3));
      await c.check('Server: noch zwei', () async => (await favorites()).length == 2);
      await c.snap();

      c.clearMessages();
      c.step('Entfernen', 'Wieder auf den Papierkorb, dann Entfernen.', 'Nur noch das Strandfoto ist da.',
          explain: 'Das Foto selbst bleibt im Album.');
      await tester.tap(find.byTooltip('Entfernen'), warnIfMissed: false);
      c.logTap('Entfernen');
      await c.settle();
      c.screen('Lieblingsbild entfernen?');
      await c.tap('Entfernen', last: true);
      c.screen('Lieblingsbilder');
      await c.check('Server: nur das Strandfoto', () => eventually(() async {
        final f = await favorites();
        return f.length == 1 && f.first == summerPhoto;
      }));
      await c.check('Ein Foto', () => eventually(() => favoriteTiles().evaluate().length == 1, seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Zurück zur Fernbedienung', 'Oben links zurück.', 'Bei Lieblingsbilder steht jetzt 1 und das Strandfoto klein.',
          explain: 'Die Fernbedienung zeigt die neuesten vier Lieblingsbilder.');
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');
      await c.check('LIEBLINGSBILDER · 1', () => c.waitFor('LIEBLINGSBILDER · 1', seconds: 8));
      await c.snap();

      // ================================================================ Ton
      c.clearMessages();
      c.step('Ton bei Videos aus', 'Auf die Kachel Ton bei Videos tippen.', 'Die Kachel zeigt Aus.',
          explain: 'Dasselbe wie Ton an/aus auf der Frames-Seite.');
      await scrollTo(c.find_('Ton bei Videos'));
      await c.tap('Ton bei Videos');
      await c.check('Server: Ton aus', () => saved('video_sound', false));
      await c.snap();

      c.clearMessages();
      c.step('Ton bei Videos an', 'Noch einmal antippen.', 'Wieder An.', kind: 'Abzweigung', explain: 'Und wieder mit Ton.');
      await c.tap('Ton bei Videos');
      await c.check('Server: Ton an', () => saved('video_sound', true));
      await c.snap();

      // ================================================================ Wiedergabe
      c.clearMessages();
      c.step('Wiedergabe öffnen', 'Auf Wiedergabe (Ein Album · Der Reihe nach · 10 Sekunden) tippen.',
          'Die Seite Wiedergabe: Was läuft, Reihenfolge, Anzeigedauer, Am Ende, Videos, Bildschirm füllen und die Schalter.',
          explain: 'Was und wie der Frame abspielt, stellt immer die App ein, egal welche Bedienstufe er hat.');
      await scrollTo(c.find_('Wiedergabe'));
      await until(FramePlaybackScreen, () => c.tap('Wiedergabe'));
      c.screen('Wiedergabe');
      await c.check('Was läuft', () => c.waitFor('WAS LÄUFT', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Alle Alben im Wechsel', 'Bei Was läuft auf Alle Alben im Wechsel tippen.',
          'Alle Alben im Wechsel ist gewählt; der Frame wechselt nach jedem Album zum nächsten.',
          explain: 'Statt nur des einen Albums laufen alle Alben des Frames nacheinander.');
      await chip('Alle Alben im Wechsel');
      await c.check('Server: Wechsel', () => saved('content_mode', 'rotate'));
      await c.snap();
      await frameShows(1);

      c.clearMessages();
      c.step('Aktuelles', 'Auf Aktuelles tippen.', 'Darunter erscheint Aktuelles bedeutet mit Letzte 10, 20, 50 und 100 Fotos.',
          explain: 'Aktuelles spielt die neuesten Fotos aus allen Alben des Frames.');
      await chip('Aktuelles');
      await c.check('Server: Aktuelles', () => saved('content_mode', 'recent'));
      await c.check('Aktuelles bedeutet', () => c.waitFor('AKTUELLES BEDEUTET', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Wie viele aktuelle Fotos', 'Nacheinander Letzte 10, 50, 100 und wieder 20 Fotos antippen.',
          'Am Ende ist Letzte 20 Fotos gewählt.', kind: 'Abzweigung', explain: 'Jede Wahl gilt sofort.');
      for (final n in const [10, 50, 100, 20]) {
        await chip('Letzte $n Fotos');
        await c.check('Server: $n', () => saved('recent_count', n));
      }
      await c.snap();

      c.clearMessages();
      c.step('Nur Lieblingsbilder', 'Bei Was läuft auf Lieblingsbilder tippen.',
          'Lieblingsbilder ist gewählt, Aktuelles bedeutet verschwindet. Der Frame zeigt nur noch das Strandfoto.',
          explain: 'So läuft dauerhaft die Lieblingsrunde.');
      await chip('Lieblingsbilder');
      await c.check('Server: Lieblingsbilder', () => saved('content_mode', 'favorites'));
      await c.snap();
      await frameShows(2);

      c.clearMessages();
      c.step('Wieder ein Album', 'Auf Ein Album tippen.', 'Ein Album ist gewählt; der Frame zeigt wieder Geburtstage.',
          explain: 'Die Einstellung, mit der ein Frame beginnt.');
      await chip('Ein Album');
      await c.check('Server: Ein Album', () => saved('content_mode', 'album'));
      await c.snap();

      c.clearMessages();
      c.step('Reihenfolge', 'Nacheinander Neueste zuerst, Zufällig und Der Reihe nach antippen.',
          'Am Ende ist wieder Der Reihe nach gewählt.', explain: 'Der Reihe nach heißt: das älteste Foto zuerst.');
      for (final (label, value) in const [('Neueste zuerst', 'newest'), ('Zufällig', 'shuffle'), ('Der Reihe nach', 'oldest')]) {
        await chip(label);
        await c.check('Server: $label', () => saved('play_order', value));
      }
      await c.snap();

      c.clearMessages();
      c.step('Anzeigedauer', 'Nacheinander 5 Sekunden, 1 Minute, 20 Sekunden und 10 Sekunden antippen.',
          'Am Ende ist 10 Sekunden gewählt.', explain: 'So lange steht jedes Foto.');
      for (final (label, value) in const [('5 Sekunden', 5), ('1 Minute', 60), ('20 Sekunden', 20), ('10 Sekunden', 10)]) {
        await chip(label);
        await c.check('Server: $label', () => saved('slideshow_interval_seconds', value));
      }
      await c.snap();

      c.clearMessages();
      c.step('Am Ende', 'Übersicht zeigen antippen, dann wieder Endlosschleife.', 'Am Ende ist Endlosschleife gewählt.',
          explain: 'Nach dem letzten Foto: von vorne oder eine Übersicht aller Fotos.');
      await chip('Übersicht zeigen');
      await c.check('Server: Übersicht', () => saved('end_behavior', 'overview'));
      await chip('Endlosschleife');
      await c.check('Server: Endlosschleife', () => saved('end_behavior', 'loop'));
      await c.snap();

      c.clearMessages();
      c.step('Videos', 'Bei Videos nacheinander Wie ein Foto (10 s), Keine Videos und Ganze Länge antippen.',
          'Am Ende ist Ganze Länge gewählt.', explain: 'Videos ganz, nur so kurz wie ein Foto oder gar nicht.');
      for (final (label, value) in const [('Wie ein Foto (10 s)', 'photo'), ('Keine Videos', 'none'), ('Ganze Länge', 'full')]) {
        await chip(label);
        await c.check('Server: $label', () => saved('video_length', value));
      }
      await c.snap();

      c.clearMessages();
      c.step('Bildschirm füllen', 'Nacheinander Nie, Immer und Wenn passend antippen.', 'Am Ende ist Wenn passend gewählt.',
          explain: 'Ob ein Foto den Bildschirm ganz füllt (und dabei Ränder abschneidet).');
      for (final (label, value) in const [('Nie', 'fit'), ('Immer', 'fill'), ('Wenn passend', 'auto')]) {
        await chip(label);
        await c.check('Server: $label', () => saved('fill_mode', value));
      }
      await c.snap();

      c.clearMessages();
      c.step('Schalter', 'Langsamer Zoom, Bild dreht sich mit dem Frame, Neue Fotos sofort zeigen, Titel anzeigen und Videos mit Ton je einmal aus- und wieder einschalten.',
          'Am Ende stehen alle wie vorher.', explain: 'Jeder Schalter speichert sofort.');
      for (final (title, column) in const [
        ('Langsamer Zoom', 'slow_zoom'),
        ('Bild dreht sich mit dem Frame', 'rotate_with_device'),
        ('Neue Fotos sofort zeigen', 'show_new_immediately'),
        ('Titel anzeigen', 'show_captions'),
        ('Videos mit Ton', 'video_sound'),
      ]) {
        final was = (await frameRow())[column] as bool;
        await flip(title);
        await c.check('Server: $title ${was ? 'aus' : 'an'}', () => saved(column, !was));
        await flip(title);
        await c.check('Server: $title wie vorher', () => saved(column, was));
      }
      await c.snap();

      c.clearMessages();
      c.step('Große Uhr', 'Große Uhr mit Datum einschalten.', 'Der Schalter ist an; am Frame steht oben rechts die Uhrzeit mit Datum.',
          explain: 'Praktisch, wenn der Frame auch als Uhr dienen soll.');
      await flip('Große Uhr mit Datum');
      await c.check('Server: Uhr an', () => saved('show_clock', true));
      await c.snap();
      await frameShows(3);

      c.clearMessages();
      c.step('Große Uhr aus', 'Wieder ausschalten.', 'Keine Uhr mehr am Frame.', kind: 'Abzweigung', explain: 'Und wieder ohne.');
      await flip('Große Uhr mit Datum');
      await c.check('Server: Uhr aus', () => saved('show_clock', false));
      await c.snap();

      c.clearMessages();
      c.step('Absender aus', 'Absender einblenden ausschalten.', 'Am Frame steht oben links nicht mehr Album und Absender.',
          explain: 'Dann zeigt der Frame nur das Foto.');
      await flip('Absender einblenden');
      await c.check('Server: Absender aus', () => saved('show_sender', false));
      await c.snap();
      await frameShows(4);

      c.clearMessages();
      c.step('Absender wieder an', 'Wieder einschalten.', 'Oben links stehen wieder Album und Absender.', kind: 'Abzweigung',
          explain: 'Und wieder mit.');
      await flip('Absender einblenden');
      await c.check('Server: Absender an', () => saved('show_sender', true));
      await c.snap();
      await frameShows(5);

      c.clearMessages();
      c.step('Nachtruhe', 'Ganz unten Nachtruhe einschalten.', 'Darunter 22:00 bis 07:00, dazu die Zeilen Dunkel ab und Hell ab.',
          explain: 'In dieser Zeit bleibt der Bildschirm des Frames dunkel.');
      await flip('Nachtruhe');
      await c.check('Server: 22 bis 7 Uhr', () => eventually(() async {
        final row = await frameRow();
        return row['quiet_from'] == '22:00:00' && row['quiet_to'] == '07:00:00';
      }));
      await scrollTo(find.text('Hell ab'));
      await c.snap();

      c.clearMessages();
      c.step('Uhrzeit: Abbrechen', 'Auf Dunkel ab tippen, dann Abbrechen.', 'Die Uhr schließt sich, es bleibt 22:00.',
          kind: 'Abzweigung', explain: 'Nichts ändert sich.');
      await c.tap('Dunkel ab');
      c.screen('Uhrzeit wählen');
      await c.waitFor('Abbrechen', seconds: 3);
      await c.snap();
      await c.tap('Abbrechen');
      c.screen('Wiedergabe');
      await c.check('Server: noch 22 Uhr', () async => (await frameRow())['quiet_from'] == '22:00:00');

      c.clearMessages();
      c.step('Uhrzeit: daneben tippen', 'Auf Dunkel ab tippen, dann oben neben die Uhr.', 'Die Uhr schließt sich, es bleibt 22:00.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await c.tap('Dunkel ab');
      c.screen('Uhrzeit wählen');
      await c.waitFor('Abbrechen', seconds: 3);
      await c.tapAt(const Offset(200, 30), 'Schließen');
      c.screen('Wiedergabe');
      await c.check('Uhr zu', () => c.gone('Abbrechen', seconds: 3));
      await c.check('Server: noch 22 Uhr', () async => (await frameRow())['quiet_from'] == '22:00:00');
      await c.snap();

      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final darkFrom = '${two(now.hour)}:00';
      final lightFrom = '${two((now.hour + 2) % 24)}:00';

      /// Sets a time in the clock dialog by typing it (the keyboard symbol).
      Future<void> pickTime(String row, String hhmm) async {
        await c.tap(row);
        c.screen('Uhrzeit wählen');
        await tester.tap(find.byIcon(Icons.keyboard_outlined), warnIfMissed: false);
        c.logTap('Texteingabe');
        await c.settle();
        final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
        await tester.enterText(fields.at(0), hhmm.substring(0, 2));
        await tester.enterText(fields.at(1), hhmm.substring(3));
        c.logTap('Eingabefeld');
        await c.settle();
        await c.tap('OK');
        c.screen('Wiedergabe');
      }

      c.clearMessages();
      c.step('Nachtruhe jetzt', 'Dunkel ab auf die volle Stunde von jetzt stellen ($darkFrom), Hell ab zwei Stunden später ($lightFrom).',
          'Darunter $darkFrom bis $lightFrom; der Bildschirm des Frames wird dunkel.',
          explain: 'Zum Ausprobieren eine Nachtruhe, die gerade jetzt gilt. Die Uhrzeit tippt man über das Tastatur-Symbol ein.');
      await pickTime('Dunkel ab', darkFrom);
      await c.check('Server: dunkel ab $darkFrom', () => saved('quiet_from', '$darkFrom:00'));
      await pickTime('Hell ab', lightFrom);
      await c.check('Server: hell ab $lightFrom', () => saved('quiet_to', '$lightFrom:00'));
      await c.snap();
      await frameShows(6);

      c.clearMessages();
      c.step('Nachtruhe aus', 'Nachtruhe ausschalten.', 'Die Zeilen verschwinden; der Frame zeigt wieder Fotos.',
          explain: 'Ohne Nachtruhe läuft der Frame rund um die Uhr.');
      await flip('Nachtruhe');
      await c.check('Server: keine Nachtruhe', () => saved('quiet_from', null));
      await c.check('Zeilen weg', () => c.gone('Hell ab', seconds: 3));
      await c.snap();
      await frameShows(7);

      c.clearMessages();
      c.step('Wiedergabe: zurück zur Fernbedienung', 'Oben links zurück.', 'Bei Wiedergabe steht jetzt Ein Album · Der Reihe nach · 10 Sekunden.',
          explain: 'Die Kurzfassung der Einstellungen.');
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');
      await scrollTo(c.find_('Ein Album · Der Reihe nach · 10 Sekunden'));
      await c.check('Kurzfassung', () => c.waitFor('Ein Album · Der Reihe nach · 10 Sekunden', seconds: 5));
      await c.snap();

      // ================================================================ Das Menü der Fernbedienung
      c.clearMessages();
      c.step('Menü der Fernbedienung', 'Oben rechts auf die drei Punkte.',
          'Das Menü: Einstellungen & Gerät, Lieblingsbilder, Wiedergabe, Bedienung am Frame und Anderes Gerät verbinden.',
          explain: 'Dieselben Seiten wie weiter unten, schnell erreichbar.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await c.check('Menü', () => c.waitFor('Anderes Gerät verbinden', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Menü schließen', 'Links neben das Menü tippen.', 'Das Menü schließt sich.', kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tapAt(const Offset(40, 500), 'Menü schließen');
      c.screen('Fernbedienung');
      await c.check('Menü zu', () => c.gone('Anderes Gerät verbinden', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Menü: Lieblingsbilder', 'Wieder die drei Punkte, dann Lieblingsbilder.', 'Lieblingsbilder mit dem Strandfoto.',
          explain: 'Der kurze Weg zu den Lieblingsbildern.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await until(FrameFavoritesScreen, () => c.tap('Lieblingsbilder', last: true));
      c.screen('Lieblingsbilder');
      await c.check('Ein Foto', () => eventually(() => favoriteTiles().evaluate().length == 1, seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Alle entfernen: Frage', 'Oben rechts auf die drei Punkte, dann Alle entfernen.',
          'Alle Lieblingsbilder von Wohnzimmer entfernen?', explain: 'Alle auf einmal, nach einer Frage.');
      await menu();
      c.screen('Menü der Lieblingsbilder');
      await c.tap('Alle entfernen', last: true);
      c.screen('Alle Lieblingsbilder entfernen?');
      await c.check('Frage', () => c.waitFor('Alle Lieblingsbilder von Wohnzimmer entfernen?', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Alle entfernen: Abbrechen', 'Abbrechen antippen.', 'Die Frage schließt sich, das Strandfoto bleibt.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tap('Abbrechen');
      c.screen('Lieblingsbilder');
      await c.check('Server: noch eins', () async => (await favorites()).length == 1);
      await c.snap();

      c.clearMessages();
      c.step('Alle entfernen: daneben tippen', 'Drei Punkte, Alle entfernen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, das Strandfoto bleibt.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await menu();
      c.screen('Menü der Lieblingsbilder');
      await c.tap('Alle entfernen', last: true);
      c.screen('Alle Lieblingsbilder entfernen?');
      await c.waitFor('Alle Lieblingsbilder von Wohnzimmer entfernen?', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Lieblingsbilder');
      await c.check('Frage zu', () => c.gone('Alle Lieblingsbilder von', seconds: 3));
      await c.check('Server: noch eins', () async => (await favorites()).length == 1);
      await c.snap();

      c.clearMessages();
      c.step('Alle entfernen', 'Drei Punkte, Alle entfernen, dann Alle entfernen.', 'Zurück auf der Fernbedienung, bei Lieblingsbilder steht 0.',
          explain: 'Sind keine Lieblingsbilder mehr da, geht es von selbst zurück.');
      await menu();
      c.screen('Menü der Lieblingsbilder');
      await c.tap('Alle entfernen', last: true);
      c.screen('Alle Lieblingsbilder entfernen?');
      await c.waitFor('Alle Lieblingsbilder von Wohnzimmer entfernen?', seconds: 3);
      await c.tap('Alle entfernen', last: true);
      await c.check('Server: keine Lieblingsbilder', () => eventually(() async => (await favorites()).isEmpty));
      await c.check('Fernbedienung', () => eventually(() => find.byType(FrameFavoritesScreen).evaluate().isEmpty, seconds: 5));
      c.screen('Fernbedienung');
      await c.check('LIEBLINGSBILDER · 0', () => c.waitFor('LIEBLINGSBILDER · 0', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Menü: Wiedergabe', 'Drei Punkte, Wiedergabe, dann zurück.', 'Die Seite Wiedergabe, danach wieder die Fernbedienung.',
          kind: 'Abzweigung', explain: 'Derselbe Inhalt wie über die Zeile Wiedergabe.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await until(FramePlaybackScreen, () => c.tap('Wiedergabe', last: true));
      c.screen('Wiedergabe');
      await c.snap();
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');

      c.clearMessages();
      c.step('Menü: Bedienung am Frame', 'Drei Punkte, Bedienung am Frame, dann zurück.', 'Die Bedienstufen (Kapitel 7), danach wieder die Fernbedienung.',
          kind: 'Abzweigung', explain: 'Auch die Bedienstufen sind im Menü.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await until(FrameControlsScreen, () => c.tap('Bedienung am Frame', last: true));
      c.screen('Bedienung am Frame');
      await c.snap();
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');

      c.clearMessages();
      c.step('Menü: Anderes Gerät verbinden', 'Drei Punkte, Anderes Gerät verbinden.',
          'Wohnzimmer verbinden: QR-Code und Code, darunter wie ein neues Tablet diesen Frame übernimmt, und Fertig.',
          explain: 'Wenn das Tablet kaputt ist: ein neues Gerät übernimmt Alben, Einstellungen und Lieblingsbilder.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await until(CreateFrameScreen, () => c.tap('Anderes Gerät verbinden', last: true));
      c.screen('Frame-Code');
      final code = (await frameRow())['pairing_code'] as String;
      await c.check('Code ${code.substring(0, 4)} ${code.substring(4)}', () async =>
          await c.waitFor('~${code.substring(0, 4)}', seconds: 5));
      await c.check('Fertig', () => c.waitFor('Fertig', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Frame-Code: Fertig', 'Fertig antippen.', 'Wieder die Fernbedienung; nichts hat sich geändert.', kind: 'Abzweigung',
          explain: 'Ohne neues Gerät bleibt alles, wie es ist.');
      await c.tap('Fertig');
      c.screen('Fernbedienung');
      await c.check('Fernbedienung', () => eventually(() => find.byType(CreateFrameScreen).evaluate().isEmpty, seconds: 5));
      await c.check('Server: weiter aktiv', () async => (await frameRow())['lifecycle_state'] == 'active');
      await c.snap();

      c.clearMessages();
      c.step('Menü: Einstellungen & Gerät', 'Drei Punkte, Einstellungen & Gerät, dann zurück.',
          'Die Seite des Frames, danach wieder die Fernbedienung.', kind: 'Abzweigung', explain: 'Gleich mehr dazu.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await until(FrameSettingsScreen, () => c.tap('Einstellungen & Gerät', last: true));
      c.screen('Frame-Seite');
      await c.snap();
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');

      // ================================================================ Frame-Seite
      c.clearMessages();
      c.step('Alben verwalten', 'Ganz unten auf Alben verwalten.',
          'Die Seite von Wohnzimmer: Bild und Name, Frame in Familie Berger · Aktiv; Status mit Gerät, Zuletzt gesehen, App-Version und Akku; '
              'Einstellungen; Zeigt mit Sommerurlaub 2026 und Geburtstage (Läuft gerade).',
          explain: 'Wie bei Album und Space: alles über den Frame auf einer Seite.');
      await scrollTo(c.find_('Alben verwalten'));
      await until(FrameSettingsScreen, () => c.tap('Alben verwalten'));
      c.screen('Frame-Seite');
      await c.check('Status', () async =>
          await c.waitFor('Zuletzt gesehen', seconds: 8) && await c.waitFor('App-Version', seconds: 1) && await c.waitFor('Akku', seconds: 1));
      await c.check('Frame in Familie Berger · Aktiv', () => c.waitFor('Frame in Familie Berger · Aktiv', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Ton auf der Frame-Seite', 'Videos mit Ton aus- und wieder einschalten.', 'Am Ende an wie vorher.',
          explain: 'Derselbe Schalter wie auf der Fernbedienung.');
      await flip('Videos mit Ton');
      await c.check('Server: Ton aus', () => saved('video_sound', false));
      await flip('Videos mit Ton');
      await c.check('Server: Ton an', () => saved('video_sound', true));
      await c.snap();

      c.clearMessages();
      c.step('Album-Wechsel erlauben', 'Album-Wechsel erlauben aus- und wieder einschalten.', 'Am Ende an wie vorher.',
          explain: 'Ob man am Frame selbst das Album wechseln darf (dasselbe wie der Schalter Album wechseln bei den Bedienstufen).');
      final albumSwitch = (await frameRow())['channel_switch_enabled'] as bool;
      await flip('Album-Wechsel erlauben');
      await c.check('Server: umgestellt', () => saved('channel_switch_enabled', !albumSwitch));
      await flip('Album-Wechsel erlauben');
      await c.check('Server: wie vorher', () => saved('channel_switch_enabled', albumSwitch));
      await c.snap();

      Future<void> albumRow(String name) async {
        final row = find.widgetWithText(SmileObjectTile, name);
        await scrollTo(row);
        // Again if the sheet did not open (a rebuilding page may swallow a tap).
        for (var i = 0; i < 3 && c.find_('Album öffnen').evaluate().isEmpty; i++) {
          await tester.tap(row, warnIfMissed: false);
          await c.settle();
          await c.waitFor('Album öffnen', seconds: 2);
        }
        c.logTap(name);
        c.screen('Album auf dem Frame');
      }

      c.clearMessages();
      c.step('Album auf dem Frame', 'Bei Zeigt auf Sommerurlaub 2026 tippen.',
          'Unten öffnet sich: Jetzt zeigen, Album öffnen und Vom Frame entfernen.',
          explain: 'Jedes Album des Frames hat diese drei Möglichkeiten.');
      await albumRow('Sommerurlaub 2026');
      await c.check('Jetzt zeigen', () => c.waitFor('Jetzt zeigen', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Jetzt zeigen', 'Jetzt zeigen antippen.',
          'Unten kurz Wohnzimmer zeigt jetzt Sommerurlaub 2026; bei Sommerurlaub 2026 steht Läuft gerade. Der Frame zeigt es.',
          explain: 'Wie ein Tipp auf das Album in der Fernbedienung.');
      await c.tap('Jetzt zeigen');
      c.screen('Frame-Seite');
      await c.check('Meldung', () => c.waitFor('Wohnzimmer zeigt jetzt Sommerurlaub 2026', seconds: 3));
      await c.check('Server: Sommerurlaub', () => saved('current_channel_id', summer));
      await c.snap();
      await frameShows(8);

      c.clearMessages();
      c.step('Album, das gerade läuft', 'Noch einmal auf Sommerurlaub 2026 tippen.', 'Nur noch Album öffnen und Vom Frame entfernen.',
          kind: 'Abzweigung', explain: 'Was schon läuft, muss man nicht zeigen.');
      await c.gone('zeigt jetzt', seconds: 6);
      await albumRow('Sommerurlaub 2026');
      await c.check('Kein Jetzt zeigen', () async => await c.waitFor('Album öffnen', seconds: 3) && await c.gone('Jetzt zeigen', seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Frame-Seite');
      await c.check('Zu', () => c.gone('Album öffnen', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Album öffnen', 'Auf Geburtstage tippen, dann Album öffnen.', 'Das Album Geburtstage.',
          explain: 'Direkt zu den Fotos.');
      await albumRow('Geburtstage');
      await until(ChannelFeedScreen, () => c.tap('Album öffnen'));
      c.screen('Album');
      await c.check('Diashow', () => c.waitFor('Diashow', seconds: 8));
      await c.snap();
      await backTo(FrameSettingsScreen);
      c.screen('Frame-Seite');

      c.clearMessages();
      c.step('Vom Frame entfernen: Frage', 'Auf Sommerurlaub 2026 tippen, dann Vom Frame entfernen.',
          'Sommerurlaub 2026 vom Frame entfernen? mit Abbrechen und Entfernen.', explain: 'Smile fragt vorher.');
      await albumRow('Sommerurlaub 2026');
      await c.tap('Vom Frame entfernen');
      c.screen('Vom Frame entfernen?');
      await c.check('Frage', () => c.waitFor('Sommerurlaub 2026 vom Frame entfernen?', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Vom Frame entfernen: Abbrechen', 'Abbrechen antippen.', 'Sommerurlaub 2026 bleibt auf dem Frame.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tap('Abbrechen');
      c.screen('Frame-Seite');
      await c.check('Server: noch zwei Alben', () async => (await assigned()).length == 2);
      await c.snap();

      c.clearMessages();
      c.step('Vom Frame entfernen: daneben tippen', 'Sommerurlaub 2026, Vom Frame entfernen, dann oben neben die Frage tippen.',
          'Die Frage schließt sich, Sommerurlaub 2026 bleibt.', kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await albumRow('Sommerurlaub 2026');
      await c.tap('Vom Frame entfernen');
      c.screen('Vom Frame entfernen?');
      await c.waitFor('Sommerurlaub 2026 vom Frame entfernen?', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Frame-Seite');
      await c.check('Frage zu', () => c.gone('Sommerurlaub 2026 vom Frame entfernen?', seconds: 3));
      await c.check('Server: noch zwei Alben', () async => (await assigned()).length == 2);
      await c.snap();

      c.clearMessages();
      c.step('Vom Frame entfernen', 'Wieder Sommerurlaub 2026, Vom Frame entfernen, dann Entfernen.',
          'Bei Zeigt steht nur noch Geburtstage (Läuft gerade); der Frame zeigt wieder Geburtstage.',
          explain: 'Das Album selbst bleibt, nur der Frame zeigt es nicht mehr.');
      await albumRow('Sommerurlaub 2026');
      await c.tap('Vom Frame entfernen');
      c.screen('Vom Frame entfernen?');
      await c.tap('Entfernen', last: true);
      c.screen('Frame-Seite');
      await c.check('Server: nur Geburtstage', () => eventually(() async {
        final a = await assigned();
        return a.length == 1 && a.first == birthdays;
      }));
      await c.check('Sommerurlaub weg', () => c.gone('Sommerurlaub 2026', seconds: 5));
      await c.snap();
      await frameShows(9);

      Future<void> addAlbum() async {
        await scrollTo(c.find_('Album hinzufügen'));
        await c.tap('Album hinzufügen');
        c.screen('Album hinzufügen');
      }

      c.clearMessages();
      c.step('Album hinzufügen', 'Auf Album hinzufügen tippen.', 'Album hinzufügen mit Sommerurlaub 2026 und Weihnachten.',
          explain: 'Zur Auswahl stehen die Alben des Space, die der Frame noch nicht zeigt.');
      await addAlbum();
      await c.check('Zwei Alben', () async => await c.waitFor('Weihnachten', seconds: 5) && await c.waitFor('Sommerurlaub 2026', seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Album hinzufügen: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich, kein Album dazu.',
          kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tapAt(const Offset(30, 80), 'Schließen');
      c.screen('Frame-Seite');
      await c.check('Server: ein Album', () async => (await assigned()).length == 1);
      await c.snap();

      c.clearMessages();
      c.step('Weihnachten dazu', 'Album hinzufügen, dann Weihnachten.', 'Bei Zeigt stehen Geburtstage und Weihnachten.',
          explain: 'Der Frame zeigt es ab sofort mit.');
      await addAlbum();
      await tapExact('Weihnachten');
      c.screen('Frame-Seite');
      await c.check('Server: Weihnachten dazu', () => eventually(() async => (await assigned()).contains(seed.albums['Weihnachten'])));
      await c.snap();

      c.clearMessages();
      c.step('Sommerurlaub wieder dazu', 'Album hinzufügen, dann Sommerurlaub 2026.', 'Bei Zeigt stehen alle drei Alben.',
          explain: 'Jetzt zeigt der Frame alle Alben von Familie Berger.');
      await addAlbum();
      await tapExact('Sommerurlaub 2026');
      c.screen('Frame-Seite');
      await c.check('Server: drei Alben', () => eventually(() async => (await assigned()).length == 3));
      await c.snap();

      c.clearMessages();
      c.step('Keine weiteren Alben', 'Noch einmal Album hinzufügen.',
          'Es gibt keine weiteren Alben, die dieser Space sehen kann. mit Schließen.', kind: 'Abzweigung',
          explain: 'Alle Alben sind schon auf dem Frame.');
      await addAlbum();
      await c.check('Hinweis', () => c.waitFor('Es gibt keine weiteren Alben', seconds: 5));
      await c.snap();
      await c.tap('Schließen', last: true);
      c.screen('Frame-Seite');
      await c.check('Hinweis zu', () => c.gone('Es gibt keine weiteren Alben', seconds: 3));

      c.clearMessages();
      c.step('Weihnachten wieder weg', 'Weihnachten, Vom Frame entfernen, Entfernen.', 'Bei Zeigt stehen Sommerurlaub 2026 und Geburtstage.',
          kind: 'Abzweigung', explain: 'Wie zu Beginn.');
      await albumRow('Weihnachten');
      await c.tap('Vom Frame entfernen');
      c.screen('Vom Frame entfernen?');
      await c.tap('Entfernen', last: true);
      c.screen('Frame-Seite');
      await c.check('Server: zwei Alben', () => eventually(() async => (await assigned()).length == 2));
      await c.snap();

      // ---------------------------------------------------------------- Name und Bild
      // All the way up: the picture sits above the name.
      Future<void> toTop() async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await c.settle();
      }

      await toTop();
      c.clearMessages();
      c.step('Umbenennen', 'Oben auf den Namen tippen, Stube eingeben, Speichern.', 'Oben steht Stube.',
          explain: 'Den Namen sieht man überall, wo der Frame vorkommt.');
      await c.tap('Frame umbenennen');
      c.screen('Frame umbenennen');
      await c.typeInto('', 'Stube');
      await c.tap('Speichern');
      c.screen('Frame-Seite');
      await c.check('Server: Stube', () => saved('name', 'Stube'));
      await c.check('Stube', () => c.waitFor('Stube', seconds: 3));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Umbenennen: Abbrechen', 'Auf den Namen tippen, Abbrechen.', 'Es bleibt Stube.', kind: 'Abzweigung',
          explain: 'Nichts ändert sich.');
      await c.tap('Frame umbenennen');
      c.screen('Frame umbenennen');
      await c.tap('Abbrechen');
      c.screen('Frame-Seite');
      await c.check('Server: weiter Stube', () async => (await frameRow())['name'] == 'Stube');
      await c.snap();

      c.clearMessages();
      c.step('Wieder Wohnzimmer', 'Auf den Namen tippen, Wohnzimmer eingeben, Speichern.', 'Oben steht wieder Wohnzimmer.',
          explain: 'Zurück zum alten Namen.');
      await c.tap('Frame umbenennen');
      c.screen('Frame umbenennen');
      await c.typeInto('', 'Wohnzimmer');
      await c.tap('Speichern');
      c.screen('Frame-Seite');
      await c.check('Server: Wohnzimmer', () => saved('name', 'Wohnzimmer'));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Bild des Frames', 'Auf das runde Bild tippen.',
          'Unten öffnet sich Bild für Wohnzimmer mit Foto aufnehmen, Vorhandenes Bild wählen und Von einer Internetadresse laden.',
          explain: 'Ein Frame hat ein Bild wie ein Album oder Space.');
      await toTop();
      await c.tap('Bild ändern');
      c.screen('Bild für den Frame');
      await c.check('Bild für Wohnzimmer', () => c.waitFor('Bild für Wohnzimmer', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Bild-Auswahl: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt die Auswahl.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Frame-Seite');
      await c.check('Auswahl zu', () => c.gone('Bild für Wohnzimmer', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Bild wählen', 'Wieder auf das Bild, Vorhandenes Bild wählen, dann Leuchtturm.', 'Der Leuchtturm steht im Kreis oben.',
          explain: '(In der Test-App: gezeichnete Testbilder statt der Galerie.)');
      await toTop();
      await c.tap('Bild ändern');
      c.screen('Bild für den Frame');
      await c.tap('Vorhandenes Bild');
      c.screen('Bildauswahl');
      await c.tap('Leuchtturm', seconds: 10);
      c.screen('Frame-Seite');
      await c.gone('Testbilder', seconds: 10);
      await c.check('Server: Bild', () => eventually(() async => (await frameRow())['avatar_path'] != null, seconds: 15));
      await c.snap();

      Future<bool> newPicture(Object? before) =>
          eventually(() async => (await frameRow())['avatar_path'] != null && (await frameRow())['avatar_path'] != before, seconds: 15);

      c.clearMessages();
      c.step('Bild aufnehmen', 'Auf das Bild tippen, Foto aufnehmen, dann Haus mit Garten.', 'Das Haus steht im Kreis oben.',
          kind: 'Abzweigung', explain: 'Normalerweise öffnet sich die Kamera. Die Test-App zeigt stattdessen ihre Testbilder.');
      var before = (await frameRow())['avatar_path'];
      await toTop();
      await c.tap('Bild ändern');
      c.screen('Bild für den Frame');
      await c.tap('Foto aufnehmen');
      c.screen('Bildauswahl');
      await c.tap('Haus mit Garten', seconds: 10);
      c.screen('Frame-Seite');
      await c.gone('Testbilder', seconds: 10);
      await c.check('Server: neues Bild', () => newPicture(before));
      await c.snap();

      final media = '${(await getApplicationSupportDirectory()).path}/fixtures/media';
      final mountainsUrl = await TestBackend.putPublic(
          'testsuite/berge_am_abend.jpg', await File('$media/27_berge_am_abend.jpg').readAsBytes(), 'image/jpeg');
      c.clearMessages();
      c.step('Bild von einer Internetadresse', 'Auf das Bild tippen, Von einer Internetadresse laden, die Adresse eines Bildes (Berge am Abend) eingeben, Laden.',
          'Das Fenster lädt das Bild und schließt sich; im Kreis stehen die Berge am Abend.', kind: 'Abzweigung',
          explain: 'Wie beim Space in Kapitel 2.');
      before = (await frameRow())['avatar_path'];
      await toTop();
      await c.tap('Bild ändern');
      c.screen('Bild für den Frame');
      await c.tap('Von einer Internetadresse');
      c.screen('Bild-URL');
      await c.typeInto('https://', mountainsUrl);
      await c.tap('Laden', last: true);
      c.screen('Frame-Seite');
      await c.check('Fenster zu', () => c.gone('Bild-URL', seconds: 15));
      await c.check('Server: neues Bild', () => newPicture(before));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Bild entfernen', 'Auf das Bild tippen, Bild entfernen.', 'Wieder die Anfangsbuchstaben WO.', kind: 'Abzweigung',
          explain: 'Ohne Bild zeigt Smile die Anfangsbuchstaben.');
      await toTop();
      await c.tap('Bild ändern');
      c.screen('Bild für den Frame');
      await c.tap('Bild entfernen', seconds: 3);
      c.screen('Frame-Seite');
      await c.check('Server: kein Bild', () => saved('avatar_path', null));
      await c.check('WO', () => c.waitFor('WO', seconds: 5));
      await c.snap();

      // ---------------------------------------------------------------- Gerät
      c.clearMessages();
      c.step('Anderes Gerät verbinden', 'Ganz unten Anderes Gerät verbinden, dann oben links zurück.',
          'Der Code von Wohnzimmer, danach wieder die Seite des Frames.', kind: 'Abzweigung',
          explain: 'Derselbe Weg wie über das Menü der Fernbedienung.');
      await scrollTo(c.find_('Anderes Gerät verbinden'));
      await until(CreateFrameScreen, () => c.tap('Anderes Gerät verbinden'));
      c.screen('Frame-Code');
      await c.check('Code', () => c.waitFor('~${code.substring(0, 4)}', seconds: 5));
      await c.snap();
      await tester.tap(find.byTooltip('Zurück').first, warnIfMissed: false);
      c.logTap('Zurück');
      await c.settle();
      c.screen('Frame-Seite');
      await c.check('Frame-Seite', () => eventually(() => find.byType(CreateFrameScreen).evaluate().isEmpty, seconds: 5));

      c.clearMessages();
      c.step('Widerrufen: Frage', 'Frame widerrufen antippen.',
          'Frame widerrufen? Der Frame verliert sofort jeden Zugriff und löscht seine Fotos.', explain: 'Zum Beispiel, wenn das Tablet verloren ging.');
      await scrollTo(c.find_('Frame widerrufen'));
      await c.tap('Frame widerrufen');
      c.screen('Frame widerrufen?');
      await c.check('Frage', () => c.waitFor('Der Frame verliert sofort jeden Zugriff', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Widerrufen: Abbrechen', 'Abbrechen antippen.', 'Der Frame bleibt aktiv.', kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tap('Abbrechen');
      c.screen('Frame-Seite');
      await c.check('Server: aktiv', () async => (await frameRow())['lifecycle_state'] == 'active');
      await c.snap();

      c.clearMessages();
      c.step('Widerrufen: daneben tippen', 'Frame widerrufen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, der Frame bleibt aktiv.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await c.tap('Frame widerrufen');
      c.screen('Frame widerrufen?');
      await c.waitFor('Der Frame verliert sofort jeden Zugriff', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Frame-Seite');
      await c.check('Frage zu', () => c.gone('Der Frame verliert sofort', seconds: 3));
      await c.check('Server: aktiv', () async => (await frameRow())['lifecycle_state'] == 'active');
      await c.snap();

      c.clearMessages();
      c.step('Widerrufen', 'Frame widerrufen, dann Widerrufen.',
          'Oben steht Widerrufen, unten Frame wieder aktivieren. Am Tablet steht: Dieser Frame wurde widerrufen.',
          explain: 'Der Frame zeigt nichts mehr, bis er wieder aktiviert wird.');
      await c.tap('Frame widerrufen');
      c.screen('Frame widerrufen?');
      await c.tap('Widerrufen', last: true);
      c.screen('Frame-Seite');
      await c.check('Server: widerrufen', () => saved('lifecycle_state', 'revoked'));
      await scrollTo(c.find_('Frame wieder aktivieren'));
      await c.check('Frame wieder aktivieren', () => c.waitFor('Frame wieder aktivieren', seconds: 5));
      await c.check('Kein Anderes Gerät verbinden', () => c.gone('Anderes Gerät verbinden', seconds: 1));
      await c.snap();
      await frameShows(10);

      c.clearMessages();
      c.step('Wieder aktivieren', 'Frame wieder aktivieren antippen.',
          'Wieder Aktiv und Frame widerrufen. Das Tablet lädt die Fotos neu und zeigt wieder die Diashow.',
          explain: 'Ohne neues Koppeln: der Frame macht einfach weiter.');
      await c.tap('Frame wieder aktivieren');
      await c.check('Server: aktiv', () => saved('lifecycle_state', 'active'));
      await c.check('Frame widerrufen', () => c.waitFor('Frame widerrufen', seconds: 5));
      await c.snap();
      await frameShows(11);

      c.clearMessages();
      c.step('Löschen: Frage', 'Frame löschen antippen.',
          'Frame Wohnzimmer löschen? Der Frame wird endgültig entfernt, das Tablet zeigt wieder den Bildschirm zum Verbinden.',
          explain: 'Endgültig löschen gehört zum Aufräumen (Kapitel 12). Hier nur die Frage.');
      await scrollTo(c.find_('Frame löschen'));
      await c.tap('Frame löschen');
      c.screen('Frame löschen?');
      await c.check('Frage', () => c.waitFor('Frame Wohnzimmer löschen?', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Löschen: Abbrechen', 'Abbrechen antippen.', 'Der Frame bleibt.', kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tap('Abbrechen');
      c.screen('Frame-Seite');
      await c.check('Server: Frame da', () async => (await frameRow())['lifecycle_state'] == 'active');
      await c.snap();

      c.clearMessages();
      c.step('Löschen: daneben tippen', 'Frame löschen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, der Frame bleibt.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await c.tap('Frame löschen');
      c.screen('Frame löschen?');
      await c.waitFor('Frame Wohnzimmer löschen?', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Frame-Seite');
      await c.check('Frage zu', () => c.gone('Frame Wohnzimmer löschen?', seconds: 3));
      await c.check('Server: Frame da', () async => (await frameRow())['lifecycle_state'] == 'active');
      await c.snap();

      // ================================================================ Oma Hilde stellt selbst ein
      c.clearMessages();
      c.step('Alles selbst', 'Zurück zur Fernbedienung, auf die Kachel Bedienstufe, dann Alles selbst.',
          'Alles selbst ist gewählt. Oma Hilde stellt jetzt am Tablet selbst die Wiedergabe ein.',
          explain: 'Ab Stufe 5 gibt es am Frame den Knopf Einstellungen mit derselben Wiedergabe wie in der App.');
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');
      await scrollTo(c.find_('Bedienstufe'));
      await until(FrameControlsScreen, () => c.tap('Bedienstufe'));
      c.screen('Bedienung am Frame');
      await tapExact('Alles selbst');
      await c.check('Server: Stufe 5', () => saved('control_level', 5));
      await c.snap();
      await frameShows(12);

      c.clearMessages();
      c.step('Wieder nur zuschauen', 'Nur zuschauen antippen.', 'Nur zuschauen ist wieder gewählt.',
          explain: 'Wie zu Beginn des Kapitels.');
      await tester.scrollUntilVisible(find.text('Nur zuschauen'), -300, scrollable: find.byType(Scrollable).first);
      await tapExact('Nur zuschauen');
      await c.check('Server: Stufe 1', () => saved('control_level', 1));
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 35)));
}
