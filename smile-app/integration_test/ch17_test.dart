// Kapitel 17: Hilfe, Über Smile, Sprache und Töne (tools/testsuite, 2026-11-27).
// Startet dort, wo Kapitel 4 endet, dazu Annas Frame Wohnzimmer. Was Android
// übernimmt (Browser, Bildschirmfoto, Töne), fängt die Testsuite ab: sie
// liest, was Smile verlangt, und meldet Smile ein Bildschirmfoto so, wie
// Android es tut (smile/screen_capture).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/about_screen.dart';
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/channels_home_screen.dart';
import 'package:smile_app/screens/feedback_screen.dart';
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frames_screen.dart';
import 'package:smile_app/screens/licenses_screen.dart';
import 'package:smile_app/screens/settings_screen.dart';
import 'package:smile_app/services/frame_service.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

/// The browser is not Smile: the address Smile opens is caught.
class _CaughtLaunch extends UrlLauncherPlatform {
  final urls = <String>[];
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return true;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 17: Hilfe, Über Smile, Sprache und Töne', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch17',
        title: 'Hilfe, Über Smile, Sprache und Töne',
        intro: 'Anna schreibt dem Smile-Team eine Idee mit Bild, meldet ein Problem direkt mit einem Bildschirmfoto, schaut unter '
            'Über Smile nach Impressum, Datenschutz und Lizenzen, stellt Smile auf Englisch und zurück und schaltet die Töne im '
            'Album aus und wieder ein.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    final messenger = tester.binding.defaultBinaryMessenger;

    final launch = _CaughtLaunch();
    UrlLauncherPlatform.instance = launch;

    // The plops (AlbumSounds.kt): which ones Smile asks Android to play.
    final sounds = <String>[];
    messenger.setMockMethodCallHandler(const MethodChannel('smile/sounds'), (call) async {
      if (call.method == 'play') sounds.add(call.arguments as String);
      return null;
    });

    // A screenshot, as Android 14 tells Smile (MainActivity.kt).
    Future<void> screenshot() async {
      await messenger.handlePlatformMessage(
          'smile/screen_capture', const StandardMethodCodec().encodeMethodCall(const MethodCall('captured')), (_) {});
      await tester.pump(const Duration(milliseconds: 300));
    }

    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter4(tester);
      final frames = FrameService();
      final wohnzimmer = await frames.createFrame(spaceId: seed.spaceId, name: 'Wohnzimmer');
      await frames.assignChannel(frameId: wohnzimmer.id, channelId: seed.albums['Geburtstage']!);
      await frames.setRevoked(frameId: wohnzimmer.id, revoked: false);
      final annaId = await TestBackend.userId(anna);
      final birthdays = seed.albums['Geburtstage']!;

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<List> reports() => TestBackend.select(
          'feedback_reports', 'select=kind,message,frame_id,image_paths,app_context&user_id=eq.$annaId&order=created_at.asc');
      Future<int> mediaCount() async =>
          (await TestBackend.select('media_items', 'select=id&channel_id=eq.$birthdays')).length;

      Future<void> tapExact(String text, {bool first = false}) async {
        await c.waitFor(text, seconds: 10);
        await tester.tap(first ? find.text(text).first : find.text(text).last, warnIfMissed: false);
        c.logTap(text);
        await c.settle();
      }

      Future<void> until(Type page, Future<void> Function() tap) async {
        for (var i = 0; i < 4 && find.byType(page).evaluate().isEmpty; i++) {
          await tap();
          for (var t = 0; t < 30 && find.byType(page).evaluate().isEmpty; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        if (find.byType(page).evaluate().isEmpty) throw TestFailure('Seite erscheint nicht: $page');
      }

      Future<void> home() async {
        for (var i = 0; i < 6 && (app.navigatorKey.currentState?.canPop() ?? false); i++) {
          await c.back();
        }
        c.screen('Startseite');
      }

      Future<void> openSettings({String menu = 'Weitere Optionen', String title = 'Einstellungen'}) async {
        await home();
        await c.tap(menu);
        c.screen('Menü');
        await until(SettingsScreen, () => c.tap(title, last: true));
        c.screen('Einstellungen');
      }

      Future<void> openAlbum() async {
        await home();
        // The start page may still show another tab (Frames, from the Frame steps).
        if (find.byType(ChannelsHomeScreen).evaluate().isEmpty) await tapExact('Alben');
        await until(ChannelFeedScreen, () => c.tap('Geburtstage', last: true));
        c.screen('Album');
        await c.waitFor('~Du:', seconds: 15);
      }

      Future<void> pickTest(String label) async {
        c.screen('Testbilder');
        if (!await c.waitFor('Testbilder', seconds: 15)) throw TestFailure('Testbilder erscheinen nicht');
        await c.settle();
        final f = find.bySemanticsLabel(label);
        await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
        await tester.tap(f.first, warnIfMissed: false);
        c.logTap(label);
        await c.settle();
      }

      Future<void> sendPhoto(String label) async {
        await c.tap('Foto oder Video teilen');
        await pickTest(label);
        await c.tap('Auswählen');
        c.screen('Vorschau');
        await c.waitFor('Senden', seconds: 10);
        await c.tap('Senden', twice: true);
        c.screen('Album');
      }

      bool sendEnabled() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Senden')).onPressed != null;

      await c.waitFor('Geburtstage', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Hilfe & Feedback
      c.step('Hilfe & Feedback', 'Drei Punkte oben rechts, Einstellungen, nach unten zu Hilfe & Feedback, antippen.',
          'Oben Etwas geht nicht (gewählt), Idee oder Wunsch und Frage. Ein großes Textfeld, Bilder (bis zu 3), Betrifft einen '
              'Frame? mit Nein, ein Kasten, was mitgeschickt wird und wohin die Antwort kommt, und Senden (noch ausgegraut).',
          explain: 'Was mitgeht, steht offen da, bevor man sendet: Smile-Version, Handy, Android, Sprache und der Frame.');
      await openSettings();
      await c.dragTo('Hilfe & Feedback');
      await until(FeedbackScreen, () => tapExact('Hilfe & Feedback'));
      c.screen('Hilfe & Feedback');
      await c.check('Drei Arten', () async =>
          await c.waitFor('Etwas geht nicht', seconds: 5) && await c.waitFor('Idee oder Wunsch', seconds: 1) && await c.waitFor('Frage', seconds: 1));
      await c.check('Etwas geht nicht gewählt', () => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Etwas geht nicht')).selected);
      await c.check('Frame-Auswahl', () => c.waitFor('Betrifft einen Frame?', seconds: 5));
      await c.check('Was mitgeht', () => c.dragTo('~Wird mitgeschickt: Smile'));
      await c.check('Antwort an Anna', () => c.waitFor('Antwort kommt an $anna', seconds: 2));
      await c.check('Senden ausgegraut', () => !sendEnabled());
      await c.snap();

      c.step('Art wählen', 'Frage antippen, dann wieder Etwas geht nicht.', 'Immer ist genau eine Art gewählt.', kind: 'Abzweigung',
          explain: 'Die Art hilft dem Smile-Team, die Meldung richtig einzuordnen.');
      await tapExact('Frage');
      await c.check('Frage gewählt', () => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Frage')).selected);
      await tapExact('Etwas geht nicht');
      await c.check('Etwas geht nicht gewählt', () => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Etwas geht nicht')).selected);
      await c.snap();

      c.step('Idee mit Bild', 'Idee oder Wunsch antippen, den Text schreiben, beim Plus das Bild Strand wählen.',
          'Idee oder Wunsch ist gewählt, der Text steht im Feld, darunter das Bild mit einem kleinen Kreuz. Senden ist jetzt rot.',
          explain: 'Bis zu drei Bilder, etwa Fotos von einem Frame oder Bildschirmfotos.');
      await c.dragTo('Idee oder Wunsch', up: false);
      await tapExact('Idee oder Wunsch');
      await c.typeInto('Was ist passiert?', 'Schön wäre ein Kalender mit unseren Fotos.');
      await c.hideKeyboard();
      await tester.tap(find.byIcon(SmileIcons.add).last, warnIfMissed: false);
      c.logTap('Bild hinzufügen');
      await c.settle();
      await pickTest('Strand');
      c.screen('Hilfe & Feedback');
      await c.check('Idee gewählt', () => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Idee oder Wunsch')).selected);
      await c.check('Ein Bild', () => eventually(() => find.byType(Image).evaluate().isNotEmpty && find.byIcon(SmileIcons.close).evaluate().length == 1));
      await c.check('Senden möglich', () => sendEnabled());
      await c.snap();

      c.step('Bild wieder entfernen', 'Beim Bild auf das kleine Kreuz tippen, dann noch einmal Plus und Strand.',
          'Das Bild verschwindet und ist danach wieder da.', kind: 'Abzweigung', explain: 'Ein falsches Bild nimmt man mit dem Kreuz wieder heraus.');
      await tester.tap(find.byIcon(SmileIcons.close).first, warnIfMissed: false);
      c.logTap('Bild entfernen');
      await c.settle();
      await c.check('Bild weg', () => find.byIcon(SmileIcons.close).evaluate().isEmpty);
      await tester.tap(find.byIcon(SmileIcons.add).last, warnIfMissed: false);
      c.logTap('Bild hinzufügen');
      await c.settle();
      await pickTest('Strand');
      c.screen('Hilfe & Feedback');
      await c.check('Wieder da', () => eventually(() => find.byIcon(SmileIcons.close).evaluate().length == 1));
      await c.snap();

      c.step('Frame wählen', 'Bei Betrifft einen Frame? auf Nein tippen, dann Wohnzimmer.',
          'Dort steht jetzt Wohnzimmer.', explain: 'So weiß das Smile-Team, um welchen Frame es geht, und sieht dessen Zustand.');
      await c.dragTo('Nein');
      await tapExact('Nein');
      await tapExact('Wohnzimmer');
      await c.check('Wohnzimmer gewählt', () => c.waitFor('Wohnzimmer', seconds: 3));
      await c.snap();

      c.step('Senden', 'Senden antippen.',
          'Danke, ist angekommen! Wir schauen es uns an und melden uns per E-Mail …, darunter Fertig.',
          explain: 'Die Meldung landet in der Verwaltung auf smileapp.app. Ohne Internet wartet sie und geht später von selbst.');
      await c.dragTo('Senden');
      await tapExact('Senden');
      await c.check('Danke', () => c.waitFor('Danke, ist angekommen!', seconds: 20));
      await c.check('Server: Idee mit Bild und Frame', () => eventually(() async {
            final r = await reports();
            return r.length == 1 &&
                r.single['kind'] == 'idea' &&
                (r.single['message'] as String).contains('Kalender') &&
                r.single['frame_id'] == wohnzimmer.id &&
                (r.single['image_paths'] as List).length == 1;
          }));
      await c.snap();

      c.step('Fertig', 'Fertig antippen.', 'Wieder die Einstellungen.', explain: 'Geschafft.');
      await tapExact('Fertig');
      c.screen('Einstellungen');
      await c.check('Einstellungen', () => eventually(() => find.byType(FeedbackScreen).evaluate().isEmpty && find.byType(SettingsScreen).evaluate().isNotEmpty));
      await c.snap();

      // ================================================================ Screenshot melden
      c.step('Bildschirmfoto im Album', 'Zurück, Geburtstage öffnen und ein Bildschirmfoto machen (Ein/Aus und Leiser).',
          'Oben ein Hinweis: das kleine Bildschirmfoto, Screenshot gemacht, Stimmt hier etwas nicht? und Melden.',
          explain: 'Wer etwas Seltsames sieht, macht einfach ein Bildschirmfoto. Der Hinweis geht nach 12 Sekunden von selbst weg.');
      await openAlbum();
      await screenshot();
      await c.check('Hinweis', () async =>
          await c.waitFor('Screenshot gemacht', seconds: 10) && await c.waitFor('Stimmt hier etwas nicht?', seconds: 1));
      await c.check('Melden', () => c.waitFor('Melden', seconds: 1));
      await c.snap();

      c.step('Melden', 'Melden antippen.',
          'Hilfe & Feedback mit Etwas geht nicht, das Bildschirmfoto schon dabei; im Kasten steht auch Bildschirm.',
          explain: 'Smile schickt mit, auf welcher Seite das Foto gemacht wurde. Die Galerie braucht Smile dafür nicht.');
      await tapExact('Melden');
      await until(FeedbackScreen, () async {});
      c.screen('Hilfe & Feedback');
      await c.check('Etwas geht nicht', () => tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Etwas geht nicht')).selected);
      await c.check('Bildschirmfoto dabei', () => eventually(() => find.byIcon(SmileIcons.close).evaluate().length == 1));
      await c.snap();

      c.step('Bildschirmfoto vom Formular', 'Noch ein Bildschirmfoto machen.', 'Kein Hinweis: ein Foto vom Formular selbst ist keine Meldung.',
          kind: 'Abzweigung', explain: 'Sonst käme beim Ausfüllen ständig der Hinweis.');
      await screenshot();
      await c.check('Kein Hinweis', () => c.neverShows('Screenshot gemacht', seconds: 3));
      await c.snap();

      c.step('Problem senden', 'Den Text schreiben, Senden.', 'Danke, ist angekommen!',
          explain: 'Beim Smile-Team kommt an, auf welcher Seite es war, dazu das Bild.');
      await c.typeInto('Was ist passiert?', 'Das Video ruckelt am Anfang.');
      await c.hideKeyboard();
      await c.dragTo('Senden');
      await tapExact('Senden');
      await c.check('Danke', () => c.waitFor('Danke, ist angekommen!', seconds: 20));
      await c.check('Server: Problem mit Bild und Seite', () => eventually(() async {
            final r = await reports();
            if (r.length != 2) return false;
            final last = r.last;
            return last['kind'] == 'problem' &&
                (last['image_paths'] as List).length == 1 &&
                (last['app_context'] as Map?)?['screen'] == 'Album „Geburtstage“';
          }));
      await c.snap();
      await tapExact('Fertig');

      // ================================================================ Über Smile
      c.step('Über Smile', 'Zurück, Einstellungen, ganz unten Über Smile.',
          'Das Smile-Zeichen mit der Version, darunter Impressum, Datenschutz, Konto löschen (So geht es, auch ohne App) und '
              'Open-Source-Lizenzen.',
          explain: 'Was rechtlich dazugehört, ist immer zwei Tipps entfernt.');
      await openSettings();
      await c.dragTo('Über Smile');
      await until(AboutScreen, () => tapExact('Über Smile'));
      c.screen('Über Smile');
      await c.check('Version', () => c.waitFor('Version $version', seconds: 5));
      await c.check('Vier Zeilen', () async =>
          await c.waitFor('Impressum', seconds: 2) && await c.waitFor('Datenschutz', seconds: 1) &&
          await c.waitFor('Konto löschen', seconds: 1) && await c.waitFor('Open-Source-Lizenzen', seconds: 1));
      await c.snap();

      c.step('Impressum', 'Impressum antippen.', 'Der Browser öffnet smileapp.app/impressum.html.',
          explain: 'Impressum und Datenschutz stehen auf der Website. Die Testsuite fängt die Adresse ab.');
      await tapExact('Impressum');
      await c.check('Impressum', () => launch.urls.lastOrNull == 'https://smileapp.app/impressum.html');
      await c.snap();

      c.step('Datenschutz', 'Datenschutz antippen.', 'Der Browser öffnet smileapp.app/datenschutz.html.', explain: 'Wie oben.');
      await tapExact('Datenschutz');
      await c.check('Datenschutz', () => launch.urls.lastOrNull == 'https://smileapp.app/datenschutz.html');
      await c.snap();

      c.step('Konto löschen (Website)', 'Konto löschen antippen.', 'Der Browser öffnet smileapp.app/konto-loeschen.html.',
          explain: 'Dort steht, wie man das Konto löscht, auch ohne die App. In der App selbst geht es in den Einstellungen (Kapitel 12).');
      await tapExact('Konto löschen');
      await c.check('Konto löschen', () => launch.urls.lastOrNull == 'https://smileapp.app/konto-loeschen.html');
      await c.snap();

      c.step('Open-Source-Lizenzen', 'Open-Source-Lizenzen antippen.', 'Eine Liste der Bausteine, aus denen Smile gemacht ist, mit ihren Lizenzen.',
          explain: 'Smile verwendet freie Software; ihre Lizenzen verlangen, dass sie genannt werden.');
      await until(LicensesScreen, () => tapExact('Open-Source-Lizenzen'));
      c.screen('Open-Source-Lizenzen');
      // The test app does not load Flutter's own list (NOTICES); the entries
      // Smile adds itself are there.
      await c.check('Liste', () async => await c.waitFor('Inter', seconds: 10) && await c.waitFor('Phosphor Icons', seconds: 2));
      await c.snap();

      c.step('Eine Lizenz lesen', 'Phosphor Icons antippen, dann Zurück.', 'Der Lizenztext von Phosphor Icons (MIT).',
          explain: 'Jede Lizenz lässt sich im vollen Wortlaut lesen.');
      await tapExact('Phosphor Icons');
      c.screen('Lizenztext');
      await c.check('Text', () => c.waitFor('~Permission is hereby granted', seconds: 5));
      await c.snap();
      await c.back();
      c.screen('Open-Source-Lizenzen');

      c.step('Lizenzen durchsuchen', 'Ins Suchfeld Inter eingeben, dann Inter antippen und Zurück.',
          'Nur noch Inter steht in der Liste; dahinter der Lizenztext (OFL).', kind: 'Abzweigung',
          explain: 'Bei vielen Bausteinen findet man so schnell den gesuchten.');
      await c.typeInto('', 'Inter');
      await c.hideKeyboard();
      await c.check('Nur Inter', () => c.gone('Phosphor Icons', seconds: 3));
      await tapExact('Inter');
      c.screen('Lizenztext');
      await c.check('OFL', () => c.waitFor('~Open Font License', seconds: 5));
      await c.snap();
      await c.back();
      c.screen('Open-Source-Lizenzen');

      // ================================================================ Sprache
      c.step('Sprache', 'Zweimal Zurück, bei Sprache auf Automatisch (Deutsch) tippen.',
          'Unten: Gilt für die App und die Mitteilungen, die du bekommst. Dazu Automatisch (Wie das Handy: Deutsch), Deutsch und English.',
          explain: 'Ohne Wahl spricht Smile die Sprache des Handys.');
      await c.back();
      c.screen('Über Smile');
      await c.back();
      c.screen('Einstellungen');
      await until(SettingsScreen, () async {});
      await c.dragTo('Automatisch (Deutsch)');
      await tapExact('Automatisch (Deutsch)');
      c.screen('Sprache');
      await c.check('Hinweis', () => c.waitFor('Gilt für die App und die Mitteilungen', seconds: 5));
      await c.check('Sprachen', () async =>
          await c.waitFor('Wie das Handy: Deutsch', seconds: 2) && await c.waitFor('English', seconds: 1));
      await c.snap();

      c.step('Englisch', 'English antippen.', 'Smile spricht sofort Englisch: oben steht Settings, bei Language steht English.',
          explain: 'Auch die Mitteilungen kommen jetzt auf Englisch; der Server weiß es.');
      await tapExact('English');
      c.screen('Einstellungen (Englisch)');
      await c.check('Settings', () => c.waitFor('Settings', seconds: 5));
      await c.check('Server: Englisch', () => eventually(() async =>
          (await TestBackend.select('profiles', 'select=language&user_id=eq.$annaId')).first['language'] == 'en'));
      await c.snap();

      c.step('Englisch: About Smile', 'Unten About Smile, dann Legal notice.',
          'Der Browser öffnet die englische Seite smileapp.app/en/legal-notice.html.',
          explain: 'Auch die Seiten der Website kommen in der gewählten Sprache.');
      await c.dragTo('About Smile');
      await until(AboutScreen, () => tapExact('About Smile'));
      c.screen('Über Smile (Englisch)');
      await tapExact('Legal notice');
      await c.check('Englisches Impressum', () => launch.urls.lastOrNull == 'https://smileapp.app/en/legal-notice.html');
      await c.snap();

      c.step('Zurück zu Automatisch', 'Zurück, bei Language auf English tippen, dann Automatic.',
          'Smile spricht wieder Deutsch wie das Handy: oben Einstellungen, bei Sprache Automatisch (Deutsch).',
          explain: 'So ist es für die meisten richtig.');
      await c.back();
      c.screen('Einstellungen (Englisch)');
      await c.dragTo('English', up: false);
      await tapExact('English');
      c.screen('Sprache (Englisch)');
      await tapExact('Automatic');
      c.screen('Einstellungen');
      await c.check('Einstellungen', () => c.waitFor('Einstellungen', seconds: 5));
      await c.check('Automatisch (Deutsch)', () => c.waitFor('Automatisch (Deutsch)', seconds: 5));
      await c.check('Server: Deutsch', () => eventually(() async =>
          (await TestBackend.select('profiles', 'select=language&user_id=eq.$annaId')).first['language'] == 'de'));
      await c.snap();

      c.step('Deutsch fest wählen', 'Bei Sprache auf Automatisch (Deutsch) tippen, Deutsch wählen.',
          'Bei Sprache steht jetzt Deutsch statt Automatisch.', kind: 'Abzweigung',
          explain: 'Fest gewählt bleibt Smile auf Deutsch, auch wenn das Handy später eine andere Sprache spricht.');
      await c.dragTo('Automatisch (Deutsch)');
      await tapExact('Automatisch (Deutsch)');
      c.screen('Sprache');
      await tapExact('Deutsch');
      c.screen('Einstellungen');
      await c.check('Nicht mehr automatisch', () => c.gone('Automatisch (Deutsch)', seconds: 3));
      await c.check('Deutsch', () => c.waitFor('Deutsch', seconds: 5));
      await c.snap();

      c.step('Sprache: daneben tippen', 'Bei Sprache auf Deutsch tippen, oben neben die Auswahl tippen.', 'Die Auswahl schließt sich, Deutsch bleibt.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben ändert nichts.');
      await tapExact('Deutsch');
      c.screen('Sprache');
      await c.waitFor('Gilt für die App und die Mitteilungen', seconds: 5);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Einstellungen');
      await c.check('Zu', () async { await c.settle(); return find.byType(RadioListTile<String>).evaluate().isEmpty; });
      await c.snap();

      c.step('Wieder Automatisch', 'Bei Sprache auf Deutsch tippen, Automatisch wählen.', 'Wieder Automatisch (Deutsch).',
          explain: 'Zurück wie vorher.');
      await tapExact('Deutsch');
      c.screen('Sprache');
      await tapExact('Automatisch');
      c.screen('Einstellungen');
      await c.check('Automatisch (Deutsch)', () => c.waitFor('Automatisch (Deutsch)', seconds: 5));
      await c.snap();

      // ================================================================ Sprache am Frame
      Future<List> frameRow() => TestBackend.select('frames', 'select=language&id=eq.${wohnzimmer.id}');
      c.step('Sprache am Frame', 'Zurück, unten Frames, Wohnzimmer, Wiedergabe. Bei Sprache am Frame English antippen.',
          'English ist gewählt; der Frame zeigt Uhr, Hinweise und Knöpfe jetzt auf Englisch.',
          explain: 'Jeder Frame hat seine eigene Sprache, etwa für Großeltern, die eine andere Sprache sprechen als die Familie.');
      await home();
      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await until(FrameRemoteScreen, () => tapExact('Wohnzimmer'));
      c.screen('Fernbedienung');
      await c.letLoad(seconds: 2);
      await c.dragTo('Wiedergabe');
      await tapExact('Wiedergabe');
      c.screen('Wiedergabe');
      await c.check('Sprache am Frame', () => c.dragTo('Wie das Tablet'));
      await tapExact('English');
      await c.check('Server: Englisch', () => eventually(() async => (await frameRow()).first['language'] == 'en'));
      await c.snap();

      c.step('Frame: Deutsch, dann wie das Tablet', 'Deutsch antippen, dann Wie das Tablet.',
          'Zuerst Deutsch, am Ende wieder Wie das Tablet.', kind: 'Abzweigung', explain: 'Ohne Wahl spricht der Frame die Sprache des Tablets.');
      await tapExact('Deutsch');
      await c.check('Server: Deutsch', () => eventually(() async => (await frameRow()).first['language'] == 'de'));
      await tapExact('Wie das Tablet');
      await c.check('Server: wie das Tablet', () => eventually(() async => (await frameRow()).first['language'] == null));
      await c.snap();

      c.step('Bild des Frames: Auswahl', 'Zurück, oben auf das runde Bild von Wohnzimmer tippen, dann neben die Auswahl.',
          'Unten die Auswahl für das Bild; ein Tipp daneben schließt sie, nichts ändert sich.', kind: 'Abzweigung',
          explain: 'Wie ein Space hat auch ein Frame ein Bild.');
      await c.back();
      c.screen('Fernbedienung');
      // The picture is at the very top; the page is still scrolled down to Wiedergabe.
      await c.dragTo('Bild ändern', up: false);
      await c.tap('Bild ändern');
      c.screen('Bild für den Space');
      await c.check('Auswahl', () => c.waitFor('Vorhandenes Bild', seconds: 5));
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Fernbedienung');
      await c.check('Zu', () => c.gone('Vorhandenes Bild', seconds: 3));
      await c.snap();

      // ================================================================ Töne im Album
      c.step('Töne im Album ausschalten', 'Zurück zur Startseite, ⋮, Einstellungen, nach unten zu Töne, den Schalter bei Töne im Album antippen.',
          'Töne im Album ist aus.', explain: 'Ein Plopp beim Senden und bei neuen Fotos im offenen Album. Ist das Handy lautlos, bleibt Smile ohnehin still.');
      await home();
      await openSettings();
      if (!await c.dragTo('Töne im Album', up: false)) await c.dragTo('Töne im Album');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Töne im Album'));
      c.logTap('Töne im Album');
      await c.settle();
      await c.check('Aus', () => !tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Töne im Album')).value);
      await c.snap();

      c.step('Senden ohne Ton', 'Zurück, Geburtstage, ein Foto (Katze) senden.', 'Das Foto kommt an, ohne Plopp.',
          explain: 'Die Testsuite hört mit, welche Töne Smile abspielen will: keinen.');
      sounds.clear();
      var before = await mediaCount();
      await openAlbum();
      await sendPhoto('Katze');
      await c.check('Server: angekommen', () => eventually(() async => await mediaCount() == before + 1, seconds: 60));
      await c.check('Kein Ton', () async {
        await c.letLoad(seconds: 1);
        return sounds.isEmpty;
      });
      await c.snap();

      c.step('Töne wieder an, senden', 'Einstellungen, Töne im Album wieder an, dann in Geburtstage ein Foto (Pizza) senden.',
          'Das Foto kommt an, mit einem leisen Plopp.', explain: 'Ein Plopp pro gesendetem Foto oder Video.');
      await openSettings();
      if (!await c.dragTo('Töne im Album', up: false)) await c.dragTo('Töne im Album');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Töne im Album'));
      c.logTap('Töne im Album');
      await c.settle();
      await c.check('An', () => tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Töne im Album')).value);
      before = await mediaCount();
      await openAlbum();
      await sendPhoto('Pizza');
      await c.check('Server: angekommen', () => eventually(() async => await mediaCount() == before + 1, seconds: 60));
      await c.check('Ein Plopp', () => eventually(() => sounds.length == 1 && sounds.single == 'send', seconds: 5));
      await c.snap();

      // ================================================================ Datenschutz vor der Anmeldung
      c.step('Datenschutz vor der Anmeldung', 'Einstellungen, Abmelden, bestätigen; auf der Anmeldung unten Datenschutzerklärung antippen.',
          'Der Browser öffnet smileapp.app/datenschutz.html.',
          explain: 'Die Datenschutzerklärung ist schon vor dem ersten Anmelden erreichbar.');
      await openSettings();
      await c.dragTo('Abmelden');
      await c.tap('Abmelden');
      c.screen('Abmelden-Frage');
      await c.waitFor('Möchtest du dich wirklich abmelden', seconds: 5);
      await c.tap('Abmelden', last: true);
      c.screen('Anmeldung');
      await c.waitFor('Code anfordern', seconds: 10);
      await c.hideKeyboard();
      launch.urls.clear();
      await tester.tapOnText(find.textRange.ofSubstring('Datenschutzerklärung'));
      c.logTap('Datenschutzerklärung');
      await c.settle();
      await c.check('Datenschutz', () => launch.urls.lastOrNull == 'https://smileapp.app/datenschutz.html');
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
