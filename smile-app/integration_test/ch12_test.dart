// Kapitel 12: Aufräumen (tools/testsuite, 2026-10-27).
// Startet dort, wo Kapitel 5 endet, dazu der Frame Wohnzimmer auf dem X200
// (ch12f_test.dart), Paul als Co-Admin von Familie Berger und Annas zweiter
// Space Ferienwohnung mit dem Album Ostsee (Tom ist darin). Paul, Lena und
// Tom haben kein Gerät: was sie erfahren, steht in ihrem Verlauf.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/album_info_screen.dart';
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/create_frame_screen.dart';
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frame_settings_screen.dart';
import 'package:smile_app/screens/frames_screen.dart';
import 'package:smile_app/screens/news_screen.dart';
import 'package:smile_app/screens/settings_screen.dart';
import 'package:smile_app/screens/space_info_screen.dart';
import 'package:smile_app/screens/spaces_screen.dart';
import 'package:smile_app/screens/trash_screen.dart';
import 'package:smile_app/services/channel_service.dart';
import 'package:smile_app/services/frame_controls.dart';
import 'package:smile_app/services/frame_service.dart';
import 'package:smile_app/services/membership_service.dart';
import 'package:smile_app/services/preferred_frame.dart';
import 'package:smile_app/services/space_service.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 12: Aufräumen', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch12',
        title: 'Aufräumen',
        intro: 'Anna räumt auf: Sie löscht den Frame Wohnzimmer, ein Album und einen ganzen Space und holt beides aus dem '
            'Papierkorb zurück. Zum Schluss löscht sie ihr Smile-Konto. Was dabei mit Oma Hildes Tablet, mit den Alben der '
            'anderen und mit Annas Spaces passiert, zeigt dieses Kapitel.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter5(tester);
      final berger = seed.spaceId;
      final birthdays = seed.albums['Geburtstage']!;
      final annaId = await TestBackend.userId(anna);
      final paul = await TestUser.signIn(paulMail);
      final lena = await TestUser.signIn(lenaMail);
      final tom = await TestUser.signIn(tomMail);
      // Paul helps managing Familie Berger (chapter 9 shows how).
      await SpaceService().inviteCoOwner(spaceId: berger, userId: paul.id);
      final paulInvite = (await TestBackend.select(
              'space_co_owner_invites', 'select=id&space_id=eq.$berger&invitee_user_id=eq.${paul.id}&status=eq.pending'))
          .first['id'];
      await paul.patch('space_co_owner_invites', 'id=eq.$paulInvite', {'status': 'accepted'});
      // Anna's second Space, Ferienwohnung, with the album Ostsee; Tom is in it.
      final holiday = await SpaceService().createSpace('Ferienwohnung');
      final baltic = await ChannelService().createChannel(spaceId: holiday, name: 'Ostsee');
      await MembershipService().inviteMember(channelId: baltic, userId: tom.id);
      final tomInvite = (await tom.select('channel_membership_requests',
              'select=id&status=eq.pending&channel_id=eq.$baltic&user_id=eq.${tom.id}'))
          .first['id'];
      await tom.patch('channel_membership_requests', 'id=eq.$tomInvite', {'status': 'accepted'});
      // The Frame Wohnzimmer, as at the end of chapter 6 (the tablet pairs itself).
      final frames = FrameService();
      final created = await frames.createFrame(spaceId: berger, name: 'Wohnzimmer');
      await frames.updateSettings(frameId: created.id, changes: FrameControlLevels.update(FrameControlLevels.preset(1)));
      await frames.assignChannel(frameId: created.id, channelId: seed.albums['Sommerurlaub 2026']!);
      await frames.assignChannel(frameId: created.id, channelId: birthdays);
      await frames.showChannelNow(frameId: created.id, channelId: birthdays);
      await c.awaitSignal('f0', seconds: 300);

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<bool> hasEntry(String userId, String body) async => (await TestBackend.select(
              'user_notifications', 'select=body&user_id=eq.$userId'))
          .any((r) => (r as Map)['body'] == body);
      Future<String?> deletedAt(String table, String id) async =>
          (await TestBackend.select(table, 'select=deleted_at&id=eq.$id')).first['deleted_at'] as String?;

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

      Future<void> toTop() async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await c.settle();
      }

      /// Back to the start page (Alben), wherever the app is.
      Future<void> home() async {
        bool inside() => [
              SettingsScreen, FrameSettingsScreen, FrameRemoteScreen, CreateFrameScreen, TrashScreen, SpaceInfoScreen,
              AlbumInfoScreen, ChannelFeedScreen, NewsScreen,
            ].any((page) => find.byType(page).evaluate().isNotEmpty);
        // Never back on the first page: that would close Smile.
        bool canPop() => tester.state<NavigatorState>(find.byType(Navigator).first).canPop();
        for (var i = 0; i < 8 && inside() && canPop(); i++) {
          await c.back();
          await c.settle(max: const Duration(seconds: 1));
        }
        await tapExact('Alben');
        c.screen('Startseite');
        await c.waitFor('Wanderungen', seconds: 10);
      }

      Future<void> openSettings() async {
        await c.tap('Weitere Optionen');
        c.screen('Menü');
        await until(SettingsScreen, () => c.tap('Einstellungen', last: true));
        c.screen('Einstellungen');
      }

      Future<void> openSpace(String name) async {
        await until(SpacesScreen, () => tapExact('Spaces'));
        c.screen('Spaces');
        await until(SpaceInfoScreen, () => c.tap(name, last: true));
        c.screen('Space');
        await c.waitFor('Admins', seconds: 10);
      }

      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await c.waitFor('Wohnzimmer', seconds: 10);
      await c.start();

      // ================================================================ Bevorzugter Frame
      c.step('Ausgangslage', 'Unten auf Frames.',
          'Die Frames-Seite: Wohnzimmer mit grünem Punkt, darunter Läuft gerade Geburtstage.',
          explain: 'So endet Kapitel 6. Dazu ist Paul inzwischen Co-Admin von Familie Berger, und Anna hat einen zweiten Space, '
              'die Ferienwohnung mit dem Album Ostsee, in dem Tom ist.');
      await c.check('Läuft gerade Geburtstage', () => c.waitFor('Geburtstage', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Bevorzugter Frame', 'Drei Punkte, Einstellungen, bei Bevorzugter Frame auf Jedes Mal fragen, dann Wohnzimmer.',
          'Bei Bevorzugter Frame steht jetzt Wohnzimmer.',
          explain: 'Dann zeigt ein Tipp auf das Frame-Symbol im Album das Album sofort auf diesem Frame, ohne zu fragen.');
      await openSettings();
      await scrollTo(find.text('Jedes Mal fragen'));
      await c.tap('Jedes Mal fragen');
      c.screen('Bevorzugter Frame');
      await c.waitFor('Wohnzimmer', seconds: 3);
      await tapExact('Wohnzimmer');
      c.screen('Einstellungen');
      await c.check('Wohnzimmer', () => c.waitFor('Wohnzimmer', seconds: 3));
      await c.check('Gemerkt', () async => await PreferredFrame.get() == created.id);
      await c.snap();

      // ================================================================ Frame löschen
      c.clearMessages();
      c.step('Frame löschen: die Frage', 'Zurück, Frames, Wohnzimmer, die Kachel Einstellungen & Gerät, ganz unten Frame löschen.',
          'Frame Wohnzimmer löschen? Der Frame wird endgültig entfernt, das Tablet zeigt wieder den Bildschirm zum Verbinden.',
          explain: 'Abbrechen und daneben tippen zeigt Kapitel 8. Hier wird wirklich gelöscht.');
      await c.back();
      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await until(FrameRemoteScreen, () => tapExact('Wohnzimmer'));
      c.screen('Fernbedienung');
      await scrollTo(c.find_('Einstellungen & Gerät'));
      await until(FrameSettingsScreen, () => c.tap('Einstellungen & Gerät'));
      c.screen('Frame-Seite');
      await scrollTo(c.find_('Frame löschen'));
      await c.tap('Frame löschen');
      c.screen('Frame löschen?');
      await c.check('Frage', () => c.waitFor('Frame Wohnzimmer löschen?', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Frame löschen', 'Löschen antippen.',
          'Der Frame ist weg. Smile zeigt die Startseite; unten gibt es den Reiter Frames nicht mehr, weil Anna keinen Frame mehr hat.',
          explain: 'Endgültig: Das Tablet muss neu verbunden werden, wenn es wieder ein Frame sein soll.');
      await c.tap('Löschen', last: true);
      await c.check('Server: Frame gelöscht', () => eventually(() async =>
          (await TestBackend.select('frames', 'select=id&id=eq.${created.id}')).isEmpty));
      await c.check('Keine Seite des gelöschten Frames', () => eventually(() =>
          find.byType(FrameRemoteScreen).evaluate().isEmpty && find.byType(FrameSettingsScreen).evaluate().isEmpty));
      await c.check('Kein Reiter Frames', () => eventually(() => find.text('Frames').evaluate().isEmpty));
      c.screen('Startseite');
      await c.snap();
      await TestBackend.signal('p1');
      await c.awaitSignal('f1', seconds: 240);

      c.clearMessages();
      c.step('Bevorzugter Frame ist weg', 'Drei Punkte, Einstellungen.', 'Den Abschnitt Bevorzugter Frame gibt es nicht mehr.',
          explain: 'Ohne Frame gibt es nichts zu bevorzugen.');
      await home();
      await openSettings();
      await c.check('Abschnitt weg', () => c.gone('Bevorzugter Frame', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Space ohne Frame', 'Zurück, unten Spaces, Familie Berger.',
          'Bei Frames: 0 Frames, Noch kein Frame und Frame verbinden.', explain: 'Wohnzimmer ist auch hier verschwunden.');
      await home();
      await openSpace('Familie Berger');
      await scrollTo(c.find_('Noch kein Frame'));
      await c.check('Noch kein Frame', () => c.waitFor('Noch kein Frame', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Frame verbinden', 'Auf Frame verbinden tippen.', 'Frame einrichten: ein Name für den neuen Frame.', kind: 'Abzweigung',
          explain: 'Von hier aus könnte Anna das Tablet neu verbinden (Kapitel 6). Sie geht zurück.');
      await until(CreateFrameScreen, () => c.tap('Frame verbinden', last: true));
      c.screen('Frame einrichten');
      await c.check('Frame einrichten', () => c.waitFor('Frame einrichten', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Frame verbinden über das Menü', 'Zurück, oben die drei Punkte, Frame verbinden.', 'Wieder Frame einrichten.',
          kind: 'Abzweigung', explain: 'Derselbe Weg über das Menü des Space.');
      await c.back();
      c.screen('Space');
      await toTop();
      await c.tap('Weitere Optionen');
      c.screen('Menü des Space');
      await until(CreateFrameScreen, () => c.tap('Frame verbinden', last: true));
      c.screen('Frame einrichten');
      await c.check('Frame einrichten', () => c.waitFor('Frame einrichten', seconds: 5));
      await c.snap();

      // ================================================================ Album löschen
      Future<void> openInfo(String album) async {
        await home();
        await until(ChannelFeedScreen, () => c.tap(album));
        c.screen('Album');
        await until(AlbumInfoScreen, () => c.tap(album, last: true));
        c.screen('Album-Infos');
        await c.waitFor('Geteilt mit', seconds: 10);
      }

      c.clearMessages();
      c.step('Album löschen: die Frage', 'Zurück zur Startseite, Geburtstage, oben auf den Namen, ganz unten Album löschen.',
          'Album Geburtstage löschen? Das Album verschwindet mit allen Fotos sofort für alle und von allen Frames; 30 Tage lang '
              'lässt es sich im Papierkorb wiederherstellen.',
          explain: 'Löschen dürfen nur Admin und Co-Admins des Space.');
      await openInfo('Geburtstage');
      await scrollTo(c.find_('Album löschen'));
      await c.tap('Album löschen');
      c.screen('Album löschen?');
      await c.check('Frage', () => c.waitFor('Album Geburtstage löschen?', seconds: 3));
      await c.check('Ganz zu lesen', () => c.fullyShown(
          'Das Album verschwindet mit allen Fotos sofort für alle Personen und von allen Frames. 30 Tage lang kannst du es im Papierkorb wiederherstellen.'));
      await c.snap();

      c.clearMessages();
      c.step('Album löschen: Abbrechen', 'Abbrechen antippen.', 'Die Frage schließt sich, das Album bleibt.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tap('Abbrechen');
      c.screen('Album-Infos');
      await c.check('Server: Album da', () async => await deletedAt('channels', birthdays) == null);
      await c.snap();

      c.clearMessages();
      c.step('Album löschen: daneben tippen', 'Album löschen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, das Album bleibt.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await c.tap('Album löschen');
      c.screen('Album löschen?');
      await c.waitFor('Album Geburtstage löschen?', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Album-Infos');
      await c.check('Zu', () => c.gone('Album Geburtstage löschen?', seconds: 3));
      await c.check('Server: Album da', () async => await deletedAt('channels', birthdays) == null);
      await c.snap();

      c.clearMessages();
      c.step('Album löschen', 'Album löschen, dann Löschen.',
          'Die Startseite, Geburtstage steht nicht mehr da. Lena, Tom und Paul bekommen die Mitteilung Album gelöscht.',
          explain: 'Wer das Album sehen konnte, erfährt es; nichts verschwindet unangekündigt.');
      await c.tap('Album löschen');
      c.screen('Album löschen?');
      await c.waitFor('Album Geburtstage löschen?', seconds: 3);
      await c.tap('Löschen', last: true);
      c.screen('Startseite');
      await c.check('Server: im Papierkorb', () => eventually(() async => await deletedAt('channels', birthdays) != null));
      await c.check('Startseite ohne Geburtstage', () => c.gone('Geburtstage', seconds: 10));
      await c.check('Lena erfährt es', () => eventually(() async => (await TestBackend.select(
              'user_notifications', 'select=body&user_id=eq.${lena.id}&body=like.Anna%20Berger%20hat%20das%20Album%20Geburtstage%20gel*'))
          .isNotEmpty));
      await c.snap();

      c.clearMessages();
      c.step('Papierkorb im Space', 'Unten Spaces, Familie Berger, ganz unten Papierkorb.',
          'Der Papierkorb: Geburtstage, in Familie Berger, gelöscht von Anna Berger, endgültig weg am … (in 30 Tagen), daneben der Knopf zum Wiederherstellen.',
          explain: 'Bis dahin ist nichts verloren: Personen, Freigaben, Frames und Fotos kommen genau so zurück.');
      await openSpace('Familie Berger');
      await scrollTo(c.find_('Papierkorb'));
      await until(TrashScreen, () => c.tap('Papierkorb'));
      c.screen('Papierkorb');
      await c.check('Geburtstage', () => c.waitFor('Geburtstage', seconds: 10));
      await c.check('Gelöscht von Anna', () => c.waitFor('~gelöscht von Anna Berger', seconds: 3));
      await c.check('Ganz zu lesen', () => c.fullyShown(find.textContaining('endgültig weg am').evaluate().isEmpty
          ? ''
          : (tester.widget<Text>(find.textContaining('endgültig weg am').first).data ?? '')));
      await c.snap();

      c.clearMessages();
      c.step('Wiederherstellen', 'Rechts auf Wiederherstellen.',
          'Unten kurz: Geburtstage ist wiederhergestellt. Der Papierkorb ist leer.',
          explain: 'Die anderen bekommen die Mitteilung Album wiederhergestellt.');
      await tester.tap(find.byTooltip('Wiederherstellen').first, warnIfMissed: false);
      c.logTap('Wiederherstellen');
      await c.settle();
      await c.check('Meldung', () => c.waitFor('~ist wiederhergestellt', seconds: 10));
      await c.check('Leer', () => c.waitFor('Der Papierkorb ist leer.', seconds: 10));
      await c.check('Server: zurück', () => eventually(() async => await deletedAt('channels', birthdays) == null));
      await c.check('Lena erfährt es', () => eventually(() => hasEntry(lena.id, 'Anna Berger hat das Album Geburtstage wiederhergestellt.')));
      await c.snap();

      c.clearMessages();
      c.step('Alles wieder da', 'Zweimal zurück, dann unten Alben, Geburtstage öffnen.',
          'Geburtstage mit allen Fotos und Videos wie vorher.', explain: 'Wiederherstellen bringt alles zurück, auch die Fotos.');
      await home();
      await until(ChannelFeedScreen, () => c.tap('Geburtstage'));
      c.screen('Album');
      await c.check('Fotos da', () async =>
          (await TestBackend.select('media_items', 'select=id&channel_id=eq.$birthdays')).length == 5);
      await c.check('Obst für alle', () => c.waitFor('Obst für alle', seconds: 15));
      await c.snap();

      // ================================================================ Space löschen
      c.clearMessages();
      c.step('Space löschen: die Frage', 'Zurück, unten Spaces, Familie Berger, ganz unten Space löschen.',
          'Space Familie Berger löschen? Der Space verschwindet mit allen Alben, Fotos und Frames sofort für alle; 30 Tage lang '
              'lässt er sich wiederherstellen.',
          explain: 'Einen Space löschen darf nur sein Admin.');
      await home();
      await openSpace('Familie Berger');
      await scrollTo(c.find_('Space löschen'));
      await c.tap('Space löschen');
      c.screen('Space löschen?');
      await c.check('Frage', () => c.waitFor('Space Familie Berger löschen?', seconds: 3));
      await c.check('Ganz zu lesen', () => c.fullyShown(
          'Der Space verschwindet mit allen Alben, Fotos und Frames sofort für alle; alle Beteiligten werden benachrichtigt. 30 Tage lang kannst du ihn im Papierkorb wiederherstellen.'));
      await c.snap();

      c.clearMessages();
      c.step('Space löschen: Abbrechen', 'Abbrechen antippen.', 'Die Frage schließt sich, der Space bleibt.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tap('Abbrechen');
      c.screen('Space');
      await c.check('Server: Space da', () async => await deletedAt('spaces', berger) == null);
      await c.snap();

      c.clearMessages();
      c.step('Space löschen: daneben tippen', 'Space löschen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, der Space bleibt.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await c.tap('Space löschen');
      c.screen('Space löschen?');
      await c.waitFor('Space Familie Berger löschen?', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Space Familie Berger löschen?', seconds: 3));
      await c.check('Server: Space da', () async => await deletedAt('spaces', berger) == null);
      await c.snap();

      c.clearMessages();
      c.step('Space löschen', 'Space löschen, dann Löschen.',
          'Die Startseite: Geburtstage, Sommerurlaub 2026 und Weihnachten sind weg, Wanderungen (Lenas Album) und Ostsee bleiben.',
          explain: 'Alle, die den Space oder eines seiner Alben sehen konnten, bekommen die Mitteilung Space gelöscht.');
      await c.tap('Space löschen');
      c.screen('Space löschen?');
      await c.waitFor('Space Familie Berger löschen?', seconds: 3);
      await c.tap('Löschen', last: true);
      await c.check('Server: im Papierkorb', () => eventually(() async => await deletedAt('spaces', berger) != null));
      await c.check('Zurück auf der Startseite', () => eventually(() => find.byType(SpaceInfoScreen).evaluate().isEmpty));
      await home();
      await c.check('Alben weg', () async => await c.gone('Geburtstage', seconds: 10) && await c.gone('Sommerurlaub 2026', seconds: 1));
      await c.check('Wanderungen bleibt', () => c.waitFor('Wanderungen', seconds: 3));
      await c.check('Paul erfährt es', () => eventually(() async => (await TestBackend.select(
              'user_notifications', 'select=body&user_id=eq.${paul.id}&body=like.Anna%20Berger%20hat%20den%20Space%20Familie%20Berger*'))
          .isNotEmpty));
      await c.snap();

      c.clearMessages();
      c.step('Papierkorb in Neuigkeiten', 'Oben auf Neuigkeiten.',
          'Unter Papierkorb: Familie Berger, endgültig weg am … (in 30 Tagen), mit dem Knopf zum Wiederherstellen.',
          explain: 'Ein gelöschter Space hat keine Seite mehr; sein Papierkorb steht darum auch in Neuigkeiten.');
      await until(NewsScreen, () => c.tap('Neuigkeiten'));
      c.screen('Neuigkeiten');
      await c.check('Papierkorb', () => c.waitFor('Papierkorb', seconds: 10));
      await c.check('Familie Berger', () => c.waitFor('Familie Berger', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Space wiederherstellen', 'Bei Familie Berger auf Wiederherstellen.',
          'Unten kurz: Familie Berger ist wiederhergestellt. Zurück auf der Startseite sind die Alben wieder da.',
          explain: 'Mit dem Space kommen alle seine Alben zurück.');
      await tester.tap(find.byTooltip('Wiederherstellen').first, warnIfMissed: false);
      c.logTap('Wiederherstellen');
      await c.settle();
      await c.check('Meldung', () => c.waitFor('~ist wiederhergestellt', seconds: 10));
      await c.check('Server: zurück', () => eventually(() async => await deletedAt('spaces', berger) == null));
      await home();
      await c.check('Alben wieder da', () => c.waitFor('Geburtstage', seconds: 15));
      await c.snap();

      // ================================================================ Konto löschen
      final dialogButton = find.widgetWithText(FilledButton, 'Endgültig löschen');
      bool confirmEnabled() => tester.widget<FilledButton>(dialogButton).onPressed != null;

      c.clearMessages();
      c.step('Konto löschen: die Frage', 'Drei Punkte, Einstellungen, ganz unten Konto löschen.',
          'Konto von Anna Berger löschen? Darunter welches Konto, was alles gelöscht wird, und ein Feld für die E-Mail-Adresse. '
              'Endgültig löschen ist noch grau.',
          explain: 'Damit niemand aus Versehen das falsche Konto löscht, muss man die E-Mail-Adresse eintippen.');
      await openSettings();
      await scrollTo(c.find_('Konto löschen'));
      await c.tap('Konto löschen');
      c.screen('Konto löschen?');
      await c.check('Frage', () => c.waitFor('Konto von Anna Berger löschen?', seconds: 3));
      await c.check('Welches Konto', () => c.waitFor('~anna.berger@example.com', seconds: 1));
      await c.check('Noch grau', () => !confirmEnabled());
      await c.snap();

      c.clearMessages();
      c.step('Falsche Adresse', 'anna@example.com eintippen.', 'Endgültig löschen bleibt grau.', kind: 'Abzweigung',
          explain: 'Nur die genaue Adresse des angemeldeten Kontos gilt.');
      await c.typeInto('', 'anna@example.com', logAs: 'Eingabefeld: anna.berger@example.com');
      await c.check('Noch grau', () => !confirmEnabled());
      await c.snap();

      c.clearMessages();
      c.step('Konto löschen: Abbrechen', 'Abbrechen antippen.', 'Die Frage schließt sich, Anna bleibt angemeldet.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.hideKeyboard();
      await c.tap('Abbrechen');
      c.screen('Einstellungen');
      await c.check('Konto da', () async => (await TestBackend.select('profiles', 'select=user_id&user_id=eq.$annaId')).isNotEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Konto löschen: daneben tippen', 'Konto löschen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, nichts passiert.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await c.tap('Konto löschen');
      c.screen('Konto löschen?');
      await c.waitFor('Konto von Anna Berger löschen?', seconds: 3);
      await c.tapAt(const Offset(200, 60), 'Schließen');
      c.screen('Einstellungen');
      await c.check('Zu', () => c.gone('Konto von Anna Berger löschen?', seconds: 3));
      await c.check('Konto da', () async => (await TestBackend.select('profiles', 'select=user_id&user_id=eq.$annaId')).isNotEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Konto löschen', 'Konto löschen, anna.berger@example.com eintippen, Endgültig löschen.',
          'Smile zeigt wieder die Anmeldung. Paul ist jetzt Admin von Familie Berger; die Ferienwohnung gibt es nicht mehr; '
              'Annas Fotos und Videos sind aus allen Alben verschwunden.',
          explain: 'Spaces mit Co-Admin übernimmt der Co-Admin, Spaces ohne Co-Admin werden mit allen Alben gelöscht. '
              'Paul und Tom bekommen je eine Mitteilung.');
      await c.tap('Konto löschen');
      c.screen('Konto löschen?');
      await c.waitFor('Konto von Anna Berger löschen?', seconds: 3);
      await c.typeInto('', anna, logAs: 'Eingabefeld: anna.berger@example.com');
      await c.check('Jetzt rot', () => confirmEnabled());
      await c.hideKeyboard();
      await c.tap('Endgültig löschen');
      c.screen('Anmeldung');
      await c.check('Anmeldung', () => c.waitFor('Code anfordern', seconds: 30));
      await c.check('Server: Profil weg', () => eventually(() async =>
          (await TestBackend.select('profiles', 'select=user_id&user_id=eq.$annaId')).isEmpty));
      await c.check('Server: Paul ist Admin', () async =>
          (await TestBackend.select('spaces', 'select=owner_id&id=eq.$berger')).first['owner_id'] == paul.id);
      await c.check('Server: Ferienwohnung weg', () async => (await TestBackend.select('spaces', 'select=id&id=eq.$holiday')).isEmpty);
      await c.check('Server: Annas Fotos weg', () async =>
          (await TestBackend.select('media_items', 'select=id&sender_id=eq.$annaId')).isEmpty);
      await c.check('Paul erfährt es', () => eventually(() => hasEntry(paul.id,
          'Anna Berger hat das Smile-Konto gelöscht. Du bist jetzt Admin des Space Familie Berger.')));
      await c.check('Tom erfährt es', () => eventually(() => hasEntry(tom.id,
          'Anna Berger hat das Smile-Konto gelöscht. Den Space Ferienwohnung mit allen Alben gibt es nicht mehr.')));
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
