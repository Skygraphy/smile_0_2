// Kapitel 14: Frame-Admin und Alben anlegen (tools/testsuite, 2026-11-26).
// Startet dort, wo Kapitel 5 endet, dazu Annas Frame Wohnzimmer und Lenas
// Frame Kinderzimmer in Familie Huber (ohne Tablet: es geht nur um Rechte).
// Lena hat kein Gerät: sie handelt per Skript, mit eigener Anmeldung und nur
// ihren eigenen Rechten, wie die App für sie.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/frame_remote_screen.dart';
import 'package:smile_app/screens/frames_screen.dart';
import 'package:smile_app/screens/news_screen.dart';
import 'package:smile_app/screens/space_info_screen.dart';
import 'package:smile_app/screens/spaces_screen.dart';
import 'package:smile_app/services/frame_controls.dart';
import 'package:smile_app/services/frame_service.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 14: Frame-Admin und Alben anlegen', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch14',
        title: 'Frame-Admin und Alben anlegen',
        intro: 'Zwei Rechte, die man einzeln vergibt, ohne gleich Co-Admin zu werden. Frame-Admin: bestimmt bei einem Frame, '
            'was dort bedient werden darf und welche Alben laufen, etwa die Mutter beim Frame ihres Kindes. Darf Alben anlegen: '
            'legt in einem fremden Space eigene Alben an und verwaltet sie. Anna vergibt beides in Familie Berger an Lena und '
            'bekommt beides von Lena in Familie Huber.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 5 + Frames)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter5(tester);
      final berger = seed.spaceId;
      final frames = FrameService();
      final wohnzimmer = await frames.createFrame(spaceId: berger, name: 'Wohnzimmer');
      await frames.updateSettings(frameId: wohnzimmer.id, changes: FrameControlLevels.update(FrameControlLevels.preset(1)));
      await frames.assignChannel(frameId: wohnzimmer.id, channelId: seed.albums['Sommerurlaub 2026']!);
      await frames.setRevoked(frameId: wohnzimmer.id, revoked: false);
      final annaId = await TestBackend.userId(anna);
      final lena = await TestUser.signIn(lenaMail);
      final huber = (await TestBackend.select('spaces', 'select=id&name=eq.Familie%20Huber')).first['id'] as String;
      final kinder = (await lena.edge('create-frame', {'space_id': huber, 'name': 'Kinderzimmer'}))['frame_id'] as String;
      await lena.edge('assign-frame-channel', {'frame_id': kinder, 'channel_id': seed.albums['Wanderungen']!});
      await lena.patch('frames', 'id=eq.$kinder', {'lifecycle_state': 'active'});

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<List> frameInvites(String frame, String userId) =>
          TestBackend.select('frame_admin_invites', 'select=id,status&frame_id=eq.$frame&invitee_user_id=eq.$userId&order=requested_at.asc');
      Future<bool> isFrameAdmin(String frame, String userId) async =>
          (await TestBackend.select('frame_admins', 'select=user_id&frame_id=eq.$frame&user_id=eq.$userId')).isNotEmpty;
      Future<List> creatorInvites(String space, String userId) => TestBackend.select(
          'space_album_creator_invites', 'select=id,status&space_id=eq.$space&invitee_user_id=eq.$userId&order=requested_at.asc');
      Future<bool> isCreator(String space, String userId) async =>
          (await TestBackend.select('space_album_creators', 'select=user_id&space_id=eq.$space&user_id=eq.$userId')).isNotEmpty;

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

      /// Back to the start page (Alben), wherever the app is.
      Future<void> home() async {
        for (var i = 0; i < 6 && (app.navigatorKey.currentState?.canPop() ?? false); i++) {
          await c.back();
        }
        await tapExact('Alben');
        c.screen('Startseite');
        await c.waitFor('Neuigkeiten', seconds: 10);
      }

      Future<void> openNews() async {
        await until(NewsScreen, () => c.tap('Neuigkeiten', seconds: 10));
        c.screen('Neuigkeiten');
      }

      Future<void> openFrame(String name) async {
        await until(FramesScreen, () => tapExact('Frames'));
        c.screen('Frames');
        await until(FrameRemoteScreen, () => tapExact(name));
        c.screen('Fernbedienung');
        await c.letLoad(seconds: 2);
      }

      Future<void> openSpace(String name) async {
        await until(SpacesScreen, () => tapExact('Spaces'));
        c.screen('Spaces');
        await until(SpaceInfoScreen, () => c.tap(name, last: true));
        c.screen('Space');
        await c.waitFor('Admins', seconds: 10);
      }

      Future<void> typeCode(String code) async {
        await tester.enterText(find.byType(TextField).last, code);
        c.logTap('Eingabefeld: Code');
        await c.settle();
        await tester.tap(find.text('OK').last, warnIfMissed: false);
        c.logTap('OK');
        await c.settle();
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

      // ================================================================ Lena wird Frame-Admin von Wohnzimmer
      c.step('Ausgangslage', 'Unten auf Frames, dann Wohnzimmer, nach unten zu Frame-Admin.',
          'Die Fernbedienung von Wohnzimmer. Unter FRAME-ADMIN: Jemand, der diesen Frame mitbestimmt … und Frame-Admin einladen.',
          explain: 'Noch hat niemand außer Anna bei diesem Frame etwas zu sagen.');
      await openFrame('Wohnzimmer');
      await c.dragTo('Frame-Admin einladen');
      await c.check('Erklärung', () => c.waitFor('~Jemand, der diesen Frame mitbestimmt', seconds: 3));
      await c.check('Server: noch niemand', () async => (await frameInvites(wohnzimmer.id, lena.id)).isEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Frame-Admin einladen', 'Frame-Admin einladen antippen.',
          'Frame-Admin von Wohnzimmer: Suchfeld, Lena und Tom, dazu QR-Code zeigen und Per E-Mail einladen.',
          explain: 'Wie bei Co-Admin: per Name, per QR-Code vor Ort oder per E-Mail. Einen weitergeleiteten Link gibt es hier nicht.');
      await tapExact('Frame-Admin einladen');
      c.screen('Einladen');
      await c.check('Titel', () => c.waitFor('Frame-Admin von Wohnzimmer', seconds: 5));
      await c.check('Lena wählbar', () => c.waitFor('Lena Huber', seconds: 8));
      await c.check('QR-Code', () => c.waitFor('QR-Code zeigen', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Lena einladen', 'Lena Huber antippen.',
          'Unten kurz Einladung an Lena Huber gesendet. Bei Frame-Admin steht Lena mit Eingeladen, noch nicht angenommen.',
          explain: 'Lena entscheidet selbst, ob sie den Frame mitbestimmen will.');
      await c.tap('Lena Huber', last: true, seconds: 8);
      c.screen('Fernbedienung');
      await c.check('Meldung', () => c.waitFor('Einladung an Lena Huber gesendet', seconds: 5));
      await c.check('Server: eingeladen', () => eventually(() async => (await frameInvites(wohnzimmer.id, lena.id)).lastOrNull?['status'] == 'pending'));
      await c.check('Wartet', () => c.dragTo('Eingeladen, noch nicht angenommen'));
      await c.snap();

      c.clearMessages();
      c.step('Einladung zurückziehen', 'Lena antippen, dann Einladung zurückziehen.', 'Lena verschwindet; wieder Frame-Admin einladen.',
          kind: 'Abzweigung', explain: 'Solange Lena nicht angenommen hat, kann Anna es sich anders überlegen.');
      await tapExact('Eingeladen, noch nicht angenommen');
      c.screen('Frame-Admin');
      await tapExact('Einladung zurückziehen');
      c.screen('Fernbedienung');
      await c.check('Weg', () => c.gone('Eingeladen, noch nicht angenommen', seconds: 10));
      await c.check('Server: keine Einladung', () => eventually(() async => (await frameInvites(wohnzimmer.id, lena.id)).isEmpty));
      await c.snap();

      c.clearMessages();
      c.step('Lena nimmt an', 'Noch einmal Frame-Admin einladen, Lena Huber antippen. Lena nimmt auf ihrem Handy an.',
          'Bei Frame-Admin steht Lena Huber mit dem Abzeichen Frame-Admin, darunter Weitere Person einladen.',
          explain: 'Lena bestimmt jetzt bei Wohnzimmer die Bedienung und welche Alben laufen. Name, Gerät und Löschen bleiben bei Anna.');
      await c.dragTo('Frame-Admin einladen');
      await tapExact('Frame-Admin einladen');
      c.screen('Einladen');
      await c.tap('Lena Huber', last: true, seconds: 8);
      c.screen('Fernbedienung');
      await c.check('Server: eingeladen', () => eventually(() async => (await frameInvites(wohnzimmer.id, lena.id)).lastOrNull?['status'] == 'pending'));
      final lenaInvite = (await frameInvites(wohnzimmer.id, lena.id)).last['id'] as String;
      await lena.patch('frame_admin_invites', 'id=eq.$lenaInvite', {'status': 'accepted'});
      await c.check('Server: Lena ist Frame-Admin', () => eventually(() => isFrameAdmin(wohnzimmer.id, lena.id)));
      await c.check('Wartet nicht mehr', () => c.gone('Eingeladen, noch nicht angenommen', seconds: 20));
      await c.check('Weitere Person einladen', () => c.dragTo('Weitere Person einladen'));
      await c.check('Abzeichen', () => c.waitFor('Frame-Admin', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Schon Frame-Admin', 'Weitere Person einladen antippen, im Suchfeld Lena eingeben, Lena antippen.',
          'In der Liste steht nur Tom. Mit der Suche erscheint Lena ausgegraut mit Schon Frame-Admin oder Admin; ein Tipp tut nichts.',
          kind: 'Abzweigung', explain: 'Wer schon Frame-Admin ist, steht gar nicht erst zur Wahl. Niemand wird doppelt eingeladen.');
      await tapExact('Weitere Person einladen');
      c.screen('Einladen');
      await c.check('Nur Tom', () async => await c.waitFor('Tom Berger', seconds: 8) && c.find_('Lena Huber').evaluate().length == 1);
      await c.typeInto('', 'Lena', logAs: 'Eingabefeld: Suche');
      await c.check('Hinweis', () => c.waitFor('~Schon Frame-Admin oder Admin', seconds: 8));
      await c.tap('Lena Huber', last: true, seconds: 3);
      await c.check('Server: keine neue Einladung', () async => (await frameInvites(wohnzimmer.id, lena.id)).length == 1);
      await c.check('Server: Tom nicht eingeladen', () async => (await frameInvites(wohnzimmer.id, await TestBackend.userId(tomMail))).isEmpty);
      await c.hideKeyboard();
      await c.snap();
      await backTo(FrameRemoteScreen);
      if (c.find_('Frame-Admin von Wohnzimmer').evaluate().isNotEmpty) await c.back();
      c.screen('Fernbedienung');

      c.clearMessages();
      c.step('Frame-Admin beenden: Abbrechen', 'Lena antippen, Frame-Admin beenden, dann Abbrechen.', 'Lena bleibt Frame-Admin.',
          kind: 'Abzweigung', explain: 'Vor dem Beenden fragt Smile nach.');
      await c.dragTo('Lena Huber');
      await tapExact('Lena Huber');
      c.screen('Frame-Admin');
      await c.check('Was Lena darf', () => c.waitFor('~Bestimmt die Bedienung und welche Alben laufen', seconds: 5));
      await tapExact('Frame-Admin beenden');
      c.screen('Frage');
      await c.check('Frage', () => c.waitFor('Lena Huber als Frame-Admin beenden?', seconds: 5));
      await c.tap('Abbrechen', last: true);
      c.screen('Fernbedienung');
      await c.check('Server: bleibt', () async => isFrameAdmin(wohnzimmer.id, lena.id));
      await c.snap();

      c.clearMessages();
      c.step('Frame-Admin beenden', 'Lena antippen, Frame-Admin beenden, in der Frage Frame-Admin beenden.',
          'Lena verschwindet; wieder der Erklärtext und Frame-Admin einladen.',
          explain: 'Der Frame läuft weiter wie eingestellt; Lena bestimmt nur nicht mehr darüber.');
      await tapExact('Lena Huber');
      c.screen('Frame-Admin');
      await tapExact('Frame-Admin beenden');
      c.screen('Frage');
      await tapExact('Frame-Admin beenden');
      c.screen('Fernbedienung');
      await c.check('Server: nicht mehr', () => eventually(() async => !await isFrameAdmin(wohnzimmer.id, lena.id)));
      await c.check('Wieder einladen', () => c.dragTo('Frame-Admin einladen'));
      await c.snap();

      // ================================================================ Anna wird Frame-Admin bei Lena
      c.clearMessages();
      c.step('Einladung von Lena', 'Lena macht Anna zum Frame-Admin ihres Frames Kinderzimmer. Zurück zur Startseite, Neuigkeiten.',
          'Unter Einladungen: Kinderzimmer, Lena Huber möchte dich zum Frame-Admin machen …, mit Annehmen und Ablehnen.',
          explain: 'Lenas Frame steht in Familie Huber, wo Anna nur in einem Album ist. Als Frame-Admin bestimmt sie trotzdem mit.');
      await lena.edge('invite-frame-admin', {'frame_id': kinder, 'user_id': annaId});
      await home();
      await openNews();
      await c.check('Einladung', () => c.waitFor('~möchte dich zum Frame-Admin machen', seconds: 20));
      await c.check('Frame', () => c.waitFor('Kinderzimmer', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Frame-Admin annehmen', 'Rechts auf das Häkchen (Annehmen) tippen.',
          'Unten kurz Du bist jetzt Frame-Admin von Kinderzimmer. Die Einladung verschwindet.', explain: 'Anna hat angenommen.');
      await c.tap('Annehmen');
      await c.check('Meldung', () => c.waitFor('Du bist jetzt Frame-Admin von Kinderzimmer.', seconds: 8));
      await c.check('Server: Anna ist Frame-Admin', () => eventually(() => isFrameAdmin(kinder, annaId)));
      await c.snap();

      c.clearMessages();
      c.step('Kinderzimmer bei Frames', 'Zurück, unten auf Frames.',
          'Wohnzimmer und Kinderzimmer; bei Kinderzimmer das Abzeichen Frame-Admin.',
          explain: 'Das Abzeichen zeigt Frames, die Anna für jemand anderen bedient.');
      await home();
      await until(FramesScreen, () => tapExact('Frames'));
      c.screen('Frames');
      await c.check('Kinderzimmer', () => c.waitFor('Kinderzimmer', seconds: 15));
      await c.check('Abzeichen', () => c.waitFor('Frame-Admin', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Kinderzimmer als Frame-Admin', 'Kinderzimmer antippen, dann oben rechts auf die drei Punkte.',
          'Die Fernbedienung von Kinderzimmer mit Bedienung am Frame und Wiedergabe. Im Menü fehlt Bild ändern.',
          explain: 'Bild, Name, Gerät und Löschen bleiben bei Lena als Admin von Familie Huber.');
      await until(FrameRemoteScreen, () => tapExact('Kinderzimmer'));
      c.screen('Fernbedienung');
      await c.letLoad(seconds: 2);
      await c.check('Bedienung am Frame', () => c.dragTo('Bedienung am Frame'));
      await menu();
      c.screen('Menü der Fernbedienung');
      await c.check('Kein Bild ändern', () => c.never('Bild ändern', seconds: 2));
      await c.snap();
      await c.back();
      c.screen('Fernbedienung');

      c.clearMessages();
      c.step('Frame-Admin: Du', 'Nach unten zu Frame-Admin.', 'Dort steht Du mit dem Abzeichen Frame-Admin; Einladen gibt es hier nicht.',
          explain: 'Nur Admin und Co-Admins von Familie Huber laden weitere Frame-Admins ein.');
      await c.check('Du', () => c.dragTo('Du'));
      await c.check('Kein Einladen', () => c.never('Weitere Person einladen', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Code als Frame-Admin', 'Weiter unten Code festlegen, 4711 eingeben, OK, noch einmal 4711, OK.',
          'Unten kurz Code gespeichert; Ein Code ist festgelegt.',
          explain: 'Den Code für die Kindersperre dürfen Frame-Admins selbst festlegen, so wie die Mutter beim Frame ihres Kindes.');
      await c.dragTo('Code festlegen');
      await tapExact('Code festlegen');
      c.screen('Code festlegen');
      await typeCode('4711');
      await typeCode('4711');
      c.screen('Fernbedienung');
      await c.check('Meldung', () => c.waitFor('Code gespeichert', seconds: 5));
      await c.check('Server: Code als Hash', () => eventually(() async =>
          (await TestBackend.select('frames', 'select=unlock_code_hash&id=eq.$kinder')).first['unlock_code_hash'] != null));
      await c.snap();

      c.clearMessages();
      c.step('Frame-Admin abgeben', 'Nach oben zu Frame-Admin, Du antippen, Frame-Admin abgeben, in der Frage Frame-Admin abgeben.',
          'Zurück bei Frames; Kinderzimmer ist nicht mehr da.',
          explain: 'Wer nicht mehr mitbestimmen will, gibt das Recht selbst ab. Der Frame läuft weiter wie eingestellt.');
      await c.dragTo('Du', up: false);
      await tapExact('Du');
      c.screen('Frame-Admin');
      await tapExact('Frame-Admin abgeben');
      c.screen('Frage');
      await tapExact('Frame-Admin abgeben');
      c.screen('Frames');
      await c.check('Server: nicht mehr', () => eventually(() async => !await isFrameAdmin(kinder, annaId)));
      await c.check('Zurück bei Frames', () => eventually(() => find.byType(FrameRemoteScreen).evaluate().isEmpty));
      await c.check('Kinderzimmer weg', () => c.gone('Kinderzimmer', seconds: 15));
      await c.snap();

      // ================================================================ Anna darf bei Lena Alben anlegen
      c.clearMessages();
      c.step('Einladung: Alben anlegen', 'Lena lädt Anna ein, in Familie Huber eigene Alben anzulegen. Zurück zur Startseite, Neuigkeiten.',
          'Unter Einladungen: Familie Huber, Lena Huber lädt dich ein, hier eigene Alben anzulegen …',
          explain: 'Anna wird damit nicht Co-Admin: Lenas Alben, Frames und der Space bleiben bei Lena.');
      await lena.edge('invite-album-creator', {'space_id': huber, 'user_id': annaId});
      await home();
      await openNews();
      await c.check('Einladung', () => c.waitFor('~lädt dich ein, hier eigene Alben anzulegen', seconds: 20));
      await c.snap();

      c.clearMessages();
      c.step('Alben anlegen annehmen', 'Rechts auf das Häkchen (Annehmen) tippen.', 'Unten kurz Du kannst jetzt in Familie Huber Alben anlegen.',
          explain: 'Anna hat angenommen.');
      await c.tap('Annehmen');
      await c.check('Meldung', () => c.waitFor('Du kannst jetzt in Familie Huber Alben anlegen.', seconds: 8));
      await c.check('Server: darf Alben anlegen', () => eventually(() => isCreator(huber, annaId)));
      await c.snap();

      c.clearMessages();
      c.step('Familie Huber bei Spaces', 'Zurück, unten auf Spaces.', 'Familie Berger und Familie Huber, bei Huber: Legt eigene Alben an.',
          explain: 'Für Familie Huber gibt es keine Einstellungen, nur den Weg hinaus.');
      await home();
      await until(SpacesScreen, () => tapExact('Spaces'));
      c.screen('Spaces');
      await c.check('Familie Huber', () => c.waitFor('Familie Huber', seconds: 10));
      await c.check('Legt eigene Alben an', () => c.waitFor('Legt eigene Alben an', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Neues Album: wohin?', 'Zurück zur Startseite, drei Punkte oben rechts, Neues Album.',
          'Unten die Frage Neues Album in … mit Familie Berger und Familie Huber.',
          explain: 'Mit zwei Spaces fragt Smile, wohin das Album soll.');
      await home();
      await c.tap('Weitere Optionen');
      c.screen('Menü');
      await c.tap('Neues Album');
      c.screen('Neues Album in …');
      await c.check('Frage', () => c.waitFor('Neues Album in …', seconds: 5));
      await c.check('Familie Huber', () => c.waitFor('Familie Huber', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Neues Album in …: daneben tippen', 'Oben neben die Frage tippen, dann noch einmal drei Punkte und Neues Album.',
          'Die Frage schließt sich, nichts wird angelegt; danach ist sie wieder da.', kind: 'Abzweigung',
          explain: 'Ein Tipp daneben bricht ab.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Startseite');
      await c.check('Zu', () => c.gone('Neues Album in …', seconds: 3));
      await c.tap('Weitere Optionen');
      c.screen('Menü');
      await c.tap('Neues Album');
      c.screen('Neues Album in …');
      await c.check('Wieder da', () => c.waitFor('Neues Album in …', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Album in Familie Huber', 'Familie Huber antippen, Kletterkurs eingeben und Anlegen antippen.',
          'Das Fenster zeigt in Familie Huber; danach öffnet sich das leere Album Kletterkurs.',
          explain: 'Das Album gehört Anna, liegt aber in Lenas Space. Anna verwaltet es selbst.');
      await tapExact('Familie Huber');
      c.screen('Neues Album');
      await c.check('In Familie Huber', () => c.waitFor('in Familie Huber', seconds: 5));
      await c.typeInto('Name', 'Kletterkurs');
      await c.tap('Anlegen', last: true);
      c.screen('Album (leer)');
      await c.check('Album offen', () async => await c.waitFor('Noch keine Fotos', seconds: 10) && await c.waitFor('Kletterkurs', seconds: 2));
      await c.check('Server: in Familie Huber, von Anna', () => eventually(() async {
            final rows = await TestBackend.select('channels', 'select=space_id,created_by&name=eq.Kletterkurs');
            return rows.length == 1 && rows.first['space_id'] == huber && rows.first['created_by'] == annaId;
          }));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Alben anlegen zurückgeben: Abbrechen', 'Zurück, unten Spaces, Familie Huber antippen, dann Abbrechen.',
          'Die Frage Alben anlegen zurückgeben; nach Abbrechen bleibt alles.', kind: 'Abzweigung',
          explain: 'Vor dem Zurückgeben fragt Smile nach.');
      await home();
      await until(SpacesScreen, () => tapExact('Spaces'));
      c.screen('Spaces');
      await c.tap('Legt eigene Alben an', last: true);
      c.screen('Frage');
      await c.check('Frage', () => c.waitFor('Alben anlegen zurückgeben', seconds: 5));
      await c.tap('Abbrechen', last: true);
      c.screen('Spaces');
      await c.check('Server: bleibt', () async => isCreator(huber, annaId));
      await c.snap();

      c.clearMessages();
      c.step('Alben anlegen zurückgeben', 'Familie Huber antippen, in der Frage Alben anlegen zurückgeben.',
          'Familie Huber verschwindet aus Spaces. Kletterkurs bleibt auf der Startseite.',
          explain: 'Anna legt dort keine neuen Alben mehr an; Kletterkurs bleibt, Anna ist darin Mitglied.');
      await c.tap('Legt eigene Alben an', last: true);
      c.screen('Frage');
      await tapExact('Alben anlegen zurückgeben');
      c.screen('Spaces');
      await c.check('Server: nicht mehr', () => eventually(() async => !await isCreator(huber, annaId)));
      await c.check('Familie Huber weg', () => c.gone('Familie Huber', seconds: 10));
      await home();
      await c.check('Kletterkurs bleibt', () => c.waitFor('Kletterkurs', seconds: 10));
      await c.snap();

      // ================================================================ Lena darf bei Anna Alben anlegen
      c.clearMessages();
      c.step('Dürfen Alben anlegen', 'Unten Spaces, Familie Berger, nach unten zu Dürfen Alben anlegen.',
          'Dort: Noch niemand. Wen du einlädst, kann hier eigene Alben anlegen …, darunter Jemanden einladen.',
          explain: 'In Annas eigenem Space vergibt Anna das Recht.');
      await openSpace('Familie Berger');
      await c.check('Abschnitt', () => c.dragTo('Dürfen Alben anlegen'));
      await c.check('Noch niemand', () => c.dragTo('~Noch niemand. Wen du einlädst'));
      await c.snap();

      c.clearMessages();
      c.step('Lena einladen (Alben anlegen)', 'Jemanden einladen antippen, Lena Huber antippen.',
          'Bei Dürfen Alben anlegen steht Lena Huber mit Eingeladen · Annahme ausstehend.',
          explain: 'Auch dieses Recht gibt es nur per eigener Einladung: Wer in einem Album ist, bekommt es nie von selbst.');
      await c.dragTo('Jemanden einladen');
      await tapExact('Jemanden einladen');
      c.screen('Einladen');
      await c.check('Titel', () => c.waitFor('Alben anlegen in Familie Berger', seconds: 5));
      await c.tap('Lena Huber', last: true, seconds: 8);
      c.screen('Space');
      await c.check('Server: eingeladen', () => eventually(() async => (await creatorInvites(berger, lena.id)).lastOrNull?['status'] == 'pending'));
      await c.check('Wartet', () => c.dragTo('Eingeladen · Annahme ausstehend'));
      await c.snap();

      c.clearMessages();
      c.step('Lena nimmt an (Alben anlegen)', 'Nichts tun: Lena nimmt auf ihrem Handy an.',
          'Bei Lena steht jetzt Legt eigene Alben an.', explain: 'Lena kann in Familie Berger eigene Alben anlegen.');
      final creatorInvite = (await creatorInvites(berger, lena.id)).last['id'] as String;
      await lena.patch('space_album_creator_invites', 'id=eq.$creatorInvite', {'status': 'accepted'});
      await c.check('Server: darf', () => eventually(() => isCreator(berger, lena.id)));
      await c.check('Legt eigene Alben an', () => c.waitFor('Legt eigene Alben an', seconds: 20));
      await c.snap();

      c.clearMessages();
      c.step('Recht wegnehmen', 'Lena antippen, Recht wegnehmen.',
          'Lena verschwindet bei Dürfen Alben anlegen; wieder Noch niemand.',
          explain: 'Lena bleibt in ihren Alben Mitglied; sie legt nur keine neuen mehr an.');
      await c.tap('Legt eigene Alben an', last: true);
      c.screen('Lena');
      await tapExact('Recht wegnehmen');
      c.screen('Space');
      await c.check('Server: nicht mehr', () => eventually(() async => !await isCreator(berger, lena.id)));
      await c.check('Wieder niemand', () => c.waitFor('~Noch niemand. Wen du einlädst', seconds: 10));
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
