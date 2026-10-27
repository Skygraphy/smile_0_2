// Kapitel 11: Tipps (tools/testsuite, 2026-10-27).
// Startet dort, wo Kapitel 5 endet, dazu der Frame Wohnzimmer (ohne Tablet:
// die Tipps zum Frame stehen in der App). In den Kapiteln davor waren die
// Tipps aus. Höchstens ein Tipp pro Tag: "am nächsten Tag" heißt hier, der
// Test vergisst den Tag des letzten Tipps (tips_last_day), wie über Nacht.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/album_info_screen.dart';
import 'package:smile_app/screens/album_slideshow_screen.dart';
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frames_screen.dart';
import 'package:smile_app/screens/news_screen.dart';
import 'package:smile_app/screens/photo_viewer_screen.dart';
import 'package:smile_app/screens/settings_screen.dart';
import 'package:smile_app/services/frame_controls.dart';
import 'package:smile_app/services/frame_service.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

const _videoQuality = 'Unter Videos senden wählst du, wie stark Videos verkleinert werden. Das spart Datenvolumen.';
const _smileName = 'Mit deinem Smile-Namen und deiner Karte findet dich jeder, der dich einladen möchte.';
const _quickCapture = 'Das Kamera-Symbol oben: Foto machen und gleich in ein Album schicken.';
const _newAlbum = 'Neue Alben legst du über ⋮ → Neues Album an.';
const _newsIcon = 'Wird das Symbol oben Coral, wartet eine Einladung oder Anfrage auf dich.';
const _frameButton = 'Ein Tipp auf das Frame-Symbol zeigt dieses Album sofort am Frame. Lang drücken öffnet die Fernbedienung.';
const _slideshow = 'Mit dem Diashow-Symbol läuft das Album als Diashow auf diesem Handy, mit eigenen Einstellungen.';
const _selectPhotos = 'Lang auf ein Foto drücken: mehrere auswählen, ausblenden oder löschen.';
const _captionLater = 'Hier kannst du nachträglich einen Titel setzen oder ändern.';
const _favoriteHeart = 'Mit dem Herz merkst du ein Foto als Lieblingsbild für den Frame.';
const _captionWhenSending = 'Jedes Foto kann einen eigenen Titel bekommen. Unten antippen oder wischen, um zum nächsten zu wechseln.';
const _inviteWays = 'Einladen geht auch ohne E-Mail: per QR-Code, Link oder aus den Kontakten.';
const _controlLevel = 'Mit der Bedienstufe legst du fest, was am Frame selbst bedient werden kann, von Nur zuschauen bis Alles selbst.';
const _playback = 'Unter Wiedergabe: Uhr, Nachtruhe, Titel, langsamer Zoom und Keine Videos.';
const _favoritesRound = 'Lieblingsbilder laufen am Frame als eigene Runde, auch über alle Alben.';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 11: Tipps', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch11',
        title: 'Tipps',
        intro: 'Ab und zu zeigt Smile einen kurzen Tipp: was man leicht übersieht, passend zur Seite. Höchstens einer am Tag, '
            'jeder nur einmal und nur, solange man die Sache noch nicht selbst benutzt hat. Anna schaltet die Tipps ein und '
            'bekommt sie Tag für Tag zu sehen.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 5 + Frame)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter5(tester);
      final birthdays = seed.albums['Geburtstage']!;
      final frames = FrameService();
      final frame = await frames.createFrame(spaceId: seed.spaceId, name: 'Wohnzimmer');
      await frames.updateSettings(frameId: frame.id, changes: FrameControlLevels.update(FrameControlLevels.preset(1)));
      await frames.assignChannel(frameId: frame.id, channelId: seed.albums['Sommerurlaub 2026']!);
      await frames.assignChannel(frameId: frame.id, channelId: birthdays);
      await frames.setRevoked(frameId: frame.id, revoked: false); // verbunden, wie nach Kapitel 6
      final fruit = (await TestBackend.select('media_items', 'select=id&channel_id=eq.$birthdays&caption=eq.Obst%20f%C3%BCr%20alle'))
          .first['id'] as String;
      final prefs = await SharedPreferences.getInstance();

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      /// Over night: the day of the last tip is forgotten.
      Future<void> nextDay() async => prefs.remove('tips_last_day');
      List<String> seen() => prefs.getStringList('tips_seen') ?? const [];
      bool tipOpen() => find.text('Verstanden').evaluate().isNotEmpty;

      /// Nothing shows for a while (longer than the quiet moment of 5 s).
      Future<bool> noTip({double seconds = 9}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (tipOpen()) return false;
        }
        return true;
      }

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

      Future<void> scrollTo(Finder f, {double by = 300}) async {
        await tester.scrollUntilVisible(f, by, scrollable: find.byType(Scrollable).first);
        await c.settle();
      }

      /// The tip [text] shows (after the quiet moment).
      Future<void> tip(String text) async {
        c.screen('Tipp');
        await c.check('Tipp erscheint', () => c.waitFor(text, seconds: 20));
        await c.check('Ganz zu lesen', () => c.fullyShown(text));
      }

      Future<void> understood(String id) async {
        await c.tap('Verstanden');
        await c.check('Tipp zu', () => c.gone('Verstanden', seconds: 3));
        await c.check('Gemerkt: kommt nicht wieder', () => seen().contains(id));
      }

      Future<void> openSettings() async {
        await c.tap('Weitere Optionen');
        c.screen('Menü');
        await until(SettingsScreen, () => c.tap('Einstellungen', last: true));
        c.screen('Einstellungen');
      }

      Future<void> openAlbum() async {
        await until(ChannelFeedScreen, () => c.tap('Geburtstage'));
        c.screen('Album');
        await c.settle(max: const Duration(seconds: 2));
      }

      Future<void> home() async {
        bool inside() => [ChannelFeedScreen, SettingsScreen, AlbumInfoScreen, PhotoViewerScreen, NewsScreen, FrameRemoteScreen]
            .any((page) => find.byType(page).evaluate().isNotEmpty);
        for (var i = 0; i < 6 && inside(); i++) {
          await c.back();
        }
        if (find.byType(FramesScreen).evaluate().isNotEmpty) await tapExact('Alben');
        c.screen('Startseite');
        await c.waitFor('Geburtstage', seconds: 10);
      }

      final switchTile = find.widgetWithText(SwitchListTile, 'Tipps anzeigen');
      bool switchOn() => tester.widget<SwitchListTile>(switchTile).value;

      await c.waitFor('Wanderungen', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Einschalten
      c.step('Ausgangslage', 'Oben rechts auf die drei Punkte, dann Einstellungen, nach unten bis Tipps.',
          'Bei Tipps: der Schalter Tipps anzeigen ist aus, darunter Tipps von vorne zeigen.',
          explain: 'In den Kapiteln davor waren die Tipps aus, damit sie nicht dazwischenfunken. Neu installiert ist der Schalter an.');
      await openSettings();
      await scrollTo(switchTile);
      await c.check('Schalter aus', () => !switchOn());
      await c.snap();

      c.clearMessages();
      c.step('Tipps einschalten', 'Den Schalter Tipps anzeigen antippen.', 'Der Schalter ist an.',
          explain: 'Ab jetzt zeigt Smile Tipps, wenn es passt.');
      await tester.tap(switchTile, warnIfMissed: false);
      c.logTap('Tipps anzeigen');
      await c.settle();
      await c.check('Schalter an', () => switchOn());
      await c.check('Gemerkt', () => prefs.getBool('tips_enabled') == true);
      await c.snap();

      c.clearMessages();
      c.step('Der erste Tipp', 'Ein paar Sekunden nichts tun.',
          'Unten erscheint eine Karte mit TIPP: Unter Videos senden wählst du, wie stark Videos verkleinert werden. '
              'Darunter Keine Tipps mehr und Verstanden.',
          explain: 'Ein Tipp kommt erst, wenn man einen Moment ruhig auf einer Seite ist. Den Tipp zum Smile-Namen gibt es hier '
              'nicht: Anna hat schon einen.');
      await tip(_videoQuality);
      await c.check('Kein Tipp zum Smile-Namen', () => c.gone(_smileName, seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Verstanden', 'Auf Verstanden tippen.', 'Die Karte verschwindet.',
          explain: 'Verstanden heißt: dieser Tipp kommt nie wieder.');
      await understood('videoQuality');
      await c.snap();

      c.clearMessages();
      c.step('Nur ein Tipp am Tag', 'Zweimal zurück zur Startseite und dort eine Weile warten.',
          'Die Startseite, kein weiterer Tipp.',
          explain: 'Höchstens ein Tipp am Tag, damit Smile nicht nervt.');
      await home();
      await c.check('Kein Tipp', () => noTip());
      await c.snap();

      // ================================================================ Startseite
      c.clearMessages();
      c.step('Am nächsten Tag: Kamera', 'Am nächsten Tag die Startseite öffnen.',
          'Eine Sprechblase zeigt auf die Kamera oben: Das Kamera-Symbol oben: Foto machen und gleich in ein Album schicken. '
              'Die Kamera leuchtet korallfarben.',
          explain: 'Zeigt ein Tipp auf einen Knopf, kommt er als Sprechblase direkt darunter.');
      await nextDay();
      await tip(_quickCapture);
      await c.snap();

      c.clearMessages();
      c.step('Tipp: daneben tippen', 'Neben die Sprechblase tippen.', 'Die Sprechblase verschwindet.', kind: 'Abzweigung',
          explain: 'Daneben tippen heißt: jetzt nicht. Der Tipp kommt an einem anderen Tag wieder.');
      await c.tapAt(const Offset(200, 600), 'Schließen');
      c.screen('Startseite');
      await c.check('Zu', () => c.gone(_quickCapture, seconds: 3));
      await c.check('Nicht gemerkt', () => !seen().contains('quickCapture'));
      await c.snap();

      c.clearMessages();
      c.step('Er kommt wieder', 'Am nächsten Tag wieder die Startseite, dann Verstanden.',
          'Zuerst dieselbe Sprechblase an der Kamera; nach Verstanden ist sie weg.', kind: 'Abzweigung',
          explain: 'Erst Verstanden macht ihn für immer erledigt.');
      await nextDay();
      await tip(_quickCapture);
      await understood('quickCapture');
      c.screen('Startseite');
      await c.snap();

      c.clearMessages();
      c.step('Am nächsten Tag: Neues Album', 'Am nächsten Tag die Startseite.',
          'Die Sprechblase zeigt auf die drei Punkte: Neue Alben legst du über ⋮ → Neues Album an.',
          explain: 'Diesen Tipp bekommt nur, wer einen Space verwaltet und damit Alben anlegen darf.');
      await nextDay();
      await tip(_newAlbum);
      await c.snap();
      await understood('newAlbum');

      c.clearMessages();
      c.step('Am nächsten Tag: Neuigkeiten', 'Am nächsten Tag die Startseite.',
          'Die Sprechblase zeigt auf das Symbol der Neuigkeiten: Wird das Symbol oben Coral, wartet eine Einladung oder Anfrage auf dich.',
          explain: 'Der dritte Tipp der Startseite.');
      c.screen('Startseite');
      await nextDay();
      await tip(_newsIcon);
      await c.snap();

      c.clearMessages();
      c.step('Selbst ausprobiert', 'Neben die Sprechblase tippen, dann Neuigkeiten öffnen und wieder zurück.',
          'Neuigkeiten geht auf und wieder zu.', kind: 'Abzweigung',
          explain: 'Wer Neuigkeiten selbst geöffnet hat, braucht den Tipp nicht mehr.');
      await c.tapAt(const Offset(200, 600), 'Schließen');
      c.screen('Startseite');
      await until(NewsScreen, () => c.tap('Neuigkeiten'));
      c.screen('Neuigkeiten');
      await c.check('Benutzt', () => eventually(() => (prefs.getStringList('tips_used') ?? const []).contains('newsIcon')));
      await c.snap();

      c.clearMessages();
      c.step('Startseite: alles erledigt', 'Zurück, am nächsten Tag auf der Startseite warten.', 'Kein Tipp mehr auf der Startseite.',
          explain: 'Kamera und Neues Album sind verstanden, Neuigkeiten benutzt: für diese Seite gibt es nichts mehr.');
      await home();
      await nextDay();
      await c.check('Kein Tipp', () => noTip());
      await c.snap();

      // ================================================================ Im Album
      c.clearMessages();
      c.step('Im Album: Frame-Symbol', 'Geburtstage öffnen.',
          'Die Sprechblase zeigt auf das Frame-Symbol oben: Ein Tipp auf das Frame-Symbol zeigt dieses Album sofort am Frame. '
              'Lang drücken öffnet die Fernbedienung.',
          explain: 'Den bekommt nur, wer einen Frame hat. Heute gab es noch keinen Tipp.');
      await openAlbum();
      await tip(_frameButton);
      await c.snap();
      await understood('frameButton');

      c.clearMessages();
      c.step('Am nächsten Tag: Diashow', 'Am nächsten Tag Geburtstage.',
          'Die Sprechblase zeigt auf das Diashow-Symbol: Mit dem Diashow-Symbol läuft das Album als Diashow auf diesem Handy.',
          explain: 'Der nächste Tipp dieser Seite.');
      c.screen('Album');
      await nextDay();
      await tip(_slideshow);
      await c.snap();

      c.clearMessages();
      c.step('Den Knopf selbst antippen', 'Auf das leuchtende Diashow-Symbol tippen.',
          'Die Sprechblase verschwindet und die Diashow startet.', kind: 'Abzweigung',
          explain: 'Wer gleich ausprobiert, worauf der Tipp zeigt, ist fertig damit.');
      await tester.tap(find.byTooltip('Diashow').first, warnIfMissed: false);
      c.logTap('Diashow');
      await c.settle();
      await c.check('Tipp zu', () => c.gone(_slideshow, seconds: 3));
      await c.check('Diashow läuft', () => eventually(() => find.byType(AlbumSlideshowScreen).evaluate().isNotEmpty, seconds: 3));
      c.screen(find.byType(AlbumSlideshowScreen).evaluate().isNotEmpty ? 'Diashow' : 'Album');
      await c.snap();
      if (find.byType(AlbumSlideshowScreen).evaluate().isNotEmpty) await c.back();
      c.screen('Album');

      c.clearMessages();
      c.step('Am nächsten Tag: Auswählen', 'Am nächsten Tag Geburtstage.',
          'Unten eine Karte: Lang auf ein Foto drücken: mehrere auswählen, ausblenden oder löschen.',
          explain: 'Ohne Knopf, auf den er zeigen könnte, kommt der Tipp als Karte unten.');
      await nextDay();
      await tip(_selectPhotos);
      await c.snap();

      c.clearMessages();
      c.step('Keine Tipps mehr', 'Auf Keine Tipps mehr tippen.', 'Die Karte verschwindet.', kind: 'Abzweigung',
          explain: 'Wer keine Tipps möchte, schaltet sie hier alle auf einmal aus.');
      await c.tap('Keine Tipps mehr');
      c.screen('Album');
      await c.check('Zu', () => c.gone(_selectPhotos, seconds: 3));
      await c.check('Tipps aus', () => prefs.getBool('tips_enabled') == false);
      await c.snap();

      c.clearMessages();
      c.step('Tipps sind aus', 'Am nächsten Tag Geburtstage, eine Weile warten.', 'Kein Tipp.', kind: 'Abzweigung',
          explain: 'Ausgeschaltet bleibt ausgeschaltet.');
      await nextDay();
      await c.check('Kein Tipp', () => noTip());
      await c.snap();

      c.clearMessages();
      c.step('Wieder einschalten', 'Zurück, drei Punkte, Einstellungen, Tipps anzeigen antippen.', 'Der Schalter ist wieder an.',
          kind: 'Abzweigung', explain: 'In den Einstellungen gehen die Tipps jederzeit wieder an.');
      await home();
      await openSettings();
      await scrollTo(switchTile);
      await c.check('Schalter aus', () => !switchOn());
      await tester.tap(switchTile, warnIfMissed: false);
      c.logTap('Tipps anzeigen');
      await c.settle();
      await c.check('Schalter an', () => switchOn());
      await c.snap();

      c.clearMessages();
      c.step('Auswählen kommt wieder', 'Zurück, Geburtstage öffnen, dann Verstanden.',
          'Zuerst die Karte Lang auf ein Foto drücken …; nach Verstanden ist sie weg.', kind: 'Abzweigung',
          explain: 'Der Tipp war noch nicht verstanden, also kommt er wieder.');
      await home();
      await openAlbum();
      await nextDay();
      await tip(_selectPhotos);
      await understood('selectPhotos');
      c.screen('Album');
      await c.snap();

      // ================================================================ Foto, Senden, Infos
      Future<void> openFruit() async {
        final any = find.byKey(ValueKey(fruit), skipOffstage: false);
        if (any.evaluate().isEmpty) {
          final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
          for (var at = position.minScrollExtent; at <= position.maxScrollExtent + 1; at += position.viewportDimension / 2) {
            position.jumpTo(at.clamp(position.minScrollExtent, position.maxScrollExtent));
            await tester.pump(const Duration(milliseconds: 50));
            if (any.evaluate().isNotEmpty) break;
          }
        }
        await Scrollable.ensureVisible(any.evaluate().first, alignment: 0.5);
        await c.settle();
        await until(PhotoViewerScreen, () async {
          await tester.tap(find.byKey(ValueKey(fruit)), warnIfMissed: false);
          c.logTap('Foto');
          await c.settle();
        });
        c.screen('Foto');
      }

      c.clearMessages();
      c.step('Im Foto: Titel', 'Am nächsten Tag auf die Obstschale tippen.',
          'Die Sprechblase zeigt auf das Titel-Zeichen oben: Hier kannst du nachträglich einen Titel setzen oder ändern.',
          explain: 'Die Tipps der Großansicht.');
      await nextDay();
      await openFruit();
      await tip(_captionLater);
      await c.snap();
      await understood('captionLater');

      c.clearMessages();
      c.step('Am nächsten Tag: Herz', 'Am nächsten Tag wieder die Obstschale.',
          'Die Sprechblase zeigt auf das Herz: Mit dem Herz merkst du ein Foto als Lieblingsbild für den Frame.',
          explain: 'Das Herz gibt es, sobald das Album auf einem Frame läuft.');
      c.screen('Foto');
      await nextDay();
      await tip(_favoriteHeart);
      await c.snap();
      await understood('favoriteHeart');

      c.clearMessages();
      c.step('Am nächsten Tag: Titel beim Senden', 'Zurück, am nächsten Tag + antippen, Pizza wählen, Auswählen.',
          'Die Vorschau; die Sprechblase zeigt auf das Titelfeld: Jedes Foto kann einen eigenen Titel bekommen.',
          explain: 'Der Tipp kommt, bevor man etwas sendet.');
      await c.back();
      c.screen('Album');
      await nextDay();
      await c.tap('Foto oder Video teilen');
      c.screen('Testbilder');
      await c.waitFor('Testbilder', seconds: 15);
      final pizza = find.bySemanticsLabel('Pizza');
      await tester.scrollUntilVisible(pizza, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(pizza.first, warnIfMissed: false);
      c.logTap('Pizza');
      await c.settle();
      await c.tap('Auswählen');
      c.screen('Vorschau');
      await tip(_captionWhenSending);
      await c.snap();
      await understood('captionWhenSending');

      c.clearMessages();
      c.step('Vorschau schließen', 'Oben links auf das Kreuz.', 'Wieder Geburtstage, die Pizza wurde nicht gesendet.',
          explain: 'Der Tipp hat nichts gesendet.');
      await tester.tap(find.byIcon(SmileIcons.close).first, warnIfMissed: false);
      c.logTap('Schließen');
      await c.settle();
      c.screen('Album');
      await c.check('Nichts gesendet', () async =>
          (await TestBackend.select('media_items', 'select=id&channel_id=eq.$birthdays')).length == 5);
      await c.snap();

      c.clearMessages();
      c.step('Am nächsten Tag: Einladen', 'Am nächsten Tag oben auf Geburtstage tippen.',
          'Die Album-Infos, unten eine Karte: Einladen geht auch ohne E-Mail: per QR-Code, Link oder aus den Kontakten.',
          explain: 'Wer schon über einen dieser Wege eingeladen hat, bekommt den Tipp nicht.');
      await nextDay();
      await until(AlbumInfoScreen, () => c.tap('Geburtstage', last: true));
      c.screen('Album-Infos');
      await tip(_inviteWays);
      await c.snap();
      await understood('inviteWays');

      // ================================================================ Fernbedienung
      c.clearMessages();
      c.step('Fernbedienung: Bedienstufe', 'Zurück zur Startseite, am nächsten Tag unten Frames, dann Wohnzimmer.',
          'Die Fernbedienung, unten eine Karte: Mit der Bedienstufe legst du fest, was am Frame selbst bedient werden kann.',
          explain: 'Drei Tipps gibt es zur Fernbedienung, einen pro Tag. In diesem Kapitel läuft kein Tablet, darum steht oben Verbunden · meldet sich gleich.');
      await home();
      await nextDay();
      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await until(FrameRemoteScreen, () => tapExact('Wohnzimmer'));
      c.screen('Fernbedienung');
      await tip(_controlLevel);
      await c.snap();
      await understood('controlLevel');

      c.clearMessages();
      c.step('Am nächsten Tag: Wiedergabe', 'Am nächsten Tag die Fernbedienung.',
          'Die Karte: Unter Wiedergabe: Uhr, Nachtruhe, Titel, langsamer Zoom und Keine Videos.', explain: 'Der zweite.');
      c.screen('Fernbedienung');
      await nextDay();
      await tip(_playback);
      await c.snap();
      await understood('playback');

      c.clearMessages();
      c.step('Am nächsten Tag: Lieblingsbilder', 'Am nächsten Tag die Fernbedienung.',
          'Die Karte: Lieblingsbilder laufen am Frame als eigene Runde, auch über alle Alben.', explain: 'Der dritte.');
      c.screen('Fernbedienung');
      await nextDay();
      await tip(_favoritesRound);
      await c.snap();
      await understood('favoritesRound');

      c.clearMessages();
      c.step('Alle gesehen', 'Am nächsten Tag die Fernbedienung, eine Weile warten.', 'Kein Tipp mehr.',
          explain: 'Alle Tipps sind verstanden oder benutzt.');
      c.screen('Fernbedienung');
      await nextDay();
      await c.check('Kein Tipp', () => noTip());
      await c.check('Alle erledigt', () async {
        final done = {...seen(), ...?prefs.getStringList('tips_used')};
        return done.length == 15;
      });
      await c.snap();

      // ================================================================ Von vorne
      c.clearMessages();
      c.step('Tipps von vorne zeigen', 'Zurück, drei Punkte, Einstellungen, nach unten, Tipps von vorne zeigen.',
          'Unten kurz: Die Tipps kommen wieder von vorne. Nach ein paar Sekunden wieder die Karte zu Videos senden.',
          explain: 'Wer alles noch einmal sehen möchte. Was man selbst benutzt hat, bleibt weg.');
      await home();
      await openSettings();
      await scrollTo(find.text('Tipps von vorne zeigen'));
      await c.tap('Tipps von vorne zeigen');
      await c.check('Meldung', () => c.waitFor('Die Tipps kommen wieder von vorne.', seconds: 3));
      await c.check('Gesehene vergessen', () => seen().isEmpty);
      await tip(_videoQuality);
      await c.snap();

      c.clearMessages();
      c.step('Und wieder verstanden', 'Auf Verstanden tippen.', 'Die Karte verschwindet.', explain: 'Ab hier wieder einer am Tag.');
      await understood('videoQuality');
      c.screen('Einstellungen');
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
