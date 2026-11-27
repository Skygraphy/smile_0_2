// Kapitel 13: Frame im Alltag (tools/testsuite, 2026-11-25), Teil am Handy.
// Der Teil am Tablet läuft gleichzeitig (ch13f_test.dart), mit Signalen wie
// in Kapitel 7 und 8 (pN vom Handy, fN vom Tablet).
// Startet wie Kapitel 8: das Tablet ist der Frame Wohnzimmer (Nur
// zuschauen) mit Sommerurlaub 2026 und Geburtstage, es läuft Geburtstage.
// Neu seit 0.0.17: Antippen hält an, Hinweis und Ton bei neuen Fotos, kein
// Hinweis beim ersten Laden, Heute vor einem Jahr, Kindersperre, Live
// ansehen, Bild des Frames, Frame neu verbinden.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/create_frame_screen.dart';
import 'package:smile_app/screens/frame_controls_screen.dart';
import 'package:smile_app/screens/frame_live_screen.dart';
import 'package:smile_app/screens/frame_playback_screen.dart';
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frames_screen.dart';
import 'package:smile_app/services/frame_controls.dart';
import 'package:smile_app/services/frame_service.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 13: Frame im Alltag', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch13',
        title: 'Frame im Alltag',
        intro: 'Was am Frame seit Version 0.0.17 dazugekommen ist: Antippen hält ihn an, neue Fotos melden sich mit Hinweis und Ton, '
            'Heute vor einem Jahr, die Kindersperre mit Code, Live ansehen, ein Bild für den Frame und Frame neu verbinden, '
            'wenn er offline ist. Schritte am Tablet sind mit Am Tablet gekennzeichnet.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (wie Kapitel 8)
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
      final lena = await TestUser.signIn(lenaMail);
      final media = '${(await getApplicationSupportDirectory()).path}/fixtures/media';
      Future<Uint8List> photo(String file) => File('$media/$file').readAsBytes();
      // The tablet claims the code by itself (ch13f) and says when it shows the photos.
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

      Future<void> backTo(Type page) async {
        for (var i = 0; i < 4 && find.byType(page).evaluate().isEmpty; i++) {
          await c.back();
        }
      }

      /// The tablet takes its picture of what this step did, then this goes on.
      Future<void> frameShows(int n) async {
        await TestBackend.signal('p$n');
        await c.awaitSignal('f$n', seconds: 900);
      }

      Future<void> scrollTo(Finder f, {double by = 300}) async {
        await tester.scrollUntilVisible(f, by, scrollable: find.byType(Scrollable).first);
        await c.settle();
      }

      /// A switch row by its title (scrolled into sight first).
      Future<void> flip(String title) async {
        final tile = find.widgetWithText(SwitchListTile, title);
        await scrollTo(tile);
        await tester.tap(tile, warnIfMissed: false);
        c.logTap(title);
        await c.settle();
      }

      bool switchOn(String title) => tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title)).value;

      Future<void> menu() async {
        await tester.tap(find.byTooltip('Weitere Optionen').last, warnIfMissed: false);
        c.logTap('Weitere Optionen');
        await c.settle();
      }

      Future<void> typeCode(String code) async {
        await tester.enterText(find.byType(TextField).last, code);
        c.logTap('Eingabefeld: Code');
        await c.settle();
        await tester.tap(find.text('OK').last, warnIfMissed: false);
        c.logTap('OK');
        await c.settle();
      }

      await c.waitFor('Wanderungen', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Ausgangslage
      c.step('Ausgangslage', 'Unten Frames, dann Wohnzimmer.',
          'Die Fernbedienung von Wohnzimmer: Online, Geburtstage läuft.',
          explain: 'Wie am Ende von Kapitel 8: das Tablet ist der Frame Wohnzimmer, Oma Hilde schaut nur zu (Nur zuschauen).');
      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await until(FrameRemoteScreen, () => tapExact('Wohnzimmer'));
      c.screen('Fernbedienung');
      await c.check('Fernbedienung', () => c.waitFor('Neueste 20 Fotos abspielen', seconds: 8));
      await c.snap();
      await frameShows(1);

      // ================================================================ Antippen hält an
      c.clearMessages();
      c.step('Antippen hält an: aus', 'Bedienung am Frame öffnen und ganz oben den Schalter Antippen hält an ausschalten.',
          'Der Schalter ist aus, darunter ist jetzt Eigene Auswahl gewählt.',
          explain: 'Antippen hält an gehört zu jeder Bedienstufe. Ausgeschaltet weicht der Frame von Nur zuschauen ab, darum Eigene Auswahl.');
      await scrollTo(find.text('Bedienung am Frame'));
      await until(FrameControlsScreen, () => tapExact('Bedienung am Frame'));
      c.screen('Bedienung am Frame');
      await flip('Antippen hält an');
      await c.check('Server: Antippen hält an aus', () => saved('easy_stop', false));
      await c.check('Server: Eigene Auswahl', () => saved('control_level', null));
      await c.check('Schalter aus', () => !switchOn('Antippen hält an'));
      await c.snap();
      await frameShows(2);

      c.clearMessages();
      c.step('Antippen hält an: wieder ein', 'Den Schalter Antippen hält an wieder einschalten.', 'Der Schalter ist an, oben wieder Nur zuschauen.',
          explain: 'Alles wieder wie in Nur zuschauen.');
      await flip('Antippen hält an');
      await c.check('Server: Antippen hält an an', () => saved('easy_stop', true));
      await c.check('Server: wieder Stufe 1', () => saved('control_level', 1));
      await c.snap();
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');

      // ================================================================ Neue Fotos
      c.clearMessages();
      c.step('Lena schickt zwei Fotos', 'Lena schickt zwei Fotos in Geburtstage.',
          'Am Handy ändert sich hier nichts; der Frame bekommt sie sofort.',
          explain: 'Neue Fotos kommen per Push zum Frame. Dort melden sie sich mit einem Ton und einem Hinweis, bis jemand hinschaut.');
      await lena.sendPhotos(birthdays, [await photo('17_heissluftballon.jpg'), await photo('19_kaffee.jpg')]);
      await c.snap();
      await frameShows(3);

      c.clearMessages();
      c.step('Hinweis auf Neues ausschalten', 'Wiedergabe öffnen und Hinweis auf Neues ausschalten. Dann schickt Lena noch ein Foto.',
          'Der Schalter ist aus.',
          explain: 'Ohne Hinweis kommen neue Fotos still dazu; der Ton bleibt ein eigener Schalter.');
      await scrollTo(find.text('Wiedergabe'), by: -300);
      await until(FramePlaybackScreen, () => tapExact('Wiedergabe', first: true));
      c.screen('Wiedergabe');
      await flip('Hinweis auf Neues');
      await c.check('Server: Hinweis aus', () => saved('new_hint', false));
      await lena.sendPhotos(birthdays, [await photo('18_fahrrad.jpg')]);
      await c.snap();
      await frameShows(4);

      c.clearMessages();
      c.step('Hinweis, Ton und Zoom', 'Hinweis auf Neues wieder ein; Ton bei neuen Fotos, Erinnern, bis jemand schaut und Beim Anhalten weiter zoomen je aus und wieder ein.',
          'Alle vier Schalter sind am Ende an.', kind: 'Abzweigung',
          explain: 'Der Ton kommt einmal, wenn etwas Neues ankommt; Erinnern wiederholt ihn stündlich, höchstens dreimal. '
              'Beim Anhalten weiter zoomen: ein angehaltenes Foto zoomt langsam weiter.');
      await flip('Hinweis auf Neues');
      await c.check('Server: Hinweis an', () => saved('new_hint', true));
      for (final (title, column) in const [
        ('Ton bei neuen Fotos', 'new_sound'),
        ('Erinnern, bis jemand schaut', 'new_sound_reminder'),
        ('Beim Anhalten weiter zoomen', 'pause_zoom'),
      ]) {
        await flip(title);
        await c.check('Server: $title aus', () => saved(column, false));
        await flip(title);
        await c.check('Server: $title an', () => saved(column, true));
      }
      await c.snap();

      // ================================================================ Heute vor einem Jahr
      c.clearMessages();
      c.step('Ein Foto von heute vor einem Jahr', 'Lena schickt ein Foto, das heute vor einem Jahr aufgenommen wurde.',
          'Bei Wiedergabe ist Heute vor einem Jahr an; darunter steht, dass solche Fotos heute als jedes 10. Bild dazwischen kommen.',
          explain: 'Smile schickt das Aufnahmedatum mit. Am Jahrestag kommt das Foto am Frame immer wieder dazwischen, mit einem Hinweis unten links.');
      await scrollTo(find.text('Heute vor einem Jahr'));
      await c.check('Schalter an', () => switchOn('Heute vor einem Jahr'));
      await c.check('Hinweis: jedes 10. Bild', () => c.waitFor('~jedes 10. Bild', seconds: 2));
      final now = DateTime.now();
      await lena.sendPhotos(birthdays, [await photo('13_sonnenuntergang.jpg')], takenAt: DateTime(now.year - 1, now.month, now.day, 12));
      await c.snap();
      await frameShows(5);

      c.clearMessages();
      c.step('Heute vor einem Jahr ausschalten', 'Heute vor einem Jahr ausschalten.', 'Der Schalter ist aus.', kind: 'Abzweigung',
          explain: 'Dann läuft das Foto wie jedes andere, ohne Hinweis.');
      await flip('Heute vor einem Jahr');
      await c.check('Server: aus', () => saved('on_this_day', false));
      await c.snap();
      await frameShows(6);
      await flip('Heute vor einem Jahr');
      await c.check('Server: wieder an', () => saved('on_this_day', true));
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');

      // ================================================================ Kindersperre
      c.clearMessages();
      c.step('Code festlegen', 'Nach unten zu Kindersperre, Code festlegen, 1234 eingeben, OK, noch einmal 1234, OK.',
          'Unten kurz Code gespeichert; dort steht jetzt Ein Code ist festgelegt, mit Code ändern und Code entfernen.',
          explain: 'Mit dem Code lässt sich am Frame alles freischalten, auch wenn Oma Hilde nur zuschaut. Die Testsuite prüft, dass am Server nur ein Hash liegt.');
      await scrollTo(find.text('Code festlegen'));
      await tapExact('Code festlegen');
      c.screen('Code festlegen');
      await c.check('Frage', () => c.waitFor('Code für Wohnzimmer', seconds: 3));
      await typeCode('1234');
      await c.check('Noch einmal', () => c.waitFor('Zur Bestätigung noch einmal', seconds: 3));
      await typeCode('1234');
      c.screen('Fernbedienung');
      await c.check('Meldung', () => c.waitFor('Code gespeichert', seconds: 5));
      await c.check('Server: Code als Hash', () async {
        final hash = (await frameRow())['unlock_code_hash'] as String?;
        return hash != null && hash != '1234' && hash.length >= 32;
      });
      await c.check('Code ist festgelegt', () => c.waitFor('Ein Code ist festgelegt.', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Code: verschieden', 'Code ändern, 1111 und dann 2222 eingeben.',
          'Unten: Die beiden Codes sind verschieden. Bitte noch einmal. Der alte Code bleibt.', kind: 'Abzweigung',
          explain: 'Zweimal eingeben schützt vor Tippfehlern.');
      final hash = (await frameRow())['unlock_code_hash'];
      await tapExact('Code ändern');
      c.screen('Code festlegen');
      await typeCode('1111');
      await typeCode('2222');
      c.screen('Fernbedienung');
      await c.check('Meldung', () => c.waitFor('Die beiden Codes sind verschieden. Bitte noch einmal.', seconds: 5));
      await c.check('Server: alter Code bleibt', () async => (await frameRow())['unlock_code_hash'] == hash);
      await c.snap();
      await frameShows(7);

      c.clearMessages();
      c.step('Code entfernen', 'Code entfernen, dann in der Frage Code entfernen.',
          'Unten kurz Code entfernt; wieder Noch kein Code und Code festlegen.',
          explain: 'Ohne Code lässt sich am Frame nichts mehr entsperren, wie vor dem ersten Code.');
      await scrollTo(find.text('Code entfernen'));
      await tapExact('Code entfernen');
      c.screen('Code entfernen?');
      await c.check('Frage', () => c.waitFor('Code entfernen?', seconds: 3));
      await tapExact('Code entfernen');
      c.screen('Fernbedienung');
      await c.check('Server: kein Code', () => saved('unlock_code_hash', null));
      await c.check('Code festlegen', () => c.waitFor('Code festlegen', seconds: 5));
      await c.snap();

      // ================================================================ Live ansehen
      c.clearMessages();
      c.step('Live ansehen', 'Nach oben, Live ansehen antippen.',
          'Wohnzimmer · Live: das Bild, das der Frame gerade zeigt, oben Live · vor ein paar Sekunden, darunter was gerade läuft.',
          explain: 'Admin und Co-Admin sehen, was der Frame zeigt: alle 1,5 Sekunden ein neues Bild. Der Frame zeigt dabei an, wer zuschaut.');
      await scrollTo(find.text('Live ansehen'), by: -300);
      await until(FrameLiveScreen, () => tapExact('Live ansehen'));
      c.screen('Live');
      await c.check('Bild vom Frame', () => c.waitFor('~Live · vor', seconds: 30));
      await c.check('Was läuft', () => c.waitFor('~Läuft · „Geburtstage“', seconds: 10));
      await c.snap();
      await frameShows(8);

      c.clearMessages();
      c.step('Live beenden', 'Oben links zurück.', 'Wieder die Fernbedienung.', explain: 'Zurück beendet das Zuschauen sofort.');
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');
      await c.check('Server: niemand schaut', () => eventually(() async =>
          (await TestBackend.select('frame_live', 'select=until&frame_id=eq.${created.id}'))
              .every((r) => DateTime.parse((r as Map)['until'] as String).isBefore(DateTime.now().add(const Duration(seconds: 5)))),
          seconds: 15));
      await c.snap();
      await frameShows(9);

      // ================================================================ Bild des Frames
      c.clearMessages();
      c.step('Bild für den Frame', 'Drei Punkte, Bild ändern, Vorhandenes Bild, dann Haus mit Garten.',
          'Oben auf der Fernbedienung steht jetzt das Haus statt der Anfangsbuchstaben.',
          explain: 'Ein Frame kann ein Bild haben wie Album und Space; es steht auch in der Liste der Frames.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await tapExact('Bild ändern');
      c.screen('Bild für den Frame');
      await c.tap('Vorhandenes Bild');
      c.screen('Bildauswahl');
      await c.tap('Haus mit Garten', seconds: 10);
      c.screen('Fernbedienung');
      await c.gone('Testbilder', seconds: 10);
      await c.check('Server: Bild gespeichert', () => eventually(() async => (await frameRow())['avatar_path'] != null, seconds: 15));
      await c.letLoad(seconds: 2);
      await c.snap();

      // ================================================================ Frame neu verbinden
      c.clearMessages();
      c.step('Frame online: anderes Gerät', 'Drei Punkte öffnen.',
          'Im Menü steht Anderes Gerät verbinden: Ein neues Tablet übernimmt diesen Frame.',
          explain: 'Läuft der Frame, geht es hier nur um ein anderes Tablet.');
      await menu();
      c.screen('Menü der Fernbedienung');
      await c.check('Anderes Gerät verbinden', () => c.waitFor('Anderes Gerät verbinden', seconds: 3));
      await c.snap();
      await tester.tapAt(const Offset(20, 300));
      c.logTap('Menü schließen');
      await c.settle();
      await frameShows(10);

      c.clearMessages();
      c.step('Frame offline: neu verbinden', 'Der Frame meldet sich eine Stunde lang nicht. Zurück, Wohnzimmer wieder öffnen, drei Punkte.',
          'Oben steht Offline; im Menü heißt es jetzt Frame neu verbinden, darunter: Zeigt das Tablet „Frame verbinden“? Oder kommt ein neues Tablet?',
          explain: 'Ist der Frame offline, passt die Anleitung für dasselbe oder ein neues Tablet. (Die Testsuite stellt das letzte Lebenszeichen des Frames eine Stunde zurück.)');
      await TestBackend.patch('frames', 'id=eq.${created.id}',
          {'last_seen_at': DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String()});
      await backTo(FramesScreen);
      c.screen('Frames');
      await until(FrameRemoteScreen, () => tapExact('Wohnzimmer'));
      c.screen('Fernbedienung');
      await c.letLoad(seconds: 2);
      await menu();
      c.screen('Menü der Fernbedienung');
      await c.check('Frame neu verbinden', () => c.waitFor('Frame neu verbinden', seconds: 5));
      await c.check('Für dasselbe oder ein neues Tablet', () => c.waitFor('~Oder kommt ein neues Tablet?', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Frame neu verbinden: QR-Code', 'Frame neu verbinden antippen.',
          'Oben Frame neu verbinden, darunter ein QR-Code und die Anleitung für das Tablet.',
          explain: 'Alben und Einstellungen bleiben. Ein anderes Tablet, das bisher dieser Frame war, ist danach keiner mehr.');
      await until(CreateFrameScreen, () => tapExact('Frame neu verbinden'));
      c.screen('Frame neu verbinden');
      await c.check('Titel', () => c.waitFor('Frame neu verbinden', seconds: 5));
      await c.letLoad(seconds: 2);
      await c.snap();
      await backTo(FrameRemoteScreen);
      c.screen('Fernbedienung');
      // The tablet stays this Frame: nothing was paired anew.
      await c.check('Server: weiter derselbe Frame', () async => (await frameRow())['lifecycle_state'] == 'active');

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
