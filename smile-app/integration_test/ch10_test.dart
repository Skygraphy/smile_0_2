// Kapitel 10: Pushes und Neuigkeiten (tools/testsuite, 2026-10-26).
// Startet dort, wo Kapitel 5 endet. Paul, Lena und Tom haben kein Gerät:
// sie handeln per Skript, mit eigener Anmeldung und nur ihren eigenen
// Rechten. Was bei Anna ankommt, ist echt: der Server schickt die Pushes
// über Firebase an das S26.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/album_info_screen.dart';
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/news_screen.dart';
import 'package:smile_app/screens/space_info_screen.dart';
import 'package:smile_app/services/upload_queue.dart';
import 'package:smile_app/widgets/top_bar_actions.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 10: Pushes und Neuigkeiten', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch10',
        title: 'Pushes und Neuigkeiten',
        intro: 'Was andere tun, erfährt Anna als Mitteilung auf dem Handy und im Verlauf unter Neuigkeiten: neue Fotos, '
            'Einladungen, Anfragen, Antworten und Änderungen an Alben und Spaces. Ein Tipp auf einen Eintrag führt dorthin, '
            'wo es passiert ist. Was Anna selbst tut, meldet Smile ihr nicht.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    // What reaches the phone while Smile is open (the app shows the same as
    // a notification); Android's own list of shown notifications.
    final pushes = <RemoteMessage>[];
    StreamSubscription<RemoteMessage>? listening;
    final tray = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!;
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 5)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      // Only what is shown; the silent sync messages say nothing to the person.
      listening = FirebaseMessaging.onMessage.listen((m) {
        if (m.notification != null) pushes.add(m);
      });
      final seed = await endOfChapter5(tester);
      final birthdays = seed.albums['Geburtstage']!;
      final christmas = seed.albums['Weihnachten']!;
      final hiking = seed.albums['Wanderungen']!;
      final berger = seed.spaceId;
      final annaId = await TestBackend.userId(anna);
      final lena = await TestUser.signIn(lenaMail);
      final tom = await TestUser.signIn(tomMail);
      final huber = (await TestBackend.select('spaces', 'select=id&name=eq.Familie%20Huber')).first['id'] as String;
      final mountains = (await TestBackend.select('channels', 'select=id&name=eq.Bergtouren')).first['id'] as String;
      final media = '${(await getApplicationSupportDirectory()).path}/fixtures/media';
      Future<Uint8List> photo(String file) => File('$media/$file').readAsBytes();

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      /// The Verlauf of a person on the server, newest first.
      Future<List<Map>> history(String userId) async => (await TestBackend.select(
              'user_notifications', 'select=id,title,body,data&user_id=eq.$userId&order=created_at.desc'))
          .cast<Map>();
      Future<bool> hasEntry(String userId, String body) async => (await history(userId)).any((r) => r['body'] == body);

      /// A push with this text reached the phone (since [from]).
      RemoteMessage? pushed(String body, {int from = 0}) =>
          pushes.skip(from).where((m) => m.notification?.body == body).lastOrNull;
      Future<bool> arrives(String body, {int from = 0}) => eventually(() => pushed(body, from: from) != null, seconds: 30);

      /// What Android shows at the top right now (title: text).
      Future<List<String>> shown() async =>
          [for (final n in await tray.getActiveNotifications()) '${n.title}: ${n.body}'];

      Finder newsButton() => find.byType(NewsButton).first;
      bool dot() => tester
          .widget<Badge>(find.descendant(of: newsButton(), matching: find.byType(Badge)).first)
          .isLabelVisible;
      bool coral() =>
          tester.widget<Icon>(find.descendant(of: newsButton(), matching: find.byType(Icon)).first).color != null;

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

      /// Back to the start page (Alben), wherever the app is.
      Future<void> home() async {
        bool inside() => [NewsScreen, AlbumInfoScreen, ChannelFeedScreen, SpaceInfoScreen]
            .any((page) => find.byType(page).evaluate().isNotEmpty);
        for (var i = 0; i < 6 && inside(); i++) {
          await c.back();
        }
        c.screen('Startseite');
        await c.waitFor('Geburtstage', seconds: 10);
      }

      Future<void> openNews() async {
        await until(NewsScreen, () async {
          await tester.tap(newsButton(), warnIfMissed: false);
          c.logTap('Neuigkeiten');
          await c.settle();
        });
        c.screen('Neuigkeiten');
      }

      /// Taps a Verlauf entry by its text; counts as a tap on its kind ([title]).
      Future<void> entry(String body, String title) async {
        if (!await c.waitFor(body, seconds: 20)) throw TestFailure('Kein Eintrag: $body');
        final f = find.text(body);
        await tester.ensureVisible(f.first);
        await c.settle();
        await tester.tap(f.first, warnIfMissed: false);
        c.logTap(title);
        await c.settle();
      }

      /// The notification itself tapped (Android hands its content to Smile,
      /// which opens the same as from the Verlauf).
      Future<void> tapNotification(String body) async {
        app.openNotificationTarget(Map<String, dynamic>.from(pushed(body)!.data));
        await c.settle();
      }

      await c.waitFor('Wanderungen', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Der Verlauf
      c.step('Ausgangslage', 'Oben rechts auf Neuigkeiten (die Glocke) tippen.',
          'Unter Verlauf: zweimal Einladung beantwortet, von Lena und von Tom: sie haben die Einladung ins Album Geburtstage angenommen. '
              'Dazu Lenas Einladung ins Album Wanderungen, die Anna in Kapitel 5 angenommen hat.',
          explain: 'So endet Kapitel 5. Was andere tun, landet als Eintrag im Verlauf, auch wenn Smile gerade zu war. '
              'Einträge bleiben 30 Tage.');
      await c.check('Handy kann Pushes empfangen',
          () => eventually(() async => (await TestBackend.select('user_push_tokens', 'select=id&user_id=eq.$annaId')).isNotEmpty));
      await openNews();
      await c.check('Verlauf', () => c.waitFor('Verlauf', seconds: 10));
      await c.check('Lena', () => c.waitFor('Lena Huber hat die Einladung ins Album Geburtstage angenommen.', seconds: 5));
      await c.check('Tom', () => c.waitFor('Tom Berger hat die Einladung ins Album Geburtstage angenommen.', seconds: 5));
      await c.check('Wanderungen', () => c.waitFor('Du wurdest als Member ins Album Wanderungen eingeladen. Annehmen unter Neuigkeiten.', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Eintrag antippen', 'Auf den Eintrag von Lena tippen.',
          'Die Album-Infos von Geburtstage gehen auf; Lena steht bei den Personen.',
          explain: 'Ein Tipp führt dorthin, wo es passiert ist. Danach ist der Eintrag erledigt und verschwindet.');
      await entry('Lena Huber hat die Einladung ins Album Geburtstage angenommen.', 'Einladung beantwortet');
      c.screen('Album-Infos');
      await c.check('Album-Infos', () => eventually(() => find.byType(AlbumInfoScreen).evaluate().isNotEmpty));
      await c.check('Lena dabei', () => c.waitFor('Lena Huber', seconds: 10));
      await c.check('Server: Eintrag weg',
          () => eventually(() async => !await hasEntry(annaId, 'Lena Huber hat die Einladung ins Album Geburtstage angenommen.')));
      await c.snap();

      c.clearMessages();
      c.step('Zurück: Eintrag erledigt', 'Oben links zurück.', 'Neuigkeiten: Lenas Eintrag ist weg, die von Tom und zu Wanderungen stehen noch da.',
          explain: 'Erledigt ist erledigt, wie bei WhatsApp eine gelesene Nachricht.');
      await c.back();
      c.screen('Neuigkeiten');
      await c.check('Lena weg', () => c.gone('Lena Huber hat die Einladung ins Album Geburtstage angenommen.', seconds: 5));
      await c.check('Tom da', () => c.waitFor('Tom Berger hat die Einladung ins Album Geburtstage angenommen.', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Wegwischen', 'Toms Eintrag nach links wegwischen.', 'Der Eintrag ist weg, ohne dass sich etwas öffnet.',
          kind: 'Abzweigung', explain: 'Wer etwas nur zur Kenntnis nimmt, wischt es weg.');
      await tester.drag(find.text('Tom Berger hat die Einladung ins Album Geburtstage angenommen.'), const Offset(-600, 0));
      c.logTap('Einladung beantwortet');
      await c.settle();
      await c.check('Weg', () => c.gone('Tom Berger hat die Einladung ins Album Geburtstage angenommen.', seconds: 5));
      await c.check('Noch Neuigkeiten', () => find.byType(NewsScreen).evaluate().isNotEmpty);
      await c.check('Server: weg', () => eventually(() async =>
          !await hasEntry(annaId, 'Tom Berger hat die Einladung ins Album Geburtstage angenommen.')));
      await c.snap();

      // ================================================================ Neue Fotos
      await home();
      await tray.cancelAll();
      c.clearMessages();
      c.step('Lena schickt Fotos', 'Nichts tun: Lena schickt zwei Fotos nach Geburtstage, kurz danach ein drittes.',
          'Oben erscheint eine Mitteilung: Geburtstage, Lena Huber hat 3 neue Fotos geteilt. Es bleibt eine einzige Mitteilung, '
              'die mitzählt. An der Glocke ein korallfarbener Punkt.',
          explain: 'Mehrere Fotos kurz hintereinander werden zu einer Mitteilung zusammengefasst, statt das Handy dreimal '
              'klingeln zu lassen. Der Punkt heißt: Neues im Verlauf.');
      final mark1 = pushes.length;
      final lenaPhotos = await lena.sendPhotos(birthdays, [
        await photo('02_berge_am_morgen.jpg'),
        await photo('03_see.jpg'),
      ]);
      await c.check('Push: 2 Fotos', () => arrives('Lena Huber hat 2 neue Fotos geteilt.', from: mark1));
      lenaPhotos.addAll(await lena.sendPhotos(birthdays, [await photo('09_blumenwiese.jpg')]));
      await c.check('Push: 3 Fotos', () => arrives('Lena Huber hat 3 neue Fotos geteilt.', from: mark1));
      await c.check('Eine Mitteilung, die mitzählt', () => eventually(() async {
            final s = (await shown()).where((n) => n.startsWith('Geburtstage: ')).toList();
            return s.length == 1 && s.single == 'Geburtstage: Lena Huber hat 3 neue Fotos geteilt.';
          }));
      await c.check('Ein Eintrag im Verlauf', () => eventually(() async {
            final h = (await history(annaId)).where((r) => (r['data'] as Map)['type'] == 'new_photo').toList();
            return h.length == 1 && h.single['body'] == 'Lena Huber hat 3 neue Fotos geteilt.';
          }));
      await c.check('Punkt an der Glocke', () => eventually(dot));
      await c.check('Startseite zählt mit', () => c.waitFor('~Lena Huber: 3 Fotos', seconds: 15));
      await c.check('Glocke nicht korall (nichts zu entscheiden)', () => !coral());
      await c.snap();

      c.clearMessages();
      c.step('Neuigkeiten: die neuen Fotos', 'Auf die Glocke tippen.',
          'Im Verlauf: Geburtstage, Lena Huber hat 3 neue Fotos geteilt, mit dem Bild des Albums.',
          explain: 'Der Punkt an der Glocke verschwindet, sobald Neuigkeiten offen war.');
      await openNews();
      await c.check('Eintrag', () => c.waitFor('Lena Huber hat 3 neue Fotos geteilt.', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Fotos-Eintrag antippen', 'Auf den Eintrag tippen.', 'Geburtstage geht auf, unten die drei Fotos von Lena.',
          explain: 'Bei neuen Fotos führt der Tipp direkt ins Album.');
      await entry('Lena Huber hat 3 neue Fotos geteilt.', 'Geburtstage');
      c.screen('Album');
      await c.check('Album offen', () => eventually(() => find.byType(ChannelFeedScreen).evaluate().isNotEmpty));
      await c.check('Server: Eintrag weg', () => eventually(() async =>
          !(await history(annaId)).any((r) => (r['data'] as Map)['type'] == 'new_photo')));
      await c.snap();

      await tray.cancelAll();
      c.clearMessages();
      c.step('Im offenen Album: keine Mitteilung', 'Nichts tun: Lena schickt noch ein Foto, während Anna Geburtstage offen hat.',
          'Das Foto erscheint unten im Album. Oben erscheint keine Mitteilung.',
          explain: 'Wie bei WhatsApp: Was man gerade vor sich hat, wird nicht noch einmal gemeldet.');
      final mark2 = pushes.length;
      lenaPhotos.addAll(await lena.sendPhotos(birthdays, [await photo('16_regenbogen.jpg')]));
      await c.check('Push kam an', () => arrives('Lena Huber hat 4 neue Fotos geteilt.', from: mark2));
      await c.check('Keine Mitteilung oben', () async {
        await c.letLoad(seconds: 2);
        return (await shown()).isEmpty;
      });
      await c.snap();

      c.clearMessages();
      c.step('Zurück: kein Punkt', 'Zweimal oben links zurück.', 'Die Startseite. Die Glocke hat keinen Punkt.',
          explain: 'Das vierte Foto hat Anna schon gesehen; im Verlauf steht es trotzdem, für später.');
      await home();
      await c.check('Kein Punkt', () => eventually(() => !dot()));
      await c.snap();

      // ================================================================ Änderungen an Alben
      await tray.cancelAll();
      c.clearMessages();
      c.step('Album umbenannt', 'Nichts tun: Lena benennt ihr Album Wanderungen in Wanderungen 2026 um.',
          'Mitteilung: Album umbenannt, Lena Huber hat das Album Wanderungen in Wanderungen 2026 umbenannt. '
              'Auf der Startseite heißt das Album jetzt Wanderungen 2026.',
          explain: 'Wer ein Album sieht, erfährt, wenn es anders heißt, damit niemand es plötzlich nicht mehr findet.');
      const renamed = 'Lena Huber hat das Album Wanderungen in Wanderungen 2026 umbenannt.';
      final mark3 = pushes.length;
      await lena.patch('channels', 'id=eq.$hiking', {'name': 'Wanderungen 2026'});
      await c.check('Push', () => arrives(renamed, from: mark3));
      await c.check('Mitteilung oben', () => eventually(() async => (await shown()).contains('Album umbenannt: $renamed')));
      await c.check('Neuer Name', () => c.waitFor('Wanderungen 2026', seconds: 15));
      await c.snap();

      c.clearMessages();
      c.step('Umbenannt: Eintrag antippen', 'Glocke, dann auf den Eintrag tippen.',
          'Die Album-Infos von Wanderungen 2026 gehen auf.', explain: 'Bei Änderungen am Album führt der Tipp in die Album-Infos.');
      await openNews();
      await entry(renamed, 'Album umbenannt');
      c.screen('Album-Infos');
      await c.check('Album-Infos', () => eventually(() => find.byType(AlbumInfoScreen).evaluate().isNotEmpty));
      await c.check('Wanderungen 2026', () => c.waitFor('Wanderungen 2026', seconds: 10));
      await c.snap();

      await home();
      c.clearMessages();
      c.step('Eigenes Foto: keine Mitteilung', 'Anna schickt ein Foto nach Wanderungen 2026.',
          'Lena und Tom bekommen die Mitteilung Wanderungen 2026, Anna Berger hat ein Foto geteilt. Anna selbst bekommt nichts.',
          explain: 'Was man selbst tut, weiß man schon. Smile meldet es nur den anderen.');
      final mark4 = pushes.length;
      const annaSent = 'Anna Berger hat ein Foto geteilt.';
      await UploadQueue.instance.enqueue(hiking, [XFile('$media/13_sonnenuntergang.jpg')], captions: [null]);
      await c.check('Lena bekommt es', () => eventually(() => hasEntry(lena.id, annaSent), seconds: 60));
      await c.check('Tom bekommt es', () => eventually(() => hasEntry(tom.id, annaSent)));
      await c.check('Anna nicht (Verlauf)', () async => !await hasEntry(annaId, annaSent));
      await c.check('Anna nicht (Push)', () async {
        await c.letLoad(seconds: 3);
        return pushes.skip(mark4).isEmpty;
      });
      await c.snap();

      await tray.cancelAll();
      c.clearMessages();
      c.step('Foto gelöscht', 'Nichts tun: Lena löscht Annas Foto aus Wanderungen 2026.',
          'Mitteilung: Foto gelöscht, Lena Huber hat dein Foto aus Wanderungen 2026 gelöscht.',
          explain: 'Lena verwaltet das Album und darf Fotos anderer löschen. Wessen Foto es war, erfährt es.');
      const deleted = 'Lena Huber hat dein Foto aus Wanderungen 2026 gelöscht.';
      final mark5 = pushes.length;
      final annaPhoto = (await TestBackend.select('media_items', 'select=id&channel_id=eq.$hiking&sender_id=eq.$annaId')).first['id'];
      await lena.edge('delete-media', {'media_item_ids': [annaPhoto], 'action': 'delete'});
      await c.check('Push', () => arrives(deleted, from: mark5));
      await c.check('Mitteilung oben', () => eventually(() async => (await shown()).contains('Foto gelöscht: $deleted')));
      await c.check('Punkt', () => eventually(dot));
      await c.snap();

      c.clearMessages();
      c.step('Gelöscht: Eintrag antippen', 'Glocke, dann auf den Eintrag tippen.', 'Wanderungen 2026 geht auf; Annas Foto ist nicht mehr da.',
          explain: 'Der Tipp führt ins Album.');
      await openNews();
      await entry(deleted, 'Foto gelöscht');
      c.screen('Album (leer)');
      await c.check('Album offen', () => eventually(() => find.byType(ChannelFeedScreen).evaluate().isNotEmpty));
      await c.check('Annas Foto weg', () => eventually(
          () => find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ChatRow').evaluate().isEmpty, seconds: 15));
      await c.snap();

      await home();
      c.clearMessages();
      c.step('Tom verlässt Geburtstage', 'Nichts tun: Tom verlässt das Album Geburtstage.',
          'Mitteilung: Album verlassen, Tom Berger hat das Album Geburtstage verlassen.',
          explain: 'Wer ein Album verwaltet, erfährt, wer geht.');
      const left = 'Tom Berger hat das Album Geburtstage verlassen.';
      final mark6 = pushes.length;
      await tom.delete('channel_members', 'channel_id=eq.$birthdays&user_id=eq.${tom.id}');
      await c.check('Push', () => arrives(left, from: mark6));
      await c.snap();

      c.clearMessages();
      c.step('Verlassen: Eintrag antippen', 'Glocke, dann auf den Eintrag tippen.',
          'Die Album-Infos von Geburtstage: Tom steht nicht mehr bei den Personen.', explain: 'Der Tipp führt in die Album-Infos.');
      await openNews();
      await entry(left, 'Album verlassen');
      c.screen('Album-Infos');
      await c.check('Album-Infos', () => eventually(() => find.byType(AlbumInfoScreen).evaluate().isNotEmpty));
      await c.check('Tom weg', () => c.gone('Tom Berger', seconds: 8));
      await c.snap();

      await home();
      c.clearMessages();
      c.step('Lena nimmt an', 'Nichts tun: Lena nimmt Annas Einladung ins Album Weihnachten an (aus Kapitel 5).',
          'Mitteilung: Einladung beantwortet, Lena Huber hat die Einladung ins Album Weihnachten angenommen.',
          explain: 'Wer einlädt, erfährt die Antwort, ob ja oder nein.');
      const accepted = 'Lena Huber hat die Einladung ins Album Weihnachten angenommen.';
      final mark7 = pushes.length;
      final lenaInvite = (await lena.select('channel_membership_requests',
              'select=id&status=eq.pending&channel_id=eq.$christmas&user_id=eq.${lena.id}'))
          .first['id'];
      await lena.patch('channel_membership_requests', 'id=eq.$lenaInvite', {'status': 'accepted'});
      await c.check('Push', () => arrives(accepted, from: mark7));
      await c.snap();

      c.clearMessages();
      c.step('Angenommen: Eintrag antippen', 'Glocke, dann auf den Eintrag tippen.', 'Die Album-Infos von Weihnachten: Lena ist dabei.',
          explain: 'Der Tipp führt in die Album-Infos.');
      await openNews();
      await entry(accepted, 'Einladung beantwortet');
      c.screen('Album-Infos');
      await c.check('Album-Infos', () => eventually(() => find.byType(AlbumInfoScreen).evaluate().isNotEmpty));
      await c.check('Lena dabei', () => c.waitFor('Lena Huber', seconds: 10));
      await c.snap();

      // ================================================================ Etwas zu entscheiden
      await home();
      c.clearMessages();
      c.step('Neue Anfrage', 'Nichts tun: Tom möchte zurück ins Album Geburtstage.',
          'Mitteilung: Neue Anfrage, Tom Berger möchte Member im Album Geburtstage werden. Die Glocke wird korallfarben.',
          explain: 'Korall heißt: Hier wartet jemand auf deine Antwort. Der Punkt allein heißt nur: Neues zum Lesen.');
      const asked = 'Tom Berger möchte Member im Album Geburtstage werden. Antworten unter Neuigkeiten.';
      final mark8 = pushes.length;
      await tom.insert('channel_membership_requests', {'channel_id': birthdays, 'user_id': tom.id, 'direction': 'request'});
      await c.check('Push', () => arrives(asked, from: mark8));
      await c.check('Glocke korall', () => eventually(coral));
      await c.snap();

      c.clearMessages();
      c.step('Anfrage in Neuigkeiten', 'Auf die Glocke tippen.',
          'Oben unter Anfragen: Geburtstage, Tom Berger möchte Member werden, mit Häkchen und Kreuz. Unten im Verlauf: Neue Anfrage.',
          explain: 'Die Anfrage bleibt oben stehen, bis Anna entschieden hat. Der Verlaufseintrag ist nur die Meldung dazu.');
      await openNews();
      await c.check('Anfragen', () => c.waitFor('Anfragen', seconds: 10));
      await c.check('Verlauf', () => c.waitFor(asked, seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Anfrage-Eintrag antippen', 'Unten im Verlauf auf Neue Anfrage tippen.',
          'Neuigkeiten bleibt offen, oben die Anfrage von Tom. Der Verlaufseintrag ist weg.',
          explain: 'Antworten kann man nur hier; darum führt der Tipp zu Neuigkeiten.');
      await entry(asked, 'Neue Anfrage');
      c.screen('Neuigkeiten');
      await c.check('Eintrag weg', () => c.gone(asked, seconds: 8));
      await c.check('Anfrage bleibt', () => c.waitFor('Anfragen', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Anfrage annehmen', 'Bei Tom auf das Häkchen (Annehmen).',
          'Die Anfrage ist weg. Tom bekommt die Mitteilung Anfrage beantwortet, Anna nicht.',
          explain: 'Die Antwort geht an den, der gefragt hat.');
      final mark9 = pushes.length;
      await c.tap('Annehmen');
      await c.check('Server: Tom ist zurück', () => eventually(() async =>
          (await TestBackend.select('channel_members', 'select=user_id&channel_id=eq.$birthdays&user_id=eq.${tom.id}')).isNotEmpty));
      await c.check('Tom bekommt Bescheid',
          () => eventually(() => hasEntry(tom.id, 'Deine Anfrage, Member im Album Geburtstage zu werden, wurde angenommen.')));
      await c.check('Anna nicht', () async {
        await c.letLoad(seconds: 3);
        return pushes.skip(mark9).isEmpty;
      });
      await c.check('Anfragen weg', () => c.gone('Anfragen', seconds: 8));
      await c.snap();

      await home();
      await c.check('Glocke wieder neutral', () => eventually(() => !coral()));
      await tray.cancelAll();
      c.clearMessages();
      c.step('Einladung ins Album', 'Nichts tun: Lena lädt Anna wieder in ihr Album Bergtouren ein.',
          'Mitteilung: Einladung ins Album, Du wurdest als Member ins Album Bergtouren eingeladen. Annehmen unter Neuigkeiten. '
              'Die Glocke wird korallfarben.',
          explain: 'Eine Einladung wartet auf Annas Antwort.');
      const invited = 'Du wurdest als Member ins Album Bergtouren eingeladen. Annehmen unter Neuigkeiten.';
      final mark10 = pushes.length;
      await lena.edge('invite-channel-member', {'channel_id': mountains, 'user_id': annaId});
      await c.check('Push', () => arrives(invited, from: mark10));
      await c.check('Mitteilung oben', () => eventually(() async => (await shown()).contains('Einladung ins Album: $invited')));
      await c.check('Glocke korall', () => eventually(coral));
      await c.snap();

      c.clearMessages();
      c.step('Auf die Mitteilung tippen', 'Oben auf die Mitteilung tippen.',
          'Neuigkeiten geht auf: unter Einladungen Bergtouren, Lena Huber lädt dich als Member ein, mit Häkchen und Kreuz.',
          explain: 'Die Mitteilung selbst führt an dieselbe Stelle wie ihr Eintrag im Verlauf.');
      await tapNotification(invited);
      c.screen('Neuigkeiten');
      await c.check('Neuigkeiten', () => eventually(() => find.byType(NewsScreen).evaluate().isNotEmpty));
      await c.check('Einladungen', () => c.waitFor('Einladungen', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Einladung annehmen', 'Bei Bergtouren auf das Häkchen (Annehmen).',
          'Unten kurz: Bergtouren ist jetzt in deinen Alben. Lena bekommt die Mitteilung Einladung beantwortet.',
          explain: 'Wieder geht die Antwort nur an die andere Seite.');
      final mark11 = pushes.length;
      await c.tap('Annehmen');
      await c.check('Lena bekommt Bescheid',
          () => eventually(() => hasEntry(lena.id, 'Anna Berger hat die Einladung ins Album Bergtouren angenommen.')));
      await c.check('Anna nicht', () async {
        await c.letLoad(seconds: 2);
        return pushes.skip(mark11).isEmpty;
      });
      await c.snap();

      c.clearMessages();
      c.step('Einladungs-Eintrag wegwischen', 'Im Verlauf den Eintrag Einladung ins Album nach rechts wegwischen.',
          'Der Eintrag ist weg.', kind: 'Abzweigung', explain: 'Wischen geht in beide Richtungen.');
      await scrollTo(find.text(invited));
      await tester.drag(find.text(invited), const Offset(600, 0));
      c.logTap('Einladung ins Album');
      await c.settle();
      await c.check('Weg', () => c.gone(invited, seconds: 5));
      await c.check('Server: weg', () => eventually(() async => !await hasEntry(annaId, invited)));
      await c.snap();

      await home();
      c.clearMessages();
      c.step('Album mit dir geteilt', 'Nichts tun: Lena teilt Bergtouren auch mit Annas Space. Anna tippt auf die Mitteilung.',
          'Neuigkeiten: unter Einladungen Bergtouren, Lena Huber möchte das Album mit deinem Space teilen.',
          explain: 'Dann sieht ganz Familie Berger das Album, auch ihr Frame.');
      const shareInvite = 'Das Album Bergtouren kann jetzt auch dein Space sehen. Annehmen unter Neuigkeiten.';
      final mark12 = pushes.length;
      await lena.edge('invite-channel-share', {'channel_id': mountains, 'user_id': annaId});
      await c.check('Push', () => arrives(shareInvite, from: mark12));
      await tapNotification(shareInvite);
      c.screen('Neuigkeiten');
      await c.check('Einladung', () => c.waitFor('Lena Huber möchte das Album mit deinem Space teilen', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Teilen annehmen', 'Auf das Häkchen (Annehmen).',
          'Die Einladung ist weg. Anna hat nur einen eigenen Space, darum fragt Smile nicht, mit welchem.',
          explain: 'Familie Berger sieht Bergtouren jetzt.');
      await c.tap('Annehmen');
      await c.check('Server: geteilt', () => eventually(() async =>
          (await TestBackend.select('channel_shares', 'select=space_id&channel_id=eq.$mountains&space_id=eq.$berger')).isNotEmpty));
      await c.check('Lena bekommt Bescheid', () => eventually(() async =>
          (await history(lena.id)).any((r) => r['body'] == 'Anna Berger hat das Album Bergtouren für den eigenen Space angenommen.')));
      await c.check('Einladung weg', () => c.gone('Lena Huber möchte das Album mit deinem Space teilen', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Nicht mehr geteilt', 'Nichts tun: Lena teilt Bergtouren doch nicht mehr mit Familie Berger.',
          'Im Verlauf: Nicht mehr geteilt, Lena Huber teilt das Album Bergtouren nicht mehr mit Familie Berger.',
          explain: 'Was verschwindet, wird angekündigt, damit sich niemand wundert.');
      const ended = 'Lena Huber teilt das Album Bergtouren nicht mehr mit Familie Berger.';
      final mark13 = pushes.length;
      await lena.delete('channel_shares', 'channel_id=eq.$mountains&space_id=eq.$berger');
      await c.check('Push', () => arrives(ended, from: mark13));
      await c.check('Im Verlauf', () => c.waitFor(ended, seconds: 15));
      await c.snap();

      c.clearMessages();
      c.step('Eintrag ohne Ziel antippen', 'Auf den Eintrag Nicht mehr geteilt tippen.',
          'Der Eintrag verschwindet, Neuigkeiten bleibt offen.',
          explain: 'Wo nichts mehr zu sehen ist, führt der Tipp nirgends hin; der Eintrag ist damit erledigt.');
      await entry(ended, 'Nicht mehr geteilt');
      await c.check('Weg', () => c.gone(ended, seconds: 5));
      await c.check('Noch Neuigkeiten', () => find.byType(AlbumInfoScreen).evaluate().isEmpty && find.byType(NewsScreen).evaluate().isNotEmpty);
      await c.snap();

      // ================================================================ Spaces
      await home();
      c.clearMessages();
      c.step('Space umbenannt', 'Nichts tun: Lena benennt ihren Space Familie Huber in Die Hubers um.',
          'Mitteilung: Space umbenannt, Lena Huber hat den Space Familie Huber in Die Hubers umbenannt.',
          explain: 'Anna ist in Alben dieses Space und erfährt es darum auch.');
      const spaceRenamed = 'Lena Huber hat den Space Familie Huber in Die Hubers umbenannt.';
      final mark14 = pushes.length;
      await lena.patch('spaces', 'id=eq.$huber', {'name': 'Die Hubers'});
      await c.check('Push', () => arrives(spaceRenamed, from: mark14));
      await c.snap();

      c.clearMessages();
      c.step('Co-Admin-Einladung', 'Nichts tun: Lena lädt Anna als Co-Admin von Die Hubers ein. Anna tippt auf die Mitteilung.',
          'Neuigkeiten: unter Einladungen Die Hubers, Lena Huber lädt dich als Co-Admin ein. Im Verlauf darunter Space umbenannt.',
          explain: 'Ein Space-Eintrag wie Space umbenannt führt nirgends hin: Einen fremden Space kann man nur als Admin öffnen.');
      const coInvite = 'Du wurdest eingeladen, den Space Die Hubers als Co-Admin mitzuverwalten. Annehmen unter Neuigkeiten.';
      final mark15 = pushes.length;
      await lena.edge('invite-space-co-owner', {'space_id': huber, 'user_id': annaId});
      await c.check('Push', () => arrives(coInvite, from: mark15));
      await tapNotification(coInvite);
      c.screen('Neuigkeiten');
      await c.check('Einladung', () => c.waitFor('Die Hubers', seconds: 10));
      await c.check('Space umbenannt im Verlauf', () => c.waitFor(spaceRenamed, seconds: 5));
      await c.check('Einladung ganz zu lesen', () => c.fullyShown(coInvite));
      await c.snap();

      c.clearMessages();
      c.step('Co-Admin annehmen', 'Bei Die Hubers auf das Häkchen (Annehmen).',
          'Die Einladung ist weg. Lena bekommt die Mitteilung Einladung beantwortet.', explain: 'Anna verwaltet Die Hubers jetzt mit.');
      await c.tap('Annehmen');
      await c.check('Server: Co-Admin', () => eventually(() async =>
          (await TestBackend.select('space_co_owners', 'select=user_id&space_id=eq.$huber&user_id=eq.$annaId')).isNotEmpty));
      await c.check('Lena bekommt Bescheid', () => eventually(() =>
          hasEntry(lena.id, 'Anna Berger hat deine Einladung als Co-Admin von Die Hubers angenommen.')));
      await c.check('Einladung weg', () => c.gone('Lena Huber lädt dich als Co-Admin ein', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Nicht mehr Co-Admin', 'Nichts tun: Lena nimmt Anna die Co-Admin-Rolle wieder ab.',
          'Im Verlauf: Nicht mehr Co-Admin, Lena Huber hat dich als Co-Admin von Die Hubers entfernt.',
          explain: 'Auch das wird gemeldet. Der Eintrag führt nirgends hin: Anna verwaltet den Space nicht mehr.');
      const removed = 'Lena Huber hat dich als Co-Admin von Die Hubers entfernt.';
      final mark16 = pushes.length;
      await lena.delete('space_co_owners', 'space_id=eq.$huber&user_id=eq.$annaId');
      await c.check('Push', () => arrives(removed, from: mark16));
      await c.check('Im Verlauf', () => c.waitFor(removed, seconds: 15));
      await c.snap();

      c.clearMessages();
      c.step('Du bist jetzt Admin', 'Nichts tun: Lena lädt Anna noch einmal ein, Anna nimmt an, und Lena übergibt ihr die Admin-Rolle.',
          'Im Verlauf: Du bist jetzt Admin, Du bist jetzt Admin des Space Die Hubers.',
          explain: 'Die Admin-Rolle geht nur an jemanden, der schon Co-Admin ist.');
      const nowAdmin = 'Du bist jetzt Admin des Space Die Hubers.';
      final mark17 = pushes.length;
      await lena.edge('invite-space-co-owner', {'space_id': huber, 'user_id': annaId});
      await c.check('Einladung da', () => c.waitFor('Lena Huber lädt dich als Co-Admin ein', seconds: 20));
      await c.tap('Annehmen');
      await c.check('Co-Admin', () => eventually(() async =>
          (await TestBackend.select('space_co_owners', 'select=user_id&space_id=eq.$huber&user_id=eq.$annaId')).isNotEmpty));
      await lena.edge('transfer-space-ownership', {'space_id': huber, 'new_owner_user_id': annaId});
      await c.check('Push', () => arrives(nowAdmin, from: mark17));
      await c.check('Im Verlauf', () => c.waitFor(nowAdmin, seconds: 15));
      await c.snap();

      c.clearMessages();
      c.step('Admin: Eintrag antippen', 'Auf den Eintrag Du bist jetzt Admin tippen.',
          'Die Seite von Die Hubers geht auf. Bei Admins: Du · Admin und Lena Huber als Co-Admin.',
          explain: 'Bei Space-Ereignissen für Admins führt der Tipp zur Seite des Space.');
      await entry(nowAdmin, 'Du bist jetzt Admin');
      c.screen('Space');
      await c.check('Space-Seite', () => eventually(() => find.byType(SpaceInfoScreen).evaluate().isNotEmpty));
      await c.check('Admins', () => c.waitFor('Admins', seconds: 10));
      await c.snap();

      await home();
      c.clearMessages();
      c.step('Neues Album', 'Nichts tun: Lena legt in Die Hubers das Album Klettersteige an.',
          'Mitteilung: Neues Album, Lena Huber hat das Album Klettersteige in Die Hubers angelegt.',
          explain: 'Wer einen Space verwaltet, erfährt von neuen Alben darin.');
      const created = 'Lena Huber hat das Album Klettersteige in Die Hubers angelegt.';
      final mark18 = pushes.length;
      await lena.insert('channels', {'space_id': huber, 'name': 'Klettersteige'});
      await c.check('Push', () => arrives(created, from: mark18));
      await c.snap();

      c.clearMessages();
      c.step('Neues Album: Eintrag antippen', 'Glocke, dann auf den Eintrag tippen.', 'Die Album-Infos von Klettersteige gehen auf.',
          explain: 'Der Tipp führt in die Album-Infos.');
      await openNews();
      await entry(created, 'Neues Album');
      c.screen('Album-Infos');
      await c.check('Album-Infos', () => eventually(() => find.byType(AlbumInfoScreen).evaluate().isNotEmpty));
      await c.check('Klettersteige', () => c.waitFor('Klettersteige', seconds: 10));
      await c.snap();

      await home();
      c.clearMessages();
      c.step('Co-Admin-Rolle abgegeben', 'Nichts tun: Lena gibt ihre Co-Admin-Rolle in Die Hubers ab.',
          'Mitteilung: Co-Admin-Rolle abgegeben, Lena Huber verwaltet den Space Die Hubers nicht mehr mit.',
          explain: 'Die Admin erfährt, wenn jemand nicht mehr mitverwaltet.');
      const steppedDown = 'Lena Huber verwaltet den Space Die Hubers nicht mehr mit.';
      final mark19 = pushes.length;
      await lena.delete('space_co_owners', 'space_id=eq.$huber&user_id=eq.${lena.id}');
      await c.check('Push', () => arrives(steppedDown, from: mark19));
      await c.snap();

      c.clearMessages();
      c.step('Abgegeben: Eintrag antippen', 'Glocke, dann auf den Eintrag tippen.',
          'Die Seite von Die Hubers: bei Admins nur noch Du · Admin.', explain: 'Der Tipp führt zur Seite des Space.');
      await openNews();
      await entry(steppedDown, 'Co-Admin-Rolle abgegeben');
      c.screen('Space');
      await c.check('Space-Seite', () => eventually(() => find.byType(SpaceInfoScreen).evaluate().isNotEmpty));
      await c.check('Lena nicht mehr Co-Admin', () => c.gone('Lena Huber', seconds: 8));
      await c.snap();

      // ================================================================ Aufräumen
      await c.back();
      c.screen('Neuigkeiten');
      c.clearMessages();
      c.step('Co-Admin-Einladung: Eintrag antippen', 'Im Verlauf auf einen Eintrag Einladung als Co-Admin tippen.',
          'Neuigkeiten geht noch einmal auf, der Eintrag ist weg. Unter Einladungen steht nichts mehr: Anna hat längst geantwortet.',
          explain: 'Einladungen beantwortet man hier; darum führt der Tipp zu Neuigkeiten.');
      final coInvites = (await history(annaId)).where((r) => r['body'] == coInvite).length;
      await entry(coInvite, 'Einladung als Co-Admin');
      c.screen('Neuigkeiten');
      await c.check('Einer weniger', () => eventually(() async =>
          (await history(annaId)).where((r) => r['body'] == coInvite).length == coInvites - 1));
      await c.check('Keine Einladung offen', () => c.gone('Einladungen', seconds: 5));
      await c.snap();
      await c.back();
      c.screen('Neuigkeiten');

      c.clearMessages();
      c.step('Space umbenannt antippen', 'Auf den Eintrag Space umbenannt tippen.', 'Der Eintrag verschwindet, Neuigkeiten bleibt offen.',
          explain: 'Ein fremder Space lässt sich nicht öffnen; der Eintrag ist damit erledigt.');
      await entry(spaceRenamed, 'Space umbenannt');
      await c.check('Weg', () => c.gone(spaceRenamed, seconds: 5));
      await c.check('Noch Neuigkeiten', () => find.byType(SpaceInfoScreen).evaluate().isEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Nicht mehr Co-Admin wegwischen', 'Den Eintrag Nicht mehr Co-Admin nach links wegwischen.', 'Der Eintrag ist weg.',
          kind: 'Abzweigung', explain: 'Auch Einträge ohne Ziel lassen sich wegwischen.');
      await tester.ensureVisible(find.text(removed));
      await c.settle();
      await tester.drag(find.text(removed), const Offset(-600, 0));
      c.logTap('Nicht mehr Co-Admin');
      await c.settle();
      await c.check('Weg', () => c.gone(removed, seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Alle entfernen', 'Ganz unten im Verlauf auf Alle entfernen.',
          'Der Verlauf ist leer. Weil auch sonst nichts wartet: Keine Neuigkeiten.',
          explain: 'Ein Tipp räumt den ganzen Verlauf weg.');
      await c.check('Noch Einträge', () async => (await history(annaId)).isNotEmpty);
      await scrollTo(find.text('Alle entfernen'));
      await tapExact('Alle entfernen');
      await c.check('Server: Verlauf leer', () => eventually(() async => (await history(annaId)).isEmpty));
      await c.check('Leer', () => c.waitFor('Keine Neuigkeiten', seconds: 5));
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      await listening?.cancel();
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
