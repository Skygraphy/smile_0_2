// Kapitel 15: Fotos weitergeben (tools/testsuite, 2026-11-27).
// Startet dort, wo Kapitel 4 endet (ohne Frame: Lieblingsbild und Am Frame
// zeigen gehören zu Kapitel 7). Das Teilen-Menü und die Galerie gehören zu
// Android: die Testsuite fängt ab, was Smile ihnen übergibt, damit kein
// Testbild in der echten Galerie landet. "Aus einer anderen App teilen"
// spielt die Testsuite so, wie Android es Smile meldet (smile/share_in).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/media_pager_screen.dart';
import 'package:smile_app/screens/settings_screen.dart';
import 'package:smile_app/screens/share_in_screen.dart';
import 'package:smile_app/services/video_quality.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

/// Android's share sheet is not Smile: what Smile hands to it is caught.
class _CaughtShare extends SharePlatform {
  final shares = <List<String>>[];
  @override
  Future<ShareResult> share(ShareParams params) async {
    shares.add([for (final f in params.files ?? const <XFile>[]) f.path]);
    return const ShareResult('test', ShareResultStatus.success);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 15: Fotos weitergeben', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch15',
        title: 'Fotos weitergeben',
        intro: 'Anna blättert im Vollbild durch ein Album, schickt Fotos über WhatsApp und Co. weiter, speichert sie in die '
            'Galerie ihres Handys, löscht eines direkt im Vollbild, teilt Fotos aus einer anderen App nach Smile und sendet ein '
            'Video in Full HD.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    final messenger = tester.binding.defaultBinaryMessenger;

    // The share sheet.
    final share = _CaughtShare();
    SharePlatform.instance = share;

    // The gallery (package gal): access granted or not, what was put in.
    var galleryAccess = true;
    final gallery = <String>[];
    messenger.setMockMethodCallHandler(const MethodChannel('gal'), (call) async {
      switch (call.method) {
        case 'hasAccess':
        case 'requestAccess':
          return galleryAccess;
        case 'putImage':
        case 'putVideo':
          final args = (call.arguments as Map).cast<String, Object?>();
          gallery.add('${call.method == 'putVideo' ? 'Video' : 'Foto'} in ${args['album']}');
          return null;
      }
      return null;
    });

    // Shared from another app: what Android has ready (ShareIn.kt).
    var sharedPaths = <String>[];
    messenger.setMockMethodCallHandler(const MethodChannel('smile/share_in'), (call) async {
      if (call.method == 'take') {
        final paths = sharedPaths;
        sharedPaths = [];
        return paths;
      }
      return null;
    });
    Future<void> shareFromOtherApp(List<String> files) async {
      final media = '${(await getApplicationSupportDirectory()).path}/fixtures/media';
      final cache = Directory('${(await getTemporaryDirectory()).path}/shared_in_test')..createSync(recursive: true);
      sharedPaths = [for (final f in files) File('$media/$f').copySync('${cache.path}/$f').path];
      await messenger.handlePlatformMessage(
          'smile/share_in', const StandardMethodCodec().encodeMethodCall(const MethodCall('available')), (_) {});
    }

    // Shrinking a video happens in Android (VideoCompressor.kt): the call
    // is passed on unchanged, the test only reads what Smile asked for.
    final compressCalls = <Map<String, Object?>>[];
    messenger.setMockMessageHandler('smile/video_compress', (message) {
      final call = const StandardMethodCodec().decodeMethodCall(message);
      if (call.method == 'compress') compressCalls.add((call.arguments as Map).cast<String, Object?>());
      return messenger.delegate.send('smile/video_compress', message);
    });

    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 4)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter4(tester);
      final birthdays = seed.albums['Geburtstage']!;
      final summer = seed.albums['Sommerurlaub 2026']!;

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<List<Map>> items(String album) async => (await TestBackend.select(
              'media_items', 'select=id,media_type,caption,processing_status&channel_id=eq.$album&order=created_at.asc'))
          .cast<Map>();
      final shown = await items(birthdays);
      // Oldest first: Torte, Luftballons, Kerzen, Obstschale, Hund.
      final torte = shown[0]['id'] as String;
      final ballons = shown[1]['id'] as String;
      final obst = shown[3]['id'] as String;

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

      Future<void> tapItem(String id, String label, {bool long = false}) async {
        final any = find.byKey(ValueKey(id), skipOffstage: false);
        if (any.evaluate().isEmpty) {
          final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
          for (var at = position.minScrollExtent; at <= position.maxScrollExtent + 1; at += position.viewportDimension / 2) {
            position.jumpTo(at.clamp(position.minScrollExtent, position.maxScrollExtent));
            await tester.pump(const Duration(milliseconds: 50));
            if (any.evaluate().isNotEmpty) break;
          }
        }
        await Scrollable.ensureVisible(any.evaluate().first, alignment: 0.5);
        await tester.pump(const Duration(milliseconds: 200));
        final f = find.byKey(ValueKey(id));
        if (long) {
          await tester.longPress(f.first, warnIfMissed: false);
        } else {
          await tester.tap(f.first, warnIfMissed: false);
        }
        c.logTap(label);
        await c.settle();
      }

      /// Which page the full screen shows (0 = the oldest).
      int page() => tester.widget<PageView>(find.byType(PageView)).controller!.page!.round();

      Future<void> swipe({required bool left}) async {
        // Slowly, like a finger: one page per swipe (a fling skipped pages).
        await tester.timedDrag(find.byType(PageView), Offset(left ? -300 : 300, 0), const Duration(milliseconds: 600));
        c.logTap(left ? 'Nach links wischen' : 'Nach rechts wischen');
        await c.settle();
        await tester.pump(const Duration(milliseconds: 600));
      }

      Future<void> more() async {
        await tapExact('Mehr');
        c.screen('Mehr');
      }

      Future<void> home() async {
        for (var i = 0; i < 6 && (app.navigatorKey.currentState?.canPop() ?? false); i++) {
          await c.back();
        }
        c.screen('Startseite');
        await c.waitFor('Neuigkeiten', seconds: 10);
      }

      Future<void> openAlbum(String name) async {
        await until(ChannelFeedScreen, () => c.tap(name, last: true));
        c.screen('Album');
        await c.waitFor('~Du:', seconds: 15);
      }

      Future<void> openSettings() async {
        await c.tap('Weitere Optionen');
        c.screen('Menü');
        await until(SettingsScreen, () => c.tap('Einstellungen', last: true));
        c.screen('Einstellungen');
      }

      await c.waitFor('Geburtstage', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Im Vollbild blättern
      c.step('Ausgangslage', 'Geburtstage antippen.',
          'Das Album Geburtstage mit drei Fotos und zwei Videos, unten das neueste: der laufende Hund.',
          explain: 'Wie Kapitel 4 endet. Hier geht es darum, Fotos aus Smile hinauszugeben und hereinzuholen.');
      await openAlbum('Geburtstage');
      await c.check('Server: fünf Fotos und Videos', () async => (await items(birthdays)).length == 5);
      await c.snap();

      c.step('Foto im Vollbild', 'Auf die Obstschale tippen.',
          'Die Obstschale füllt den Bildschirm. Unten Knöpfe mit Wörtern: Titel, Löschen und Mehr.',
          explain: 'Unten stehen die Knöpfe mit Beschriftung, damit man ohne Vorwissen weiß, was sie tun. Lieblingsbild und Am Frame '
              'zeigen kommen dazu, sobald ein Frame da ist (Kapitel 7).');
      await tapItem(obst, 'Foto');
      c.screen('Vollbild');
      await c.check('Vollbild', () => eventually(() => find.byType(MediaPagerScreen).evaluate().isNotEmpty, seconds: 5));
      await c.check('Knöpfe mit Wörtern', () async =>
          await c.waitFor('Titel', seconds: 5) && await c.waitFor('Löschen', seconds: 1) && await c.waitFor('Mehr', seconds: 1));
      await c.check('Titel im Bild', () => c.waitFor('Obst für alle', seconds: 3));
      await c.check('Die Obstschale', () => page() == 3);
      await c.snap();

      c.step('Nach links wischen', 'Nach links wischen.', 'Der laufende Hund, das nächste neuere Video; es spielt gleich los.',
          explain: 'Wie bei WhatsApp: nach links kommt das Neuere, nach rechts das Ältere. Nur das Bild bewegt sich, die Knöpfe bleiben.');
      await swipe(left: true);
      await c.check('Der Hund', () => eventually(() => page() == 4, seconds: 3));
      await c.check('Knöpfe bleiben', () => c.waitFor('Mehr', seconds: 2));
      await c.snap();

      c.step('Am Ende weiterwischen', 'Noch einmal nach links wischen.', 'Der Hund bleibt: er ist das neueste.',
          kind: 'Abzweigung', explain: 'Nach dem neuesten kommt nichts mehr.');
      await swipe(left: true);
      await c.check('Bleibt beim Hund', () => page() == 4);
      await c.snap();

      c.step('Nach rechts wischen', 'Zweimal nach rechts wischen.', 'Die Torte mit Kerzen.',
          explain: 'Zurück zu den älteren.');
      await swipe(left: false);
      await swipe(left: false);
      await c.check('Die Kerzen', () => eventually(() => page() == 2, seconds: 3));
      await c.snap();

      // ================================================================ Teilen und Speichern
      c.step('Mehr', 'Unten Mehr antippen.', 'Ein kleines Menü: Teilen … und Aufs Handy speichern.',
          explain: 'Alles, was ein Foto aus Smile hinausgibt, steht unter Mehr.');
      await more();
      await c.check('Teilen', () => c.waitFor('Teilen …', seconds: 3));
      await c.check('Speichern', () => c.waitFor('Aufs Handy speichern', seconds: 1));
      await c.snap();

      c.step('Mehr: daneben tippen', 'Oben neben das Menü tippen, dann wieder Mehr.', 'Das Menü schließt sich; danach ist es wieder offen.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt das Menü, ohne etwas zu tun.');
      await c.tapAt(const Offset(200, 300), 'Menü schließen');
      c.screen('Vollbild');
      await c.check('Zu', () => c.gone('Teilen …', seconds: 3));
      await more();
      await c.check('Wieder offen', () => c.waitFor('Teilen …', seconds: 3));
      await c.snap();

      c.step('Teilen', 'Teilen … antippen.',
          'Kurz Wird vorbereitet …, dann das Teilen-Menü von Android mit der Torte, etwa für WhatsApp oder eine E-Mail.',
          explain: 'Das Teilen-Menü gehört zu Android. Die Testsuite fängt ab, was Smile ihm übergibt: genau ein Foto.');
      await tapExact('Teilen …');
      c.screen('Vollbild');
      await c.check('Ein Foto ans Teilen-Menü', () => eventually(() => share.shares.length == 1 && share.shares.last.length == 1));
      await c.check('Als Foto (jpg)', () => share.shares.last.single.endsWith('.jpg'));
      await c.snap();

      c.clearMessages();
      c.step('Aufs Handy speichern', 'Mehr, dann Aufs Handy speichern.',
          'Unten kurz Gespeichert – in deiner Galerie im Album „Smile“.',
          explain: 'Das Foto kommt in die Galerie des Handys, in ein eigenes Album Smile. Die Testsuite fängt es ab.');
      await more();
      await tapExact('Aufs Handy speichern');
      c.screen('Vollbild');
      await c.check('Meldung', () => c.waitFor('Gespeichert – in deiner Galerie', seconds: 15));
      await c.check('Ein Foto im Album Smile', () => gallery.length == 1 && gallery.single == 'Foto in Smile');
      await c.snap();

      c.clearMessages();
      c.step('Speichern ohne Erlaubnis', 'Mehr, Aufs Handy speichern; Android fragt nach der Erlaubnis, sie wird abgelehnt.',
          'Unten kurz Das Speichern hat leider nicht geklappt. Nichts kommt in die Galerie.',
          kind: 'Abzweigung', explain: 'Ohne Erlaubnis für die Galerie kann Smile nichts dort ablegen; eine freundliche Meldung sagt das.');
      galleryAccess = false;
      await more();
      await tapExact('Aufs Handy speichern');
      c.screen('Vollbild');
      await c.check('Meldung', () => c.waitFor('Das Speichern hat leider nicht geklappt.', seconds: 10));
      await c.check('Nichts dazu', () => gallery.length == 1);
      galleryAccess = true;
      await c.snap();

      // ================================================================ Löschen im Vollbild
      c.clearMessages();
      c.step('Löschen im Vollbild: Abbrechen', 'Unten Löschen antippen, dann Abbrechen.',
          'Die gleiche Frage wie im Album: Für alle löschen oder Für mich löschen. Nach Abbrechen bleibt die Torte.',
          kind: 'Abzweigung', explain: 'Im Vollbild fragt Smile genauso nach wie im Album.');
      await tapExact('Löschen');
      c.screen('Löschen-Frage');
      await c.check('Zwei Wege', () async =>
          await c.waitFor('Für alle löschen', seconds: 3) && await c.waitFor('Für mich löschen', seconds: 1));
      await c.tap('Abbrechen', last: true);
      c.screen('Vollbild');
      await c.check('Server: alle fünf da', () async => (await items(birthdays)).length == 5);
      await c.check('Noch die Kerzen', () => page() == 2);
      await c.snap();

      c.clearMessages();
      c.step('Für mich löschen im Vollbild', 'Löschen, dann Für mich löschen.',
          'Die Torte mit Kerzen verschwindet nur bei Anna; an ihrer Stelle die Obstschale.',
          explain: 'Nach dem Löschen zeigt das Vollbild gleich das nächste. Für mich löschen lässt sich unter Ausgeblendete zurückholen '
              '(Kapitel 4).');
      await tapExact('Löschen');
      c.screen('Löschen-Frage');
      await tapExact('Für mich löschen');
      c.screen('Vollbild');
      final kerzen = shown[2]['id'] as String;
      await c.check('Server: für Anna ausgeblendet', () => eventually(() async =>
          (await TestBackend.select('media_item_hides', 'select=media_item_id&media_item_id=eq.$kerzen')).isNotEmpty));
      await c.check('Jetzt die Obstschale', () => c.waitFor('Obst für alle', seconds: 5));
      await c.snap();

      // ================================================================ Mehrere weitergeben
      c.clearMessages();
      c.step('Zurück ins Album', 'Oben links Zurück.', 'Das Album ohne die Torte mit Kerzen.',
          explain: 'Im Album steht nur noch, was Anna sehen will.');
      await c.back();
      c.screen('Album');
      await c.check('Album', () => eventually(() => find.byType(MediaPagerScreen).evaluate().isEmpty, seconds: 3));
      await c.check('Kerzen weg', () => eventually(() => find.byKey(ValueKey(kerzen), skipOffstage: false).evaluate().isEmpty, seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Mehrere teilen', 'Lange auf die Geburtstagstorte drücken, dazu die Luftballons antippen, unten Teilen.',
          'Das Teilen-Menü von Android mit einem Foto und einem Video; die Auswahl ist danach zu.',
          explain: 'In der Auswahl stehen Teilen und Speichern unten, zwischen Alle auswählen und Löschen.');
      await tapItem(torte, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await tapItem(ballons, 'Video in der Auswahl');
      await c.check('Teilen und Speichern', () async => await c.waitFor('Teilen', seconds: 3) && await c.waitFor('Speichern', seconds: 1));
      await tapExact('Teilen');
      c.screen('Album');
      await c.check('Zwei ans Teilen-Menü', () => eventually(() => share.shares.length == 2 && share.shares.last.length == 2, seconds: 30));
      await c.check('Foto und Video', () =>
          share.shares.last.where((p) => p.endsWith('.jpg')).length == 1 && share.shares.last.where((p) => p.endsWith('.mp4')).length == 1);
      await c.snap();

      c.clearMessages();
      c.step('Mehrere speichern', 'Wieder lange auf die Geburtstagstorte drücken, die Luftballons dazu, unten Speichern.',
          'Unten kurz 2 gespeichert – in deiner Galerie im Album „Smile“.',
          explain: 'Fotos und Videos landen gemeinsam im Album Smile der Galerie.');
      gallery.clear();
      await tapItem(torte, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await tapItem(ballons, 'Video in der Auswahl');
      await tapExact('Speichern');
      c.screen('Album');
      await c.check('Meldung', () => c.waitFor('2 gespeichert', seconds: 30));
      await c.check('Foto und Video in Smile', () =>
          gallery.length == 2 && gallery.contains('Foto in Smile') && gallery.contains('Video in Smile'));
      await c.snap();

      c.clearMessages();
      c.step('Ganzes Album speichern: die Frage', 'Oben rechts die drei Punkte, Ganzes Album speichern.',
          'Die Frage 4 Fotos und Videos aufs Handy speichern? mit dem Hinweis auf WLAN, dazu Abbrechen und Speichern.',
          explain: 'Vier, denn die Torte mit Kerzen ist für Anna ausgeblendet. Videos können groß sein, daher der Hinweis.');
      gallery.clear();
      await c.tap('Weitere Optionen');
      c.screen('Menü des Albums');
      await tapExact('Ganzes Album speichern');
      c.screen('Frage');
      await c.check('Frage', () => c.waitFor('4 Fotos und Videos aufs Handy speichern?', seconds: 5));
      await c.check('WLAN', () => c.waitFor('~am besten im WLAN', seconds: 1));
      await c.snap();

      c.step('Ganzes Album: Abbrechen', 'Abbrechen antippen.', 'Die Frage schließt sich, nichts wird gespeichert.',
          kind: 'Abzweigung', explain: 'Abbrechen speichert nichts.');
      await c.tap('Abbrechen', last: true);
      c.screen('Album');
      await c.check('Nichts gespeichert', () async {
        await c.letLoad(seconds: 1);
        return gallery.isEmpty;
      });
      await c.snap();

      c.step('Ganzes Album: daneben tippen', 'Noch einmal drei Punkte, Ganzes Album speichern, dann oben neben die Frage tippen.',
          'Die Frage schließt sich, nichts wird gespeichert.', kind: 'Abzweigung', explain: 'Ein Tipp daneben wirkt wie Abbrechen.');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Albums');
      await tapExact('Ganzes Album speichern');
      c.screen('Frage');
      await c.waitFor('4 Fotos und Videos aufs Handy speichern?', seconds: 5);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Album');
      await c.check('Zu', () => c.gone('4 Fotos und Videos aufs Handy speichern?', seconds: 3));
      await c.check('Nichts gespeichert', () async {
        await c.letLoad(seconds: 1);
        return gallery.isEmpty;
      });
      await c.snap();

      c.clearMessages();
      c.step('Ganzes Album speichern', 'Noch einmal drei Punkte, Ganzes Album speichern, dann Speichern.',
          'Unten zählt es mit (1 von 4 …), dann 4 gespeichert – in deiner Galerie im Album „Smile“.',
          explain: 'So holt man ein ganzes Album auf ein neues Handy oder als Sicherung.');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Albums');
      await tapExact('Ganzes Album speichern');
      c.screen('Frage');
      await tapExact('Speichern');
      c.screen('Album');
      await c.check('Meldung', () => c.waitFor('4 gespeichert', seconds: 60));
      await c.check('Zwei Fotos, zwei Videos', () =>
          gallery.where((g) => g == 'Foto in Smile').length == 2 && gallery.where((g) => g == 'Video in Smile').length == 2);
      await c.snap();

      // ================================================================ Aus einer anderen App nach Smile
      c.clearMessages();
      c.step('Aus der Galerie teilen', 'Zurück zur Startseite. In der Galerie zwei Fotos (Leuchtturm, Regenbogen) auswählen, '
              'Teilen und Smile wählen.',
          'Smile öffnet Senden an …: oben die zwei Bilder und 2 Fotos, darunter die Alben, in die Anna senden darf.',
          explain: 'Smile steht im Teilen-Menü jeder App, wie WhatsApp. Die Testsuite meldet Smile die zwei Fotos so, wie Android es tut.');
      await home();
      await shareFromOtherApp(['15_leuchtturm.jpg', '16_regenbogen.jpg']);
      c.screen('Senden an');
      await c.check('Senden an', () => eventually(() => find.byType(ShareInScreen).evaluate().isNotEmpty, seconds: 10));
      await c.check('2 Fotos', () => c.waitFor('2 Fotos', seconds: 5));
      await c.check('Alben', () async =>
          await c.waitFor('Sommerurlaub 2026', seconds: 10) && await c.waitFor('Geburtstage', seconds: 2) && await c.waitFor('Weihnachten', seconds: 2));
      await c.snap();

      c.step('Senden an: Zurück', 'Oben links Zurück.', 'Wieder die Startseite; nichts wurde gesendet.',
          kind: 'Abzweigung', explain: 'Wer es sich anders überlegt, geht einfach zurück.');
      await c.back();
      c.screen('Startseite');
      await c.check('Startseite', () => eventually(() => find.byType(ShareInScreen).evaluate().isEmpty, seconds: 3));
      await c.check('Server: nichts dazu', () async => (await items(summer)).length == 1);
      await c.snap();

      c.step('In ein Album senden', 'Noch einmal zwei Fotos aus der Galerie teilen, Sommerurlaub 2026 antippen.',
          'Die Vorschau wie beim Senden aus Smile: die zwei Fotos, ein Feld für den Titel und Senden.',
          explain: 'Ab hier ist es derselbe Weg wie mit dem Plus im Album (Kapitel 3).');
      await shareFromOtherApp(['15_leuchtturm.jpg', '16_regenbogen.jpg']);
      c.screen('Senden an');
      await until(ShareInScreen, () async {});
      await c.waitFor('Sommerurlaub 2026', seconds: 10);
      await c.tap('Sommerurlaub 2026', last: true);
      c.screen('Vorschau');
      await c.check('Vorschau', () => c.waitFor('Senden', seconds: 10));
      await c.snap();

      c.step('Geteilte Fotos senden', 'Rechts unten auf den Pfeil (Senden) tippen.',
          'Das Album Sommerurlaub 2026 öffnet sich; die zwei Fotos kommen unten dazu.',
          explain: 'Gesendet wird wie immer über die Warteschlange, auch wenn Smile gleich geschlossen wird.');
      await c.tap('Senden', twice: true);
      c.screen('Album');
      await c.check('Album offen', () => eventually(() => find.byType(ChannelFeedScreen).evaluate().isNotEmpty, seconds: 10));
      await c.check('Server: drei Fotos im Sommerurlaub', () => eventually(() async => (await items(summer)).length == 3, seconds: 90));
      await c.snap();

      // ================================================================ Full HD
      c.clearMessages();
      c.step('Videos senden', 'Zurück zur Startseite, drei Punkte, Einstellungen, nach unten zu Videos senden.',
          'Full HD ist aus; darunter Hoch, Mittel und Niedrig.',
          explain: 'Smile verkleinert Videos vor dem Senden, damit es schnell geht. Full HD ist für große Bildschirme.');
      await home();
      await openSettings();
      await c.check('Full HD', () => c.dragTo('Full HD'));
      await c.check('Aus', () => !tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Full HD')).value);
      await c.snap();

      c.step('Full HD einschalten', 'Den Schalter bei Full HD antippen.',
          'Full HD ist an; Hoch, Mittel und Niedrig sind ausgegraut, denn sie gelten jetzt nicht.',
          explain: 'Beste Qualität, braucht aber mehr Daten und länger zum Senden. Gilt nur für dieses Handy.');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Full HD'));
      c.logTap('Full HD');
      await c.settle();
      await c.check('An', () => tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Full HD')).value);
      await c.check('Stufen ausgegraut', () =>
          tester.widgetList<IgnorePointer>(find.ancestor(of: find.byType(SegmentedButton<VideoQuality>).first, matching: find.byType(IgnorePointer)))
              .any((w) => w.ignoring));
      await c.snap();

      c.step('Video in Full HD senden', 'Zurück, Geburtstage öffnen, unten Foto oder Video, das Video Segelboot fährt wählen, Auswählen (1), Senden.',
          'Das Video kommt ins Album; Smile hat es in Full HD verkleinert (1080 Bildpunkte an der kurzen Seite).',
          explain: 'Die Testsuite liest mit, was Smile dem Handy zum Verkleinern aufträgt.');
      await home();
      await openAlbum('Geburtstage');
      await c.tap('Foto oder Video teilen');
      c.screen('Testbilder');
      if (!await c.waitFor('Testbilder', seconds: 15)) throw TestFailure('Testbilder erscheinen nicht');
      await c.settle();
      final boat = find.bySemanticsLabel('Segelboot fährt');
      await tester.scrollUntilVisible(boat, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(boat.first, warnIfMissed: false);
      c.logTap('Segelboot fährt');
      await c.settle();
      await c.tap('Auswählen');
      c.screen('Vorschau');
      await c.waitFor('Senden', seconds: 10);
      await c.tap('Senden', twice: true);
      c.screen('Album');
      await c.check('Server: Video da', () => eventually(() async {
            final now = await items(birthdays);
            return now.length == 6 && now.last['media_type'] == 'video' && now.last['processing_status'] == 'ready';
          }, seconds: 120));
      await c.check('In Full HD verkleinert', () => compressCalls.isNotEmpty && compressCalls.last['shortSide'] == 1080);
      await c.snap();

      c.step('Full HD ausschalten', 'Zurück, drei Punkte, Einstellungen, Full HD wieder aus.',
          'Full HD ist aus, Hoch, Mittel und Niedrig gelten wieder.', explain: 'Wie es für die meisten am besten passt.');
      await home();
      await openSettings();
      await c.dragTo('Full HD');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Full HD'));
      c.logTap('Full HD');
      await c.settle();
      await c.check('Aus', () => !tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Full HD')).value);
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
