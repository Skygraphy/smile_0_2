// Kapitel 9: Teilen und Co-Admin (tools/testsuite, 2026-10-26).
// Startet dort, wo Kapitel 5 endet (der Frame spielt hier keine Rolle).
// Paul, Lena und Tom haben kein Gerät: sie handeln per Skript, mit eigener
// Anmeldung und nur ihren eigenen Rechten, wie die App für sie.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/album_info_screen.dart';
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/screens/news_screen.dart';
import 'package:smile_app/screens/space_info_screen.dart';
import 'package:smile_app/screens/spaces_screen.dart';
import 'package:smile_app/services/space_service.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

/// Android's share sheet is not Smile: in the test, what Smile hands to it is caught.
class _CaughtShare extends SharePlatform {
  String? text;
  @override
  Future<ShareResult> share(ShareParams params) async {
    text = params.text;
    return const ShareResult('test', ShareResultStatus.success);
  }
}

/// An invented phone book (never the real one on the phone).
List<Map<String, Object?>> _phoneBook() {
  Map<String, Object?> entry(String id, String name, {String? email, String? phone}) => {
        'id': id,
        'displayName': name,
        'phones': [
          if (phone != null)
            {'number': phone, 'normalizedNumber': phone.replaceAll(' ', ''), 'label': {'label': 'mobile'}},
        ],
        'emails': [
          if (email != null) {'address': email, 'label': {'label': 'home'}},
        ],
      };
  return [
    entry('1', 'Paul Berger', email: paulMail),
    entry('2', 'Lena Huber', email: lenaMail),
    entry('3', 'Tom Berger', email: tomMail),
    entry('4', 'Max Moser', phone: '+43 660 000 0001'),
  ];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 9: Teilen und Co-Admin', (tester) async {
    final semantics = tester.ensureSemantics();
    final share = _CaughtShare();
    SharePlatform.instance = share;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_contacts'), (call) async {
      switch (call.method) {
        case 'permissions.check':
        case 'permissions.request':
          return 'granted';
        case 'crud.getAll':
          return _phoneBook();
      }
      return null;
    });
    final c = Chapter(tester, binding,
        id: 'ch09',
        title: 'Teilen und Co-Admin',
        intro: 'Anna holt sich Hilfe beim Verwalten: Paul wird Co-Admin von Familie Berger, Tom kurz auch, und Anna gibt die '
            'Admin-Rolle probeweise an Paul ab. Dann wird Anna selbst Co-Admin bei Lena. Zum Schluss teilt Anna Alben mit '
            'Lenas Space Familie Huber und bekommt ein Album von Lena in ihren eigenen Space.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 5)
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter5(tester);
      final berger = seed.spaceId;
      final summer = seed.albums['Sommerurlaub 2026']!;
      final birthdays = seed.albums['Geburtstage']!;
      final annaId = await TestBackend.userId(anna);
      final paul = await TestUser.signIn(paulMail);
      final lena = await TestUser.signIn(lenaMail);
      final tom = await TestUser.signIn(tomMail);
      final huber = (await TestBackend.select('spaces', 'select=id&name=eq.Familie%20Huber')).first['id'] as String;
      final mountains = (await TestBackend.select('channels', 'select=id&name=eq.Bergtouren')).first['id'] as String;

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<List<Map>> coInvites(String space) async => (await TestBackend.select(
              'space_co_owner_invites', 'select=id,invitee_user_id,status&space_id=eq.$space&order=requested_at.asc'))
          .cast<Map>();
      Future<Map?> coInviteOf(String space, String userId) async =>
          (await coInvites(space)).where((r) => r['invitee_user_id'] == userId).lastOrNull;
      Future<bool> isCoAdmin(String space, String userId) async =>
          (await TestBackend.select('space_co_owners', 'select=user_id&space_id=eq.$space&user_id=eq.$userId')).isNotEmpty;
      Future<String> ownerOf(String space) async =>
          (await TestBackend.select('spaces', 'select=owner_id&id=eq.$space')).first['owner_id'] as String;
      Future<List<Map>> shareRequests(String album) async => (await TestBackend.select('channel_share_requests',
              'select=id,space_id,target_user_id,direction,status&channel_id=eq.$album&order=requested_at.asc'))
          .cast<Map>();
      Future<Map?> lastShareRequest(String album) async => (await shareRequests(album)).lastOrNull;
      Future<bool> isShared(String album, String space) async =>
          (await TestBackend.select('channel_shares', 'select=space_id&channel_id=eq.$album&space_id=eq.$space')).isNotEmpty;
      Future<String> activeCode(String target) async => (await TestBackend.select('invite_codes',
              'select=code&target_id=eq.$target&revoked_at=is.null&order=created_at.desc&limit=1'))
          .first['code'] as String;

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

      /// The row "Co-Admin einladen" in the Admins section.
      Future<void> inviteRow() async {
        await scrollTo(find.widgetWithText(SmileActionRow, 'Co-Admin einladen'));
        await tester.tap(find.widgetWithText(SmileActionRow, 'Co-Admin einladen'), warnIfMissed: false);
        c.logTap('Co-Admin einladen');
        await c.settle();
        c.screen('Einladen');
        await c.waitFor('QR-Code zeigen', seconds: 5);
      }

      /// A person in the invite sheet (by name, the row of the sheet).
      /// Paul shares no album with Anna any more (chapter 5): found by his Smile-Name.
      Future<void> pick(String name) async {
        if (name == 'Paul Berger') await c.typeInto('Name oder @Smile-Name', '@paul.berger');
        await c.tap(name, last: true, seconds: 8);
      }

      Future<void> openSpace(String name) async {
        await until(SpacesScreen, () => tapExact('Spaces'));
        c.screen('Spaces');
        await until(SpaceInfoScreen, () => c.tap(name, last: true));
        c.screen('Space');
        await c.waitFor('Admins', seconds: 10);
      }

      Future<void> openInfo(String album) async {
        final feed = find.byType(ChannelFeedScreen);
        for (var i = 0; i < 3 && feed.evaluate().isEmpty; i++) {
          await c.tap(album);
          for (var t = 0; t < 40 && feed.evaluate().isEmpty; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        c.screen('Album');
        final info = find.byType(AlbumInfoScreen, skipOffstage: false);
        for (var i = 0; i < 3 && info.evaluate().isEmpty; i++) {
          await c.settle(max: const Duration(seconds: 2));
          await c.tap(album, last: true);
          for (var t = 0; t < 60 && info.evaluate().isEmpty; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        c.screen('Album-Infos');
        await c.waitFor('Geteilt mit', seconds: 10);
      }

      /// Back to the start page (Alben), wherever the app is.
      Future<void> home() async {
        for (var i = 0; i < 5 && find.byType(SpacesScreen).evaluate().isEmpty && c.find_('Neuigkeiten').evaluate().isEmpty; i++) {
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

      await c.waitFor('Wanderungen', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Co-Admin einladen
      c.step('Ausgangslage', 'Unten auf Spaces, dann Familie Berger.',
          'Die Seite von Familie Berger. Oben die Knöpfe Album, Frame und Co-Admin, weiter unten bei Admins nur Du · Admin und Co-Admin einladen.',
          explain: 'So endet Kapitel 5. Ein Space hat genau einen Admin, dazu beliebig viele Co-Admins, die mitverwalten.');
      await openSpace('Familie Berger');
      await scrollTo(c.find_('Co-Admin einladen'));
      await c.check('Noch kein Co-Admin', () async => (await TestBackend.select('space_co_owners', 'select=user_id&space_id=eq.$berger')).isEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Co-Admin einladen', 'Bei Admins auf Co-Admin einladen tippen.',
          'Co-Admin für Familie Berger: Suchfeld, Lena und Tom (aus Geburtstage), dazu Aus Kontakten, QR-Code zeigen und Per E-Mail einladen. '
              'Einen Einladungslink gibt es hier nicht.',
          explain: 'Co-Admins dürfen alles verwalten. Darum gibt es keinen Link, der weitergeleitet werden könnte.');
      await inviteRow();
      await c.check('Titel', () => c.waitFor('Co-Admin für Familie Berger', seconds: 3));
      await c.check('Kein Einladungslink', () => c.gone('Einladungslink teilen', seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Co-Admin einladen: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Co-Admin für Familie Berger', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Paul einladen (Menü)', 'Oben rechts auf die drei Punkte, Co-Admin einladen, @paul.berger suchen, Paul Berger antippen.',
          'Unten kurz: Einladung an Paul Berger gesendet. Bei Admins steht Paul mit Eingeladen · Annahme ausstehend.',
          explain: 'Paul bekommt die Einladung in seine Neuigkeiten und entscheidet selbst.');
      await toTop();
      await c.tap('Weitere Optionen');
      c.screen('Menü des Space');
      await c.tap('Co-Admin einladen', last: true);
      c.screen('Einladen');
      await pick('Paul Berger');
      c.screen('Space');
      await c.check('Meldung', () => c.waitFor('Einladung an Paul Berger gesendet', seconds: 8));
      await c.check('Server: eingeladen', () => eventually(() async => (await coInviteOf(berger, paul.id))?['status'] == 'pending'));
      await scrollTo(c.find_('Eingeladen · Annahme ausstehend'));
      await c.check('Ganz zu lesen', () => c.fullyShown('Eingeladen · Annahme ausstehend'));
      await c.snap();

      c.clearMessages();
      c.step('Einladung zurückziehen', 'Rechts neben Paul auf das Kreuz (Zurückziehen) tippen.', 'Paul verschwindet bei Admins.',
          kind: 'Abzweigung', explain: 'Solange Paul nicht angenommen hat, lässt sich die Einladung zurücknehmen.');
      await c.tap('Zurückziehen');
      await c.check('Server: keine Einladung', () => eventually(() async => await coInviteOf(berger, paul.id) == null));
      await c.check('Weg', () => c.gone('Eingeladen · Annahme ausstehend', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Über den Knopf Co-Admin', 'Ganz oben auf den Knopf Co-Admin tippen, Paul suchen und antippen.', 'Paul ist wieder eingeladen.',
          kind: 'Abzweigung', explain: 'Derselbe Weg über den Knopf oben.');
      await toTop();
      await tapExact('Co-Admin', first: true);
      c.screen('Einladen');
      await pick('Paul Berger');
      c.screen('Space');
      await c.check('Server: eingeladen', () => eventually(() async => (await coInviteOf(berger, paul.id))?['status'] == 'pending'));
      await scrollTo(c.find_('Eingeladen · Annahme ausstehend'));
      await c.snap();

      c.clearMessages();
      c.step('Paul lehnt ab', 'Nichts tun: Paul lehnt auf seinem Handy ab.', 'Paul verschwindet bei Admins.', kind: 'Abzweigung',
          explain: 'Wer nicht mitverwalten möchte, lehnt ab.');
      final paulInvite1 = (await coInviteOf(berger, paul.id))!['id'] as String;
      await paul.patch('space_co_owner_invites', 'id=eq.$paulInvite1', {'status': 'declined'});
      await c.check('Weg', () => c.gone('Eingeladen · Annahme ausstehend', seconds: 20));
      await c.snap();

      c.clearMessages();
      c.step('Paul nimmt an', 'Co-Admin einladen, Paul suchen und antippen. Paul nimmt diesmal an.',
          'Bei Admins steht Paul Berger mit dem Abzeichen Co-Admin.', explain: 'Paul verwaltet Familie Berger jetzt mit: Alben, Frames und Personen.');
      await inviteRow();
      await pick('Paul Berger');
      c.screen('Space');
      await c.check('Eingeladen', () => eventually(() async => (await coInviteOf(berger, paul.id))?['status'] == 'pending'));
      final paulInvite2 = (await coInviteOf(berger, paul.id))!['id'] as String;
      await paul.patch('space_co_owner_invites', 'id=eq.$paulInvite2', {'status': 'accepted'});
      await c.check('Server: Paul ist Co-Admin', () => eventually(() => isCoAdmin(berger, paul.id)));
      await c.check('Kein Wartend mehr', () => c.gone('Eingeladen · Annahme ausstehend', seconds: 20));
      await scrollTo(c.find_('Paul Berger'));
      await c.snap();

      c.clearMessages();
      c.step('Schon Co-Admin', 'Co-Admin einladen, @paul.berger suchen.', 'Bei Paul steht Schon Admin oder Co-Admin; ein Tipp tut nichts.',
          kind: 'Abzweigung', explain: 'Niemand wird doppelt eingeladen.');
      await inviteRow();
      await c.typeInto('Name oder @Smile-Name', '@paul.berger');
      await c.check('Hinweis', () => c.waitFor('~Schon Admin oder Co-Admin', seconds: 5));
      await c.check('Ganz zu lesen', () => c.fullyShown('@paul.berger · Schon Admin oder Co-Admin'));
      await c.tap('Paul Berger', last: true);
      await c.check('Server: keine neue Einladung', () async => (await coInvites(berger)).where((r) => r['status'] == 'pending').isEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Aus Kontakten', 'Suchfeld leeren, Aus Kontakten antippen.',
          'Aus Kontakten: der Hinweis Co-Admin kann nur werden, wer schon Smile hat, darunter In Smile mit Lena und Tom (Einladen) und Paul mit Schon Admin oder Co-Admin. Max Moser ohne Smile steht nicht da.',
          explain: 'Co-Admin kann nur werden, wer Smile schon hat.');
      await c.typeInto('Name oder @Smile-Name', '');
      await c.hideKeyboard();
      await c.tap('Aus Kontakten');
      c.screen('Kontakte');
      await c.check('Kontakte', () => c.waitFor('Lena Huber', seconds: 8));
      await c.check('Hinweis', () => c.waitFor('Co-Admin kann nur werden, wer schon Smile hat', seconds: 2));
      await c.check('Max nicht da', () => c.gone('Max Moser', seconds: 1));
      await c.snap();

      await c.back();
      c.screen('Space');

      c.clearMessages();
      c.step('Tom per QR-Code', 'Co-Admin einladen, QR-Code zeigen. Tom scannt ihn vor Ort mit seinem Handy. Dann oben links zurück.',
          'Der QR-Code mit dem Hinweis, dass man Co-Admin nur per QR-Code vor Ort wird. Danach steht Tom sofort bei Admins.',
          explain: 'Wer den QR-Code scannt, steht neben Anna, darum ist er sofort Co-Admin.');
      await inviteRow();
      await c.tap('QR-Code zeigen');
      c.screen('QR-Code');
      await c.check('Hinweis', () => c.waitFor('~Co-Admin wird man nur per QR-Code', seconds: 8));
      final code = await activeCode(berger);
      await c.check('Abgetippt geht nicht', () async => (await tom.edge('redeem-invite-code', {'code': code, 'via': 'typed'}))['error'] == 'qr_only');
      await c.snap();
      final scanned = await tom.edge('redeem-invite-code', {'code': code, 'via': 'qr'});
      await c.check('Tom gescannt', () => scanned['status'] == 'joined');
      await c.back();
      c.screen('Space');
      await c.check('Server: Tom ist Co-Admin', () => eventually(() => isCoAdmin(berger, tom.id)));
      await scrollTo(c.find_('Tom Berger'));
      await c.check('Tom bei Admins', () => c.waitFor('Tom Berger', seconds: 10));

      c.clearMessages();
      c.step('Per E-Mail: Lena', 'Co-Admin einladen, Per E-Mail einladen, lena.huber@example.com eingeben, Einladen. Lena lehnt ab.',
          'Zuerst steht Lena mit Eingeladen · Annahme ausstehend da, nach ihrer Absage nicht mehr.', kind: 'Abzweigung',
          explain: 'Per E-Mail geht es auch, wenn man jemanden noch nicht in der Liste hat.');
      await inviteRow();
      await c.tap('Per E-Mail einladen');
      c.screen('E-Mail-Frage');
      await c.typeInto('E-Mail-Adresse', lenaMail);
      await c.tap('Einladen', last: true);
      c.screen('Space');
      await c.check('Server: Lena eingeladen', () => eventually(() async => (await coInviteOf(berger, lena.id))?['status'] == 'pending'));
      await c.check('Wartet', () => c.waitFor('Eingeladen · Annahme ausstehend', seconds: 8));
      await c.hideKeyboard();
      await c.snap();
      final lenaInvite = (await coInviteOf(berger, lena.id))!['id'] as String;
      await lena.patch('space_co_owner_invites', 'id=eq.$lenaInvite', {'status': 'declined'});
      await c.check('Lena weg', () => c.gone('Eingeladen · Annahme ausstehend', seconds: 20));

      // ---------------------------------------------------------------- Co-Admins verwalten
      Future<void> coAdminCard(String name) async {
        await scrollTo(c.find_(name));
        await c.tap(name, last: true);
        c.screen('Co-Admin-Karte');
        await c.waitFor('Als Co-Admin entfernen', seconds: 5);
      }

      c.clearMessages();
      c.step('Co-Admin antippen', 'Bei Admins auf Tom Berger tippen.', 'Unten öffnet sich: Zum Admin machen und Als Co-Admin entfernen.',
          explain: 'Als Admin entscheidet Anna, wer mitverwaltet.');
      await coAdminCard('Tom Berger');
      await c.snap();

      c.clearMessages();
      c.step('Co-Admin-Karte: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Als Co-Admin entfernen', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Entfernen: Abbrechen', 'Tom antippen, Als Co-Admin entfernen, dann Abbrechen.', 'Tom bleibt Co-Admin.', kind: 'Abzweigung',
          explain: 'Smile fragt vorher.');
      await coAdminCard('Tom Berger');
      await c.tap('Als Co-Admin entfernen');
      c.screen('Co-Admin entfernen?');
      await c.check('Frage', () => c.waitFor('Tom Berger als Co-Admin entfernen?', seconds: 3));
      await c.snap();
      await c.tap('Abbrechen');
      c.screen('Space');
      await c.check('Server: Tom bleibt', () => isCoAdmin(berger, tom.id));

      c.clearMessages();
      c.step('Entfernen: daneben tippen', 'Wieder öffnen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await coAdminCard('Tom Berger');
      await c.tap('Als Co-Admin entfernen');
      c.screen('Co-Admin entfernen?');
      await c.waitFor('Tom Berger als Co-Admin entfernen?', seconds: 3);
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Tom Berger als Co-Admin entfernen?', seconds: 3));
      await c.check('Server: unverändert', () => isCoAdmin(berger, tom.id));
      await c.snap();

      c.clearMessages();
      c.step('Als Co-Admin entfernen', 'Tom antippen, Als Co-Admin entfernen, Entfernen.', 'Tom steht nicht mehr bei Admins.',
          explain: 'Tom verliert die Verwaltungsrechte, seine Alben bleiben, wie sie sind.');
      await coAdminCard('Tom Berger');
      await c.tap('Als Co-Admin entfernen');
      c.screen('Co-Admin entfernen?');
      await c.tap('Entfernen', last: true);
      c.screen('Space');
      await c.check('Server: Tom weg', () => eventually(() async => !await isCoAdmin(berger, tom.id)));
      await c.check('Tom weg', () => c.gone('Tom Berger', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Zum Admin machen: Abbrechen', 'Paul antippen, Zum Admin machen, dann Abbrechen.',
          'Die Frage Paul Berger zum Admin machen? mit der Erklärung; nach Abbrechen bleibt alles.', kind: 'Abzweigung',
          explain: 'Anna bliebe danach Co-Admin mit allen Rechten.');
      await coAdminCard('Paul Berger');
      await c.tap('Zum Admin machen');
      c.screen('Admin-Frage');
      await c.check('Frage', () => c.waitFor('Paul Berger zum Admin machen?', seconds: 3));
      await c.snap();
      await c.tap('Abbrechen');
      c.screen('Space');
      await c.check('Server: Anna bleibt Admin', () async => await ownerOf(berger) == annaId);

      c.clearMessages();
      c.step('Zum Admin machen: daneben tippen', 'Wieder öffnen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await coAdminCard('Paul Berger');
      await c.tap('Zum Admin machen');
      c.screen('Admin-Frage');
      await c.waitFor('Paul Berger zum Admin machen?', seconds: 3);
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Paul Berger zum Admin machen?', seconds: 3));
      await c.check('Server: unverändert', () async => await ownerOf(berger) == annaId);
      await c.snap();

      c.clearMessages();
      c.step('Admin übergeben: Auswahl', 'Ganz unten auf Admin übergeben.', 'Wer soll Admin werden? mit Paul Berger.',
          explain: 'Zum Beispiel, wenn jemand anderes den Space künftig führt.');
      await scrollTo(c.find_('Admin übergeben'));
      await c.tap('Admin übergeben');
      c.screen('Admin-Auswahl');
      await c.check('Frage', () => c.waitFor('Wer soll Admin werden?', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Admin übergeben: daneben tippen', 'Neben die Auswahl tippen.', 'Die Auswahl schließt sich, Anna bleibt Admin.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Wer soll Admin werden?', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Admin übergeben', 'Admin übergeben, Paul Berger, dann Zum Admin machen.',
          'Bei Admins steht jetzt Paul Berger · Admin und Du · Co-Admin. Space löschen und Co-Admin einladen sind weg.',
          explain: 'Anna verwaltet weiter mit, entscheidet aber nicht mehr allein, wer mitverwaltet.');
      await c.tap('Admin übergeben');
      c.screen('Admin-Auswahl');
      await c.tap('Paul Berger', last: true);
      c.screen('Admin-Frage');
      await c.tap('Zum Admin machen', last: true);
      c.screen('Space');
      await c.check('Server: Paul ist Admin', () => eventually(() async => await ownerOf(berger) == paul.id));
      await c.check('Server: Anna ist Co-Admin', () => eventually(() => isCoAdmin(berger, annaId)));
      await c.check('Kein Space löschen', () => c.gone('Space löschen', seconds: 8));
      await c.check('Kein Co-Admin einladen', () => c.gone('Co-Admin einladen', seconds: 2));
      await scrollTo(c.find_('Paul Berger'), by: -300);
      await c.snap();

      c.clearMessages();
      c.step('Als Co-Admin: eigene Rolle', 'Bei Admins auf Du tippen, Co-Admin-Rolle abgeben, dann Abbrechen.',
          'Die Frage Co-Admin-Rolle abgeben? Du verlierst deine Verwaltungsrechte über diesen Space. Nach Abbrechen bleibt alles.',
          kind: 'Abzweigung', explain: 'Jeder Co-Admin kann selbst aufhören.');
      await scrollTo(find.text('Du'));
      await tapExact('Du');
      c.screen('Co-Admin-Karte');
      await c.tap('Co-Admin-Rolle abgeben');
      c.screen('Abgeben-Frage');
      await c.check('Frage', () => c.waitFor('Du verlierst deine Verwaltungsrechte', seconds: 3));
      await c.snap();
      await c.tap('Abbrechen');
      c.screen('Space');
      await c.check('Server: Anna bleibt Co-Admin', () => isCoAdmin(berger, annaId));

      c.clearMessages();
      c.step('Abgeben: daneben tippen', 'Wieder öffnen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await scrollTo(find.text('Du'));
      await tapExact('Du');
      c.screen('Co-Admin-Karte');
      await c.tap('Co-Admin-Rolle abgeben');
      c.screen('Abgeben-Frage');
      await c.waitFor('Du verlierst deine Verwaltungsrechte', seconds: 3);
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Du verlierst deine Verwaltungsrechte', seconds: 3));
      await c.check('Server: unverändert', () => isCoAdmin(berger, annaId));
      await c.snap();

      c.clearMessages();
      c.step('Paul gibt zurück', 'Nichts tun: Paul macht Anna auf seinem Handy wieder zum Admin.',
          'Bei Admins wieder Du · Admin und Paul Berger · Co-Admin, dazu wieder Co-Admin einladen und Space löschen.',
          explain: 'Der Wechsel geht in beide Richtungen.');
      final back = await paul.edge('transfer-space-ownership', {'space_id': berger, 'new_owner_user_id': annaId});
      await c.check('Übergeben', () => back['status'] == 'transferred');
      await c.check('Server: Anna ist Admin', () => eventually(() async => await ownerOf(berger) == annaId));
      await c.check('Co-Admin einladen wieder da', () => eventually(() async {
        await scrollTo(c.find_('Co-Admin einladen'));
        return c.find_('Co-Admin einladen').evaluate().isNotEmpty;
      }, seconds: 20));
      await c.snap();

      // ================================================================ Anna wird selbst Co-Admin
      c.clearMessages();
      c.step('Co-Admin-Einladung bekommen', 'Lena lädt Anna als Co-Admin von Familie Huber ein. Zur Startseite, oben Neuigkeiten.',
          'Unter Einladungen: Familie Huber, Lena Huber lädt dich als Co-Admin ein, mit Häkchen und Kreuz.',
          explain: 'Einladungen an einen selbst warten in den Neuigkeiten.');
      final invHuber = await lena.edge('invite-space-co-owner', {'space_id': huber, 'user_id': annaId});
      await c.check('Eingeladen', () => invHuber['status'] == 'invited');
      await home();
      await openNews();
      await c.check('Einladung', () => c.waitFor('Lena Huber lädt dich als Co-Admin ein', seconds: 20));
      await c.check('Ganz zu lesen', () => c.fullyShown('Lena Huber lädt dich als Co-Admin ein'));
      await c.snap();

      c.clearMessages();
      c.step('Co-Admin: ablehnen', 'Auf das Kreuz (Ablehnen) tippen.', 'Die Einladung ist weg.', kind: 'Abzweigung',
          explain: 'Lena erfährt es in ihren Neuigkeiten.');
      await c.tap('Ablehnen');
      await c.check('Server: abgelehnt', () => eventually(() async => (await coInviteOf(huber, annaId))?['status'] == 'declined'));
      await c.check('Weg', () => c.gone('Lena Huber lädt dich als Co-Admin ein', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Co-Admin: annehmen', 'Lena lädt noch einmal ein. Auf das Häkchen (Annehmen) tippen.',
          'Unten kurz: Du verwaltest jetzt Familie Huber mit.', explain: 'Anna ist jetzt Co-Admin bei Lena.');
      await lena.edge('invite-space-co-owner', {'space_id': huber, 'user_id': annaId});
      await c.waitFor('Lena Huber lädt dich als Co-Admin ein', seconds: 20);
      await c.tap('Annehmen');
      await c.check('Meldung', () => c.waitFor('Du verwaltest jetzt Familie Huber mit', seconds: 8));
      await c.check('Server: Anna ist Co-Admin', () => eventually(() => isCoAdmin(huber, annaId)));
      await c.snap();

      c.clearMessages();
      c.step('Lenas Space', 'Zurück, unten Spaces, dann Familie Huber.',
          'Die Seite von Familie Huber: die Alben Wanderungen und Bergtouren, bei Admins Lena Huber · Admin und Du · Co-Admin. '
              'Co-Admin einladen und Space löschen gibt es für Anna hier nicht.',
          explain: 'Als Co-Admin verwaltet Anna mit, aber nur Lena entscheidet, wer mitverwaltet.');
      await c.back();
      await openSpace('Familie Huber');
      await c.check('Bergtouren', () => c.waitFor('Bergtouren', seconds: 8));
      await scrollTo(c.find_('Admins'));
      await c.check('Kein Co-Admin einladen', () => c.gone('Co-Admin einladen', seconds: 2));
      await c.check('Kein Space löschen', () => c.gone('Space löschen', seconds: 1));
      await c.snap();

      // ================================================================ Ein Album teilen
      await home();
      c.clearMessages();
      c.step('Geteilt mit', 'Auf der Startseite Sommerurlaub 2026 öffnen, oben auf den Namen.',
          'Die Seite des Albums, weiter unten Geteilt mit: Noch mit keinem anderen Space geteilt, darunter Mit einem Space teilen.',
          explain: 'Ein Album lässt sich mit einem anderen Space teilen. Dort sieht man es nur an und auf den Frames, trägt aber nichts bei.');
      await openInfo('Sommerurlaub 2026');
      await scrollTo(c.find_('Noch mit keinem anderen Space geteilt'));
      await c.snap();

      c.clearMessages();
      c.step('Mit Space teilen', 'Ganz oben auf den Knopf Mit Space teilen.',
          'Mit einem Space teilen: Lena und Paul mit Verwaltet einen Space. Tom fehlt, er verwaltet keinen Space.',
          explain: 'Geteilt wird mit jemandem, der einen Space verwaltet. Er wählt beim Annehmen, mit welchem.');
      await toTop();
      await tapExact('Mit Space teilen');
      c.screen('Einladen');
      await c.check('Verwaltet einen Space', () => c.waitFor('~Verwaltet einen Space', seconds: 5));
      // Only in the sheet: the page behind lists Tom as a member.
      await c.check('Tom fehlt', () => find.descendant(of: find.byType(BottomSheet), matching: find.text('Tom Berger')).evaluate().isEmpty);
      await c.snap();

      c.clearMessages();
      c.step('Tom geht nicht', 'Nach @tom.berger suchen und Tom antippen.', 'Tom steht grau da mit Verwaltet keinen Space; der Tipp tut nichts.',
          kind: 'Abzweigung', explain: 'Ohne eigenen Space kann man kein Album in einen Space holen.');
      await c.typeInto('Name oder @Smile-Name', '@tom.berger');
      await c.check('Grund', () => c.waitFor('~Verwaltet keinen Space', seconds: 5));
      await c.tap('Tom Berger', last: true);
      await c.check('Server: keine Anfrage', () async => (await shareRequests(summer)).isEmpty);
      await c.snap();
      await c.typeInto('Name oder @Smile-Name', '');
      await c.hideKeyboard();

      c.clearMessages();
      c.step('Lena einladen', 'Lena Huber antippen.',
          'Unten kurz: Einladung an Lena Huber gesendet. Bei Geteilt mit steht Lena mit Eingeladen · Annahme ausstehend.',
          explain: 'Lena entscheidet in ihren Neuigkeiten, ob und mit welchem Space.');
      await c.tap('Lena Huber', last: true);
      c.screen('Album-Infos');
      await c.check('Server: eingeladen', () => eventually(() async => (await lastShareRequest(summer))?['status'] == 'pending'));
      await scrollTo(c.find_('Eingeladen · Annahme ausstehend'));
      await c.snap();

      c.clearMessages();
      c.step('Teilen zurückziehen', 'Rechts neben Lena auf das Kreuz (Zurückziehen).', 'Lena verschwindet wieder.', kind: 'Abzweigung',
          explain: 'Wie bei Personen.');
      await c.tap('Zurückziehen');
      await c.check('Server: keine offene Einladung', () => eventually(() async => await lastShareRequest(summer) == null));
      await c.check('Weg', () => c.gone('Eingeladen · Annahme ausstehend', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Lena nimmt an', 'Unten Mit einem Space teilen, Lena Huber. Lena nimmt an.',
          'Bei Geteilt mit steht Familie Huber: Sieht das Album, trägt nichts bei.',
          explain: 'Familie Huber sieht Sommerurlaub 2026 jetzt, auch auf ihren Frames.');
      await scrollTo(c.find_('Mit einem Space teilen'));
      await c.tap('Mit einem Space teilen');
      c.screen('Einladen');
      await c.tap('Lena Huber', last: true);
      c.screen('Album-Infos');
      await c.check('Eingeladen', () => eventually(() async => (await lastShareRequest(summer))?['status'] == 'pending'));
      final shareInvite = (await lastShareRequest(summer))!['id'] as String;
      await lena.patch('channel_share_requests', 'id=eq.$shareInvite', {'status': 'accepted', 'space_id': huber});
      await c.check('Server: geteilt', () => eventually(() => isShared(summer, huber)));
      await c.check('Familie Huber', () => c.waitFor('Sieht das Album, trägt nichts bei', seconds: 20));
      await c.snap();

      Future<void> shareCard() async {
        await scrollTo(c.find_('Sieht das Album'));
        await tapExact('Familie Huber');
        c.screen('Freigabe-Karte');
        await c.waitFor('Freigabe beenden', seconds: 5);
      }

      c.clearMessages();
      c.step('Freigabe antippen', 'Auf Familie Huber tippen.', 'Unten öffnet sich Freigabe beenden.',
          explain: 'Das Teilen lässt sich jederzeit beenden.');
      await shareCard();
      await c.snap();

      c.clearMessages();
      c.step('Freigabe-Karte: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich.', kind: 'Abzweigung',
          explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Album-Infos');
      await c.check('Zu', () => c.gone('Freigabe beenden', seconds: 3));
      await c.snap();
      await shareCard();

      c.clearMessages();
      c.step('Freigabe beenden: Abbrechen', 'Freigabe beenden, dann Abbrechen.',
          'Die Frage Freigabe für Familie Huber beenden? Familie Huber sieht Sommerurlaub 2026 danach nicht mehr, auch nicht auf seinen Frames. '
              'Nach Abbrechen bleibt alles.', kind: 'Abzweigung', explain: 'Smile fragt vorher.');
      await c.tap('Freigabe beenden', last: true);
      c.screen('Freigabe-Frage');
      await c.check('Frage', () => c.waitFor('Freigabe für Familie Huber beenden?', seconds: 3));
      await c.snap();
      await c.tap('Abbrechen');
      c.screen('Album-Infos');
      await c.check('Server: weiter geteilt', () => isShared(summer, huber));

      c.clearMessages();
      c.step('Freigabe beenden: daneben tippen', 'Wieder öffnen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await shareCard();
      await c.tap('Freigabe beenden', last: true);
      c.screen('Freigabe-Frage');
      await c.waitFor('Freigabe für Familie Huber beenden?', seconds: 3);
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Album-Infos');
      await c.check('Zu', () => c.gone('Freigabe für Familie Huber beenden?', seconds: 3));
      await c.check('Server: unverändert', () => isShared(summer, huber));
      await c.snap();

      c.clearMessages();
      c.step('Freigabe beenden', 'Familie Huber, Freigabe beenden, Freigabe beenden.', 'Wieder Noch mit keinem anderen Space geteilt.',
          explain: 'Lena bekommt Bescheid.');
      await shareCard();
      await c.tap('Freigabe beenden', last: true);
      c.screen('Freigabe-Frage');
      await c.tap('Freigabe beenden', last: true);
      c.screen('Album-Infos');
      await c.check('Server: nicht mehr geteilt', () => eventually(() async => !await isShared(summer, huber)));
      await c.check('Nicht geteilt', () => c.waitFor('Noch mit keinem anderen Space geteilt', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Teilen per QR-Code', 'Mit einem Space teilen, QR-Code zeigen. Lena scannt ihn. Dann oben links zurück.',
          'Familie Huber steht sofort bei Geteilt mit.', explain: 'Vor Ort gescannt, ohne weiteres Ja.');
      await scrollTo(c.find_('Mit einem Space teilen'));
      await c.tap('Mit einem Space teilen');
      c.screen('Einladen');
      await c.tap('QR-Code zeigen');
      c.screen('QR-Code');
      await c.waitFor('Neuen Code erstellen', seconds: 8);
      await c.snap();
      final shareCode = await activeCode(summer);
      final scannedShare = await lena.edge('redeem-invite-code', {'code': shareCode, 'via': 'qr'});
      await c.check('Lena gescannt', () => scannedShare['status'] == 'joined');
      await c.back();
      c.screen('Album-Infos');
      await c.check('Server: geteilt', () => eventually(() => isShared(summer, huber)));
      await c.check('Familie Huber', () => c.waitFor('Sieht das Album, trägt nichts bei', seconds: 20));

      c.clearMessages();
      c.step('Einladungslink zum Teilen', 'Mit einem Space teilen, Einladungslink teilen.',
          'Android öffnet die Auswahl zum Teilen. Darin ein Link zum Teilen von Sommerurlaub 2026 und für den Notfall der Code.',
          kind: 'Abzweigung', explain: 'Wer den Link bekommt, braucht noch Annas Ja.');
      await scrollTo(c.find_('Mit einem Space teilen'));
      await c.tap('Mit einem Space teilen');
      c.screen('Einladen');
      await c.tap('Einladungslink teilen');
      c.screen('Album-Infos');
      await c.check('Text übergeben', () => eventually(() => share.text != null));
      await c.check('Mit Link', () => share.text!.contains('https://smileapp.app/i/'));
      await c.snap();

      // ---------------------------------------------------------------- Lena fragt an
      await c.back();
      await c.back();
      c.screen('Startseite');
      c.clearMessages();
      c.step('Lena fragt an', 'Lena möchte Geburtstage in ihrem Space sehen. Anna öffnet Geburtstage und oben den Namen.',
          'Bei Geteilt mit: Lena Huber, Möchte das Album mit dem eigenen Space sehen, mit Häkchen und Kreuz.',
          explain: 'Auch umgekehrt geht es: jemand bittet darum, ein Album im eigenen Space zu sehen.');
      await lena.insert('channel_share_requests',
          {'channel_id': birthdays, 'space_id': huber, 'direction': 'request', 'target_user_id': lena.id});
      await openInfo('Geburtstage');
      await scrollTo(c.find_('Möchte das Album mit dem eigenen Space sehen'));
      await c.check('Ganz zu lesen', () => c.fullyShown('Möchte das Album mit dem eigenen Space sehen'));
      await c.snap();

      c.clearMessages();
      c.step('Anfrage ablehnen', 'Auf das Kreuz (Ablehnen).', 'Die Anfrage ist weg.', kind: 'Abzweigung', explain: 'Lena bekommt Bescheid.');
      await c.tap('Ablehnen');
      await c.check('Server: abgelehnt', () => eventually(() async => (await lastShareRequest(birthdays))?['status'] == 'declined'));
      await c.check('Weg', () => c.gone('Möchte das Album mit dem eigenen Space sehen', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Anfrage annehmen', 'Lena fragt noch einmal. Auf das Häkchen (Annehmen).', 'Bei Geteilt mit steht Familie Huber.',
          explain: 'Familie Huber sieht Geburtstage jetzt.');
      await lena.insert('channel_share_requests',
          {'channel_id': birthdays, 'space_id': huber, 'direction': 'request', 'target_user_id': lena.id});
      await c.waitFor('Möchte das Album mit dem eigenen Space sehen', seconds: 20);
      await c.tap('Annehmen');
      await c.check('Server: geteilt', () => eventually(() => isShared(birthdays, huber)));
      await c.check('Familie Huber', () => c.waitFor('Sieht das Album, trägt nichts bei', seconds: 10));
      await c.snap();

      // ================================================================ Ein geteiltes Album bekommen
      // Anna has a second Space of her own by now (made in the app, chapter 2 shows how).
      await SpaceService().createSpace('Ferienwohnung');
      await c.back();
      await c.back();
      c.screen('Startseite');
      c.clearMessages();
      c.step('Teilen-Einladung bekommen', 'Lena möchte Bergtouren mit Annas Space teilen. Oben Neuigkeiten.',
          'Unter Einladungen: Bergtouren, Lena Huber möchte das Album mit deinem Space teilen, mit Häkchen und Kreuz.',
          explain: 'Anna hat inzwischen einen zweiten eigenen Space, die Ferienwohnung.');
      final shareToAnna = await lena.edge('invite-channel-share', {'channel_id': mountains, 'user_id': annaId});
      await c.check('Eingeladen', () => shareToAnna['status'] == 'invited');
      await openNews();
      await c.check('Einladung', () => c.waitFor('Lena Huber möchte das Album mit deinem Space teilen', seconds: 20));
      await c.check('Ganz zu lesen', () => c.fullyShown('Lena Huber möchte das Album mit deinem Space teilen'));
      await c.snap();

      c.clearMessages();
      c.step('Mit welchem Space?', 'Auf das Häkchen (Annehmen).',
          'Mit welchem Space? mit Familie Berger und Ferienwohnung. Familie Huber steht nicht da, Bergtouren gehört ja schon dorthin.',
          explain: 'Wer mehrere Spaces verwaltet, wählt, wo das Album zu sehen sein soll.');
      await c.tap('Annehmen');
      c.screen('Space-Auswahl');
      await c.check('Frage', () => c.waitFor('Mit welchem Space?', seconds: 5));
      await c.check('Familie Berger', () => c.waitFor('Familie Berger', seconds: 1));
      await c.check('Ferienwohnung', () => c.waitFor('Ferienwohnung', seconds: 1));
      await c.check('Nicht Familie Huber', () => c.gone('Familie Huber', seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Space-Auswahl: daneben tippen', 'Neben die Auswahl tippen.', 'Die Auswahl schließt sich, die Einladung bleibt.',
          kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Neuigkeiten');
      await c.check('Einladung bleibt', () => c.waitFor('Lena Huber möchte das Album mit deinem Space teilen', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Mit Familie Berger', 'Annehmen, dann Familie Berger.', 'Unten kurz: Bergtouren ist jetzt mit deinem Space geteilt.',
          explain: 'Familie Berger sieht Bergtouren jetzt, auch auf dem Frame.');
      await c.tap('Annehmen');
      c.screen('Space-Auswahl');
      await c.tap('Familie Berger', last: true);
      c.screen('Neuigkeiten');
      await c.check('Meldung', () => c.waitFor('Bergtouren ist jetzt mit deinem Space geteilt', seconds: 8));
      await c.check('Server: geteilt', () => eventually(() => isShared(mountains, berger)));
      await c.snap();

      // ---------------------------------------------------------------- Co-Admin-Rolle abgeben
      c.clearMessages();
      c.step('Co-Admin-Rolle abgeben', 'Zurück, unten Spaces, Familie Huber, bei Admins Du, Co-Admin-Rolle abgeben, Verlassen.',
          'Zurück auf Spaces; Familie Huber steht dort nicht mehr.', explain: 'Anna verwaltet Familie Huber nicht mehr mit.');
      await c.back();
      c.screen('Startseite');
      await openSpace('Familie Huber');
      await scrollTo(find.text('Du'));
      await tapExact('Du');
      c.screen('Co-Admin-Karte');
      await c.tap('Co-Admin-Rolle abgeben');
      c.screen('Abgeben-Frage');
      await c.tap('Verlassen', last: true);
      c.screen('Spaces');
      await c.check('Server: nicht mehr Co-Admin', () => eventually(() async => !await isCoAdmin(huber, annaId)));
      await c.check('Familie Huber weg', () => c.gone('Familie Huber', seconds: 10));
      await c.snap();

      await home();
      c.clearMessages();
      c.step('Ein geteiltes Album', 'Lena nimmt Anna aus Bergtouren. Auf der Startseite Bergtouren öffnen.',
          'Das Album Bergtouren; unten statt des Plus der Knopf Member werden.',
          explain: 'Als Co-Admin war Anna automatisch Member in Lenas Alben, das bleibt auch nach dem Abgeben (so beschlossen). '
              'Lena nimmt sie aus Bergtouren; jetzt sieht Anna es nur noch, weil es mit Familie Berger geteilt ist. Mitmachen kann sie, wenn Lena zustimmt.');
      await lena.delete('channel_members', 'channel_id=eq.$mountains&user_id=eq.$annaId');
      await until(ChannelFeedScreen, () => c.tap('Bergtouren'));
      c.screen('Album');
      await c.check('Member werden', () => c.waitFor('Member werden', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Member werden', 'Member werden antippen.', 'Der Knopf heißt jetzt Anfrage gesendet.',
          explain: 'Lena entscheidet, ob Anna auch Fotos senden darf.');
      await c.tap('Member werden');
      await c.check('Anfrage gesendet', () => c.waitFor('Anfrage gesendet', seconds: 8));
      await c.check('Server: Anfrage', () => eventually(() async => (await TestBackend.select('channel_membership_requests',
              'select=id&channel_id=eq.$mountains&user_id=eq.$annaId&direction=eq.request&status=eq.pending'))
          .isNotEmpty));
      await c.snap();

      c.clearMessages();
      c.step('Anfrage zurücknehmen', 'Anfrage gesendet antippen.', 'Wieder Member werden.', kind: 'Abzweigung',
          explain: 'Die Anfrage lässt sich zurücknehmen.');
      await c.tap('Anfrage gesendet');
      await c.check('Member werden', () => c.waitFor('Member werden', seconds: 8));
      await c.check('Server: keine Anfrage', () => eventually(() async => (await TestBackend.select('channel_membership_requests',
              'select=id&channel_id=eq.$mountains&user_id=eq.$annaId&direction=eq.request&status=eq.pending'))
          .isEmpty));
      await c.snap();

      c.clearMessages();
      c.step('Mit diesem Space geteilt', 'Zurück, unten Spaces, Familie Berger.',
          'Auf der Seite von Familie Berger: Mit diesem Space geteilt, darin Bergtouren · Viewer.',
          explain: 'Hier sieht Anna, welche fremden Alben ihr Space zeigt.');
      await c.back();
      c.screen('Startseite');
      await openSpace('Familie Berger');
      await scrollTo(c.find_('Mit diesem Space geteilt'));
      await c.check('Bergtouren', () => c.waitFor('Bergtouren', seconds: 5));
      await c.snap();

      Future<void> sharedInCard() async {
        await scrollTo(c.find_('Bergtouren'));
        await c.tap('Bergtouren', last: true);
        c.screen('Geteilt-Karte');
        await c.waitFor('Nicht mehr anzeigen', seconds: 5);
      }

      c.clearMessages();
      c.step('Nicht mehr anzeigen: Abbrechen', 'Bergtouren antippen, Nicht mehr anzeigen, dann Abbrechen.',
          'Die Frage Bergtouren nicht mehr anzeigen? Danach bleibt alles.', kind: 'Abzweigung', explain: 'Smile fragt vorher.');
      await sharedInCard();
      await c.tap('Nicht mehr anzeigen', last: true);
      c.screen('Anzeigen-Frage');
      await c.check('Frage', () => c.waitFor('Bergtouren nicht mehr anzeigen?', seconds: 3));
      await c.snap();
      await c.tap('Abbrechen');
      c.screen('Space');
      await c.check('Server: weiter geteilt', () => isShared(mountains, berger));

      c.clearMessages();
      c.step('Nicht mehr anzeigen: daneben tippen', 'Wieder öffnen, dann oben neben die Frage tippen.', 'Die Frage schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Wie Abbrechen.');
      await sharedInCard();
      await c.tap('Nicht mehr anzeigen', last: true);
      c.screen('Anzeigen-Frage');
      await c.waitFor('Bergtouren nicht mehr anzeigen?', seconds: 3);
      await c.tapAt(const Offset(200, 80), 'Schließen');
      c.screen('Space');
      await c.check('Zu', () => c.gone('Bergtouren nicht mehr anzeigen?', seconds: 3));
      await c.check('Server: unverändert', () => isShared(mountains, berger));
      await c.snap();

      c.clearMessages();
      c.step('Nicht mehr anzeigen', 'Bergtouren, Nicht mehr anzeigen, Nicht mehr anzeigen.', 'Mit diesem Space geteilt ist verschwunden.',
          explain: 'Familie Berger und ihr Frame zeigen Bergtouren nicht mehr.');
      await sharedInCard();
      await c.tap('Nicht mehr anzeigen', last: true);
      c.screen('Anzeigen-Frage');
      await c.tap('Nicht mehr anzeigen', last: true);
      c.screen('Space');
      await c.check('Server: nicht mehr geteilt', () => eventually(() async => !await isShared(mountains, berger)));
      await c.check('Abschnitt weg', () => c.gone('Mit diesem Space geteilt', seconds: 8));
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
