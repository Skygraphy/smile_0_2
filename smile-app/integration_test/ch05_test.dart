// Kapitel 5: Leute einladen (tools/testsuite, 2026-10-22).
// Startet dort, wo Kapitel 4 endet: auf der Seite des Albums Geburtstage.
// Paul, Lena und Tom haben hier kein Gerät: sie handeln per Skript, mit
// eigener Anmeldung und nur ihren eigenen Rechten, wie die App für sie.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/album_info_screen.dart';
import 'package:smile_app/screens/channel_feed_screen.dart';
import 'package:smile_app/services/invite_links.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

const paulMail = 'paul.berger@example.com';
const lenaMail = 'lena.huber@example.com';
const tomMail = 'tom.berger@example.com';

/// Android's share sheet is not Smile: in the test, what Smile hands to it is caught.
class _CaughtShare extends SharePlatform {
  String? text;
  @override
  Future<ShareResult> share(ShareParams params) async {
    text = params.text;
    return const ShareResult('test', ShareResultStatus.success);
  }
}

/// Neither is the SMS app: the address Smile opens is caught.
class _CaughtLaunch extends UrlLauncherPlatform {
  String? url;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    return true;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;
}

/// An invented phone book (never the real one on the phone): three people
/// who have Smile, and more than twelve who don't, so the A-Z rail shows.
List<Map<String, Object?>> _phoneBook() {
  Map<String, Object?> entry(String id, String name, {String? phone, String? email}) => {
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
  var n = 0;
  String num() => '+43 660 000 ${(++n).toString().padLeft(4, '0')}';
  return [
    entry('1', 'Paul Berger', phone: num(), email: paulMail),
    entry('2', 'Lena Huber', email: lenaMail),
    entry('3', 'Tom Berger', phone: num(), email: tomMail),
    for (final (i, name) in [
      'Max Moser', 'Sophie Wagner', 'Andrea Bauer', 'Bernd Gruber', 'Doris Pichler', 'Emil Steiner', 'Franz Hofer',
      'Gerda Leitner', 'Hannes Wimmer', 'Ines Egger', 'Jakob Fuchs', 'Klara Brunner', 'Zoe Winkler',
    ].indexed)
      entry('${10 + i}', name, phone: num()),
  ];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 5: Leute einladen', (tester) async {
    final semantics = tester.ensureSemantics();
    final share = _CaughtShare();
    SharePlatform.instance = share;
    final launch = _CaughtLaunch();
    UrlLauncherPlatform.instance = launch;
    // The phone book: first not allowed, then allowed in the settings.
    var contactsAllowed = 'notDetermined';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('flutter_contacts'), (call) async {
      switch (call.method) {
        case 'permissions.check':
          return contactsAllowed;
        case 'permissions.request':
          return contactsAllowed == 'granted' ? 'granted' : 'denied';
        case 'permissions.openSettings':
          contactsAllowed = 'granted';
          return null;
        case 'crud.getAll':
          return _phoneBook();
      }
      return null;
    });

    final c = Chapter(tester, binding,
        id: 'ch05',
        title: 'Leute einladen',
        intro: 'Anna holt Leute in ihr Album Geburtstage: per Smile-Name, mit dem QR-Code, mit einem Link, per E-Mail und aus '
            'ihren Kontakten. Sie nimmt Anfragen an oder lehnt sie ab und entfernt jemanden wieder. Dann wird Anna selbst '
            'eingeladen, gibt einen Code ein und verlässt ein Album. Zum Schluss sieht man, wie Tom als Neuling eine Einladung annimmt.');

    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand (Ende Kapitel 4)
      await freshAnna(tester, c);
      final support = (await getApplicationSupportDirectory()).path;
      Future<void> picture(String mail, String file) async =>
          TestBackend.setAvatar(mail, await File('$support/fixtures/profiles/$file').readAsBytes(), 'image/png');
      await picture(paulMail, 'mann_mittel.png');
      await TestBackend.person(lenaMail, 'Lena Huber', handle: 'lena.huber');
      await picture(lenaMail, 'frau_jung.png');
      await TestBackend.person(tomMail, 'Tom Berger', handle: 'tom.berger');
      await picture(tomMail, 'mann_jung.png');
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter4(tester);
      final birthdays = seed.albums['Geburtstage']!;
      final annaId = await TestBackend.userId(anna);
      final paul = await TestUser.signIn(paulMail);
      final lena = await TestUser.signIn(lenaMail);
      final tom = await TestUser.signIn(tomMail);

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<List<Map>> requests(String album) async => (await TestBackend.select(
              'channel_membership_requests', 'select=id,user_id,direction,status&channel_id=eq.$album&order=requested_at.asc'))
          .cast<Map>();
      Future<Map?> requestOf(String album, String userId) async =>
          (await requests(album)).where((r) => r['user_id'] == userId).lastOrNull;
      Future<bool> isMember(String album, String userId) async =>
          (await TestBackend.select('channel_members', 'select=user_id&channel_id=eq.$album&user_id=eq.$userId')).isNotEmpty;
      Future<String> activeCode(String album) async => (await TestBackend.select('invite_codes',
              'select=code&target_id=eq.$album&revoked_at=is.null&order=created_at.desc&limit=1'))
          .first['code'] as String;
      String pretty(String code) => '${code.substring(0, 3)}-${code.substring(3)}';
      Future<void> tapExact(String text) async {
        await tester.tap(find.text(text).last, warnIfMissed: false);
        c.logTap(text);
        await c.settle();
      }

      Future<void> openInfo(String album) async {
        // The list may just be rebuilding (sync) and swallow a tap: until the
        // album's own bar is there (the start page has a ⋮ too).
        final feed = find.byType(ChannelFeedScreen);
        for (var i = 0; i < 3 && feed.evaluate().isEmpty; i++) {
          await c.tap(album);
          for (var t = 0; t < 40 && feed.evaluate().isEmpty; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        c.screen('Album');
        // Then its name at the top (Kapitel 2) -- an album of someone else's
        // Space has no menu with Infos zum Album for a Member.
        // Only tapped again if the page really isn't coming (it was opened
        // twice once, 2026-10-22).
        final info = find.byType(AlbumInfoScreen, skipOffstage: false);
        for (var i = 0; i < 3 && info.evaluate().isEmpty; i++) {
          await c.settle(max: const Duration(seconds: 2));
          await c.tap(album, last: true);
          for (var t = 0; t < 60 && info.evaluate().isEmpty; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        c.screen('Album-Infos');
        await c.waitFor('Album verlassen', seconds: 10);
      }

      Future<void> signOut() async {
        await c.tap('Weitere Optionen');
        c.screen('Menü');
        await c.tap('Einstellungen');
        c.screen('Einstellungen');
        await tester.scrollUntilVisible(c.find_('Abmelden'), 300, scrollable: find.byType(Scrollable).first);
        await c.tap('Abmelden');
        c.screen('Abmelden-Frage');
        await c.waitFor('Möchtest du dich wirklich abmelden', seconds: 5);
        await c.tap('Abmelden', last: true);
      }

      /// "Code eintippen" -- once the page has really arrived (a tap during
      /// the transition goes nowhere).
      Future<void> openCodeDialog() async {
        await c.waitFor('QR-Code in den Rahmen halten', seconds: 10);
        for (var i = 0; i < 3; i++) {
          await c.settle();
          await c.tap('Code eintippen', last: true);
          if (await c.waitFor('z. B.', seconds: 4)) break;
        }
        c.screen('Code-Frage');
      }

      await c.waitFor('Geburtstage', seconds: 15);
      await c.hideKeyboard();
      await openInfo('Geburtstage');
      await c.start();

      // ================================================================ Per Smile-Name
      c.clearMessages();
      c.step('Ausgangslage', 'Smile ist geöffnet, Anna ist auf der Seite des Albums Geburtstage.',
          'Oben Einladen und Mit Space teilen. Bei den Personen nur Anna selbst (Du) als Admin.',
          explain: 'So endet Kapitel 4. Im Album ist bisher nur Anna.');
      await c.check('Nur Anna im Album', () async =>
          (await TestBackend.select('channel_members', 'select=user_id&channel_id=eq.$birthdays')).length == 1);
      await c.check('1 Person', () => c.waitFor('1 Person', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Einladen öffnen', 'Oben auf Einladen tippen.',
          'Von unten erscheint In Geburtstage einladen: ein Suchfeld, der Hinweis, dass Anna in Smile noch niemanden kennt, '
              'und darunter Aus Kontakten, QR-Code zeigen, Einladungslink teilen und Per E-Mail einladen.',
          explain: 'Wie bei WhatsApp: zuerst die Leute, die man schon kennt, dann die anderen Wege.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.check('Titel', () => c.waitFor('In Geburtstage einladen', seconds: 5));
      await c.check('Noch niemand bekannt', () => c.waitFor('Noch niemand, den du in Smile kennst', seconds: 5));
      await c.check('Vier Wege', () async =>
          await c.waitFor('Aus Kontakten', seconds: 2) &&
          await c.waitFor('QR-Code zeigen', seconds: 1) &&
          await c.waitFor('Einladungslink teilen', seconds: 1) &&
          await c.waitFor('Per E-Mail einladen', seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Einladen: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich, wieder die Seite des Albums.',
          kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Album-Infos');
      await c.check('Auswahl zu', () => c.gone('In Geburtstage einladen', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Suche: nur der Name', 'Wieder Einladen, dann ins Suchfeld Paul eingeben.',
          'Niemand gefunden. Fremde nur mit ganzem @Smile-Namen.',
          kind: 'Abzweigung',
          explain: 'Wen man noch nicht aus einem gemeinsamen Album kennt, findet man nicht über den Namen. So kann niemand einfach Fremde suchen.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.typeInto('Name oder @Smile-Name', 'Paul');
      await c.hideKeyboard();
      await c.check('Niemand gefunden', () => c.waitFor('Niemand gefunden', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Suche: ganzer Smile-Name', 'Stattdessen @paul.berger eingeben.', 'Paul Berger erscheint mit Bild und @paul.berger.',
          explain: 'Mit dem ganzen Smile-Namen findet man genau diese eine Person.');
      await c.typeInto('Name oder @Smile-Name', '@paul.berger');
      await c.hideKeyboard();
      await c.check('Paul gefunden', () => c.waitFor('Paul Berger', seconds: 8));
      // His picture, not the initials shown while it loads (0.0.15 review).
      await c.check('Mit Bild', () => c.gone('PB', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Paul einladen', 'Auf Paul Berger tippen.',
          'Unten kurz: Einladung an Paul Berger gesendet. Bei den Personen steht Paul mit Eingeladen · Annahme ausstehend.',
          explain: 'Paul muss die Einladung noch annehmen. Bis dahin ist er nicht im Album.');
      await c.tap('Paul Berger', last: true);
      c.screen('Album-Infos');
      await c.check('Meldung', () => c.waitFor('Einladung an Paul Berger gesendet', seconds: 8));
      await c.check('Offene Einladung im Server', () async => (await requestOf(birthdays, paul.id))?['status'] == 'pending');
      await c.check('Wartet', () => c.waitFor('Eingeladen · Annahme ausstehend', seconds: 8));
      await c.check('Ganz zu lesen, nicht abgeschnitten', () => c.fullyShown('Eingeladen · Annahme ausstehend'));
      await c.snap();

      c.clearMessages();
      c.step('Einladung zurückziehen', 'Rechts neben Paul auf das Kreuz (Zurückziehen) tippen.',
          'Paul verschwindet aus der Liste.', kind: 'Abzweigung',
          explain: 'Solange Paul nicht angenommen hat, kann Anna die Einladung zurücknehmen.');
      await c.tap('Zurückziehen');
      await c.check('Einladung weg im Server', () => eventually(() async => await requestOf(birthdays, paul.id) == null));
      await c.check('Paul weg', () => c.gone('Paul Berger', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Person einladen', 'Unten bei den Personen auf Person einladen tippen, @paul.berger suchen und Paul antippen.',
          'Paul steht wieder mit Eingeladen · Annahme ausstehend da.',
          kind: 'Abzweigung', explain: 'Person einladen öffnet dasselbe wie Einladen oben.');
      await tester.scrollUntilVisible(c.find_('Person einladen'), 300, scrollable: find.byType(Scrollable).first);
      await c.tap('Person einladen');
      c.screen('Einladen');
      await c.typeInto('Name oder @Smile-Name', '@paul.berger');
      await c.hideKeyboard();
      await c.tap('Paul Berger', last: true, seconds: 8);
      c.screen('Album-Infos');
      await c.check('Wartet wieder', () => c.waitFor('Eingeladen · Annahme ausstehend', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Paul nimmt an', 'Nichts tun: Paul nimmt die Einladung auf seinem Handy an.',
          'Ohne Zutun steht Paul jetzt als Member in der Liste, oben 2 Personen.',
          explain: 'Was Paul auf seinem Handy macht, kommt bei Anna von selbst an.');
      final paulInvite = (await requestOf(birthdays, paul.id))!['id'];
      await paul.patch('channel_membership_requests', 'id=eq.$paulInvite', {'status': 'accepted'});
      await c.check('Paul im Album', () => eventually(() => isMember(birthdays, paul.id)));
      await c.check('2 Personen', () => c.waitFor('2 Personen', seconds: 20));
      await c.check('Nicht mehr wartend', () => c.gone('Eingeladen · Annahme ausstehend', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Personenkarte', 'Auf Paul Berger tippen.',
          'Von unten: Pauls Bild, sein Name, Member und Stellt Fotos und Videos ins Album. Darunter Aus dem Album entfernen.',
          explain: 'Jede Person in der Liste lässt sich antippen und zeigt, was ihre Rolle bedeutet.');
      await c.tap('Paul Berger');
      c.screen('Personenkarte');
      await c.check('Rolle erklärt', () => c.waitFor('Stellt Fotos und Videos ins Album', seconds: 5));
      await c.check('Entfernen angeboten', () => c.waitFor('Aus dem Album entfernen', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Entfernen: Abbrechen', 'Aus dem Album entfernen, dann Abbrechen.', 'Die Frage schließt sich, Paul bleibt im Album.',
          kind: 'Abzweigung', explain: 'Smile fragt vorher nach.');
      await c.tap('Aus dem Album entfernen');
      c.screen('Entfernen-Frage');
      await c.check('Frage', () => c.waitFor('Paul Berger entfernen?', seconds: 5));
      await c.tap('Abbrechen');
      c.screen('Album-Infos');
      await c.check('Paul bleibt', () async => await c.waitFor('2 Personen', seconds: 3) && await isMember(birthdays, paul.id));
      await c.snap();

      c.clearMessages();
      c.step('Aus dem Album entfernen', 'Paul antippen, Aus dem Album entfernen, dann Entfernen.',
          'Paul verschwindet aus der Liste, oben wieder 1 Person.',
          explain: 'Paul sieht das Album danach nicht mehr. Seine Fotos bleiben im Album.');
      await c.tap('Paul Berger');
      c.screen('Personenkarte');
      await c.tap('Aus dem Album entfernen');
      c.screen('Entfernen-Frage');
      await c.waitFor('Paul Berger entfernen?', seconds: 5);
      await c.tap('Entfernen', last: true);
      c.screen('Album-Infos');
      await c.check('Paul nicht mehr im Album', () => eventually(() async => !await isMember(birthdays, paul.id)));
      await c.check('1 Person', () => c.waitFor('1 Person', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Die eigene Karte', 'Auf Du tippen.',
          'Von unten: Annas Bild, Du, Admin und Hat den Space angelegt und verwaltet alles. Darunter Profil bearbeiten.',
          kind: 'Abzweigung', explain: 'Die eigene Karte führt zum eigenen Profil. Sich selbst kann man hier nicht entfernen.');
      await tapExact('Du');
      c.screen('Personenkarte');
      await c.check('Admin erklärt', () => c.waitFor('Hat den Space angelegt', seconds: 5));
      await c.check('Profil bearbeiten', () => c.waitFor('Profil bearbeiten', seconds: 2));
      await c.check('Kein Entfernen', () => c.gone('Aus dem Album entfernen', seconds: 1));
      await c.snap();

      c.clearMessages();
      c.step('Karte schließen', 'Oben neben die Karte tippen.', 'Wieder die Seite des Albums.', kind: 'Abzweigung',
          explain: 'Die Karte schließt sich.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Album-Infos');
      await c.check('Karte zu', () => c.gone('Profil bearbeiten', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Von der Karte zum Profil', 'Auf Du tippen, dann Profil bearbeiten.', 'Die Einstellungen mit Annas Bild, Name und Smile-Name.',
          kind: 'Abzweigung', explain: 'Dort ändert man Bild und Namen (Kapitel 1).');
      await tapExact('Du');
      c.screen('Personenkarte');
      await c.tap('Profil bearbeiten');
      c.screen('Einstellungen');
      await c.check('Einstellungen', () => c.waitFor('@anna.berger', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Zurück zum Album', 'Oben links zurück.', 'Wieder die Seite des Albums.', kind: 'Abzweigung',
          explain: 'Die Einstellungen schließen sich.');
      await c.back();
      c.screen('Album-Infos');
      await c.check('Album-Seite', () => c.waitFor('Person einladen', seconds: 5));
      await c.snap();

      // ================================================================ QR-Code
      c.clearMessages();
      c.step('QR-Code zeigen', 'Einladen, dann QR-Code zeigen.',
          'Eine Seite mit einem großen QR-Code, darunter ein Code wie K7P-2QX, eine Erklärung, Gilt 24 Stunden und Neuen Code erstellen.',
          explain: 'Für jemanden, der neben einem steht: Wer den QR-Code scannt, ist sofort im Album.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('QR-Code zeigen');
      c.screen('QR-Code');
      await c.check('Gilt 24 Stunden', () => c.waitFor('Gilt 24 Stunden', seconds: 10));
      final firstCode = await activeCode(birthdays);
      await c.check('Code wie im Server', () => c.waitFor(pretty(firstCode), seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Neuen Code erstellen', 'Auf Neuen Code erstellen tippen.', 'Ein anderer QR-Code und ein anderer Code erscheinen.',
          kind: 'Abzweigung', explain: 'Der alte Code gilt dann nicht mehr, zum Beispiel wenn ihn jemand Falsches gesehen hat.');
      await c.tap('Neuen Code erstellen');
      await c.check('Neuer Code im Server', () => eventually(() async => await activeCode(birthdays) != firstCode));
      final code = await activeCode(birthdays);
      await c.check('Neuer Code angezeigt', () => c.waitFor(pretty(code), seconds: 5));
      await c.check('Alter Code gilt nicht mehr', () async =>
          (await paul.edge('redeem-invite-code', {'code': firstCode, 'via': 'qr'}))['error'] == 'invalid_code');
      await c.snap();

      c.clearMessages();
      c.step('Paul scannt den QR-Code', 'Paul hält sein Handy auf den QR-Code. Dann oben links zurück.',
          'Auf der Seite des Albums steht Paul sofort als Member, ohne dass Anna etwas bestätigt.',
          explain: 'Wer den QR-Code scannt, steht neben Anna. Darum muss sie nicht noch einmal zustimmen.');
      final scanned = await paul.edge('redeem-invite-code', {'code': code, 'via': 'qr'});
      await c.check('Paul ist drin', () => scanned['status'] == 'joined');
      await c.back();
      c.screen('Album-Infos');
      await c.check('2 Personen', () => c.waitFor('2 Personen', seconds: 20));
      await c.check('Paul in der Liste', () => c.waitFor('Paul Berger', seconds: 3));
      await c.snap();

      // ================================================================ Link und Anfrage
      c.clearMessages();
      c.step('Einladungslink teilen', 'Einladen, dann Einladungslink teilen.',
          'Android öffnet die Auswahl zum Teilen (WhatsApp, SMS und so weiter). Darin steht: Komm in mein Smile-Album Geburtstage! '
              'mit einem Link und für den Notfall der Code.',
          explain: 'Den Link kann Anna zum Beispiel per WhatsApp schicken. Wer ihn so bekommt, braucht noch ihr Ja.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('Einladungslink teilen');
      c.screen('Album-Infos');
      await c.check('Text übergeben', () => eventually(() => share.text != null));
      await c.check('Mit Link', () => share.text!.contains('https://smileapp.app/i/$code') && !share.text!.contains('s=1'));
      await c.check('Mit Code für den Notfall', () => share.text!.contains(pretty(code)));
      await c.snap();

      c.clearMessages();
      c.step('Lena fragt an', 'Nichts tun: Lena hat den Link bekommen und tippt ihn an.',
          'Bei den Personen erscheint Lena Huber mit Möchte Member werden, rechts ein Häkchen und ein Kreuz.',
          explain: 'Über einen Link kommt man nicht sofort ins Album: Anna entscheidet.');
      final lenaAsk = await lena.edge('redeem-invite-code', {'code': code, 'via': 'typed'});
      await c.check('Anfrage im Server', () => lenaAsk['status'] == 'requested');
      await c.check('Lena fragt', () => c.waitFor('Möchte Member werden', seconds: 20));
      await c.check('Ganz zu lesen, nicht abgeschnitten', () => c.fullyShown('Möchte Member werden'));
      await c.letLoad();
      await c.snap();

      c.clearMessages();
      c.step('Anfrage ablehnen', 'Rechts neben Lena auf das Kreuz (Ablehnen) tippen.', 'Lena verschwindet aus der Liste.',
          kind: 'Abzweigung', explain: 'Lena kommt nicht ins Album.');
      await c.tap('Ablehnen');
      await c.check('Abgelehnt im Server', () => eventually(() async => (await requestOf(birthdays, lena.id))?['status'] == 'declined'));
      await c.check('Lena weg', () => c.gone('Lena Huber', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Anfrage annehmen', 'Lena fragt noch einmal. Diesmal rechts auf das Häkchen (Annehmen) tippen.',
          'Lena steht jetzt als Member in der Liste, oben 3 Personen.',
          explain: 'Lena ist im Album und kann Fotos und Videos senden.');
      final lenaAgain = await lena.edge('redeem-invite-code', {'code': code, 'via': 'typed'});
      await c.check('Zweite Anfrage', () => lenaAgain['status'] == 'requested');
      await c.waitFor('Möchte Member werden', seconds: 20);
      await c.tap('Annehmen');
      await c.check('Lena im Album', () => eventually(() => isMember(birthdays, lena.id)));
      await c.check('3 Personen', () => c.waitFor('3 Personen', seconds: 8));
      await c.snap();

      // ================================================================ Per E-Mail
      c.clearMessages();
      c.step('Per E-Mail: Abbrechen', 'Einladen, Per E-Mail einladen, dann Abbrechen.',
          'Zuerst fragt Smile nach der E-Mail-Adresse. Nach Abbrechen ist die Frage weg.', kind: 'Abzweigung',
          explain: 'Ohne Adresse passiert nichts.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('Per E-Mail einladen');
      c.screen('E-Mail-Frage');
      await c.check('Frage', () => c.waitFor('Die Person braucht bereits einen Smile-Account', seconds: 5));
      await c.tap('Abbrechen');
      c.screen('Album-Infos');
      await c.check('Frage weg', () => c.gone('Die Person braucht bereits', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Per E-Mail: ohne Smile', 'Einladen, Per E-Mail einladen, sophie.wagner@example.com eingeben, Einladen.',
          'Auf der Seite steht: Diese Person hat noch keinen Smile-Account.', kind: 'Abzweigung',
          explain: 'Per E-Mail geht es nur mit Leuten, die schon Smile haben. Für alle anderen gibt es den Link oder die Kontakte.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('Per E-Mail einladen');
      c.screen('E-Mail-Frage');
      await c.typeInto('E-Mail-Adresse', 'sophie.wagner@example.com');
      await c.tap('Einladen', last: true);
      c.screen('Album-Infos');
      await c.check('Freundlicher Hinweis', () => c.waitFor('Diese Person hat noch keinen Smile-Account', seconds: 8));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Per E-Mail einladen', 'Einladen, Per E-Mail einladen, tom.berger@example.com eingeben, Einladen.',
          'Der Hinweis ist weg. Bei den Personen steht Tom Berger mit Eingeladen · Annahme ausstehend.',
          explain: 'Tom hat Smile schon. Er findet die Einladung bei sich in den Neuigkeiten.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('Per E-Mail einladen');
      c.screen('E-Mail-Frage');
      await c.typeInto('E-Mail-Adresse', tomMail);
      await c.tap('Einladen', last: true);
      c.screen('Album-Infos');
      await c.check('Einladung im Server', () => eventually(() async => (await requestOf(birthdays, tom.id))?['status'] == 'pending'));
      await c.check('Tom wartet', () => c.waitFor('Eingeladen · Annahme ausstehend', seconds: 8));
      await c.letLoad();
      await c.check('Hinweis weg', () => c.gone('Diese Person hat noch keinen', seconds: 3));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Tom lehnt ab', 'Nichts tun: Tom lehnt die Einladung auf seinem Handy ab.', 'Tom verschwindet aus der Liste.',
          kind: 'Abzweigung', explain: 'Eine Einladung kann man auch ablehnen. Anna sieht dann einfach niemanden mehr warten.');
      final tomInvite = (await requestOf(birthdays, tom.id))!['id'];
      await tom.patch('channel_membership_requests', 'id=eq.$tomInvite', {'status': 'declined'});
      await c.check('Tom weg', () => c.gone('Tom Berger', seconds: 20));
      await c.snap();

      // ================================================================ Aus Kontakten
      c.clearMessages();
      c.step('Kontakte: die Erklärung', 'Einladen, dann Aus Kontakten.',
          'Kontakte in Smile finden: was Smile mit dem Telefonbuch macht, unten Weiter und Nicht jetzt.',
          explain: 'Bevor Android nach dem Telefonbuch fragt, erklärt Smile, wozu.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('Aus Kontakten');
      c.screen('Kontakte');
      await c.check('Erklärung', () => c.waitFor('Kontakte in Smile finden', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Kontakte: Nicht jetzt', 'Nicht jetzt antippen.', 'Wieder die Seite des Albums. Android hat nichts gefragt.',
          kind: 'Abzweigung', explain: 'Ohne Weiter fragt Android gar nicht erst nach dem Telefonbuch.');
      await c.tap('Nicht jetzt');
      c.screen('Album-Infos');
      await c.check('Album-Seite', () => c.waitFor('Person einladen', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Kontakte: nicht erlaubt', 'Einladen, Aus Kontakten, Weiter. Android fragt, ob Smile die Kontakte sehen darf: Nicht zulassen.',
          'Smile darf deine Kontakte noch nicht sehen. Du kannst es in den Einstellungen erlauben. Darunter Einstellungen öffnen.',
          kind: 'Abzweigung', explain: 'Ohne Erlaubnis sieht Smile nichts vom Telefonbuch.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('Aus Kontakten');
      c.screen('Kontakte');
      await c.tap('Weiter');
      await c.check('Hinweis', () => c.waitFor('Smile darf deine Kontakte noch nicht sehen', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Kontakte: zurück', 'Oben links zurück.', 'Wieder die Seite des Albums.', kind: 'Abzweigung',
          explain: 'Die Kontakte schließen sich.');
      await c.back();
      c.screen('Album-Infos');
      await c.check('Album-Seite', () => c.waitFor('Person einladen', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Kontakte: erlauben', 'Einladen, Aus Kontakten, Weiter, wieder nicht zulassen. Dann Einstellungen öffnen, dort Kontakte erlauben und zurück zu Smile.',
          'Die Kontakte: oben IN SMILE mit Paul, Lena (beide blass, Schon im Album) und Tom (Einladen), darunter NOCH NICHT IN SMILE '
              'von A bis Z, rechts eine Buchstabenleiste.',
          explain: 'Smile prüft nur verschlüsselt, wer schon Smile hat. Die Adressen selbst verlassen das Handy nicht.');
      await c.tap('Einladen');
      c.screen('Einladen');
      await c.tap('Aus Kontakten');
      c.screen('Kontakte');
      await c.tap('Weiter');
      await c.waitFor('Smile darf deine Kontakte noch nicht sehen', seconds: 8);
      await c.tap('Einstellungen öffnen');
      await c.check('In Smile', () => c.waitFor('IN SMILE', seconds: 10));
      await c.check('Tom einladbar', () => c.waitFor('in Smile: Tom Berger', seconds: 5));
      await c.check('Paul und Lena schon im Album', () => find.text('Schon im Album').evaluate().length == 2);
      await c.check('Noch nicht in Smile', () => c.waitFor('NOCH NICHT IN SMILE', seconds: 2));
      await c.letLoad();
      await c.snap();

      c.clearMessages();
      c.step('Buchstabenleiste', 'Rechts in der Leiste auf M tippen.', 'Die Liste springt nach unten zu M, Max Moser ist zu sehen. Weil danach nur noch wenige Kontakte kommen, steht oben schon I.',
          kind: 'Abzweigung', explain: 'Wie im Telefonbuch von Android: ein Tipp auf einen Buchstaben springt dorthin.');
      await tester.tap(find.text('M').last, warnIfMissed: false);
      c.logTap('Buchstabenleiste');
      await c.settle();
      await c.check('Max Moser sichtbar', () => c.waitFor('Max Moser', seconds: 3));
      await c.check('Andrea Bauer nicht mehr', () => c.gone('Andrea Bauer', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Kontakt suchen', 'Oben ins Suchfeld Max eingeben.', 'Nur noch Max Moser.', kind: 'Abzweigung',
          explain: 'Die Suche findet Namen, Nummern und Adressen.');
      await c.typeInto('Kontakt suchen', 'Max');
      await c.hideKeyboard();
      await c.check('Max', () => c.waitFor('Max Moser', seconds: 5));
      await c.check('Sonst niemand', () => c.gone('Tom Berger', seconds: 2));
      await c.snap();

      c.clearMessages();
      c.step('Kontakt ohne Smile', 'Max Moser antippen.',
          'Einladung zu Smile senden: Max Moser hat noch kein Smile. Darunter die Nachricht mit Link, Per SMS senden und Per WhatsApp senden.',
          explain: 'Wer noch kein Smile hat, bekommt eine Nachricht mit dem Link.');
      await c.tap('Max Moser');
      c.screen('Kontakt einladen');
      await c.check('Frage', () => c.waitFor('Einladung zu Smile senden', seconds: 8));
      await c.check('SMS', () => c.waitFor('Per SMS senden', seconds: 5));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Einladung zu Smile: daneben tippen', 'Oben neben die Einladung tippen.', 'Die Einladung schließt sich, nichts wurde gesendet.',
          kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Kontakte');
      await c.check('Zu', () => c.gone('Einladung zu Smile senden', seconds: 5));
      await c.check('Nichts gesendet', () => launch.url == null);
      await c.snap();

      c.clearMessages();
      c.step('Einladung zu Smile: Nicht jetzt', 'Max Moser antippen, dann Nicht jetzt.', 'Die Einladung schließt sich, nichts wurde gesendet.',
          kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tap('Max Moser');
      c.screen('Kontakt einladen');
      await c.waitFor('Per SMS senden', seconds: 5);
      await c.tap('Nicht jetzt', last: true);
      c.screen('Kontakte');
      await c.check('Zu', () => c.gone('Einladung zu Smile senden', seconds: 5));
      await c.check('Nichts gesendet', () => launch.url == null);
      await c.snap();

      c.clearMessages();
      c.step('Nachricht ändern', 'Max Moser antippen und am Ende der Nachricht Liebe Grüße, Anna anfügen.',
          'In der Nachricht steht am Ende Liebe Grüße, Anna. Der Link bleibt.', kind: 'Abzweigung',
          explain: 'Die Nachricht kann man vor dem Senden selbst ändern.');
      await c.tap('Max Moser');
      c.screen('Kontakt einladen');
      await c.waitFor('Per SMS senden', seconds: 5);
      final messageField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Nachricht');
      final message = tester.widget<TextField>(messageField).controller!.text;
      await c.typeInto('Nachricht', '$message Liebe Grüße, Anna');
      await c.hideKeyboard();
      await c.check('Angefügt', () => c.waitFor('~Liebe Grüße, Anna', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Per SMS senden', 'Per SMS senden antippen.',
          'Die SMS-App öffnet sich mit Max Mosers Nummer und der Nachricht. Zurück in Smile ist wieder die Kontaktliste da.',
          explain: 'Max bekommt die Einladung per SMS. Mit dem Link kann er Smile laden und ist danach gleich beim Album.');
      await c.tap('Per SMS senden');
      c.screen('Kontakte');
      await c.check('SMS-App aufgerufen', () => eventually(() => launch.url != null));
      await c.check('An Max', () => launch.url!.startsWith('sms:+436600000'));
      await c.check('Mit Link', () => Uri.decodeComponent(launch.url!).contains('https://smileapp.app/i/$code'));
      await c.check('Mit Annas Gruß', () => Uri.decodeComponent(launch.url!).contains('Liebe Grüße, Anna'));
      await c.check('Liste wieder da', () => c.waitFor('Max Moser', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Per WhatsApp senden', 'Max Moser antippen, dann Per WhatsApp senden.',
          'WhatsApp öffnet sich mit dem Chat von Max Moser und der Nachricht. Zurück in Smile ist wieder die Kontaktliste da.',
          kind: 'Abzweigung', explain: 'Statt per SMS geht die Einladung über WhatsApp.');
      launch.url = null;
      await c.tap('Max Moser');
      c.screen('Kontakt einladen');
      await c.tap('Per WhatsApp senden');
      c.screen('Kontakte');
      await c.check('WhatsApp aufgerufen', () => eventually(() => launch.url != null));
      await c.check('An Max', () => launch.url!.startsWith('https://wa.me/436600000'));
      await c.check('Mit Link', () => Uri.decodeComponent(launch.url!).contains('https://smileapp.app/i/$code'));
      await c.check('Liste wieder da', () => c.waitFor('Max Moser', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Kontakt mit Smile', 'Das Suchfeld leeren und bei Tom Berger auf Einladen tippen.',
          'Zurück auf der Seite des Albums: Einladung an Tom Berger gesendet, Tom wartet auf die Annahme.',
          explain: 'Tom hat Smile schon. Er bekommt die Einladung direkt in Smile.');
      await c.typeInto('Kontakt suchen', '', logAs: 'Suchfeld leeren');
      await c.hideKeyboard();
      await c.tap('Tom Berger');
      c.screen('Album-Infos');
      await c.check('Meldung', () => c.waitFor('Einladung an Tom Berger gesendet', seconds: 8));
      await c.check('Einladung im Server', () => eventually(() async => (await requestOf(birthdays, tom.id))?['status'] == 'pending'));
      await c.check('Tom wartet', () => c.waitFor('Eingeladen · Annahme ausstehend', seconds: 8));
      await c.letLoad();
      await c.snap();

      // ================================================================ Anna wird eingeladen
      final lenaSpace = (await lena.insert('spaces', {'name': 'Familie Huber'})).first['id'];
      final hiking = (await lena.insert('channels', {'space_id': lenaSpace, 'name': 'Wanderungen'})).first['id'] as String;
      final mountains = (await lena.insert('channels', {'space_id': lenaSpace, 'name': 'Bergtouren'})).first['id'] as String;

      c.clearMessages();
      c.step('Zurück zur Startseite', 'Zweimal oben links zurück.', 'Die Startseite mit den drei Alben.', kind: 'Abzweigung',
          explain: 'Von der Seite des Albums geht es übers Album zurück.');
      await c.back();
      await c.back();
      c.screen('Startseite');
      await c.check('Startseite', () => c.waitFor('Sommerurlaub 2026', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Eine Einladung bekommen', 'Lena lädt Anna in ihr Album Wanderungen ein. Anna tippt oben auf Neuigkeiten.',
          'Unter Einladungen: Wanderungen, Lena Huber lädt dich als Member ein, mit Häkchen und Kreuz.',
          explain: 'Einladungen an einen selbst warten in den Neuigkeiten.');
      final invited = await lena.edge('invite-channel-member', {'channel_id': hiking, 'user_id': annaId});
      await c.check('Eingeladen', () => invited['status'] == 'invited');
      await c.tap('Neuigkeiten', seconds: 10);
      c.screen('Neuigkeiten');
      await c.check('Einladung', () => c.waitFor('Lena Huber lädt dich als Member ein', seconds: 20));
      await c.check('Ganz zu lesen, nicht abgeschnitten', () => c.fullyShown('Lena Huber lädt dich als Member ein'));
      await c.snap();

      c.clearMessages();
      c.step('Einladung annehmen', 'Auf das Häkchen (Annehmen) tippen.',
          'Unten kurz: Wanderungen ist jetzt in deinen Alben. Die Einladung ist weg.',
          explain: 'Anna ist jetzt im Album Wanderungen und kann dort Fotos senden.');
      await c.tap('Annehmen');
      await c.check('Meldung', () => c.waitFor('Wanderungen ist jetzt in deinen Alben', seconds: 8));
      await c.check('Anna im Album', () => eventually(() => isMember(hiking, annaId)));
      await c.snap();

      c.clearMessages();
      c.step('Neues Album auf der Startseite', 'Oben links zurück.', 'Auf der Startseite steht jetzt auch Wanderungen.',
          explain: 'Alben aus anderen Spaces stehen in derselben Liste.');
      await c.back();
      c.screen('Startseite');
      await c.check('Wanderungen', () => c.waitFor('Wanderungen', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Code scannen', 'Oben rechts auf die drei Punkte, dann Code scannen.',
          'Die Seite Code scannen: hier wäre das Kamerabild mit einem Rahmen, unten Code eintippen.',
          explain: 'Mit der Kamera scannt man den QR-Code, den jemand zeigt. In der Test-App bleibt die Kamera aus.');
      await c.tap('Weitere Optionen');
      c.screen('Menü');
      await c.tap('Code scannen');
      c.screen('Code scannen');
      await c.check('Code eintippen', () => c.waitFor('Code eintippen', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Code eintippen: falscher Code', 'Code eintippen, ABC-234 eingeben, OK.', 'Dieser Code ist ungültig. Darunter OK.',
          kind: 'Abzweigung', explain: 'Ein vertippter oder abgelaufener Code führt nirgendwohin.');
      await openCodeDialog();
      await c.typeInto('z. B.', 'ABC-234');
      await c.tap('OK');
      await c.check('Ungültig', () => c.waitFor('Dieser Code ist ungültig', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Code eintippen: daneben tippen', 'OK, Code eintippen, dann oben neben die Frage tippen.',
          'Die Frage schließt sich, wieder die Seite Code scannen.', kind: 'Abzweigung', explain: 'Nichts passiert.');
      await c.tap('OK');
      c.screen('Code scannen');
      await openCodeDialog();
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Code scannen');
      await c.hideKeyboard();
      await c.check('Frage zu', () => c.gone('z. B.', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Code scannen verlassen', 'Oben links zurück.', 'Wieder die Startseite.', kind: 'Abzweigung',
          explain: 'Die Seite schließt sich.');
      await c.back();
      c.screen('Startseite');
      await c.check('Startseite', () => c.waitFor('Wanderungen', seconds: 5));
      await c.snap();

      final lenaCode = (await lena.edge('create-invite-code', {'kind': 'album_member', 'target_id': mountains}))['code'] as String;
      c.clearMessages();
      c.step('Code eintippen', 'Drei Punkte, Code scannen, Code eintippen und Lenas Code für Bergtouren eingeben, OK.',
          'Anfrage gesendet: Die Admins von Bergtouren entscheiden. Du bekommst Bescheid.',
          explain: 'Ein abgetippter Code kommt meist per Nachricht. Darum entscheidet Lena noch.');
      await c.tap('Weitere Optionen');
      c.screen('Menü');
      await c.tap('Code scannen');
      c.screen('Code scannen');
      await openCodeDialog();
      await c.typeInto('z. B.', pretty(lenaCode));
      await c.tap('OK');
      await c.check('Anfrage gesendet', () => c.waitFor('Anfrage gesendet', seconds: 10));
      await c.check('Anfrage im Server', () async => (await requestOf(mountains, annaId))?['status'] == 'pending');
      await c.snap();

      c.clearMessages();
      c.step('Lena nimmt an', 'OK. Lena nimmt Annas Anfrage auf ihrem Handy an.',
          'Wieder die Startseite. Ohne Zutun erscheint dort Bergtouren.',
          explain: 'Sobald Lena Ja sagt, ist das Album bei Anna da.');
      await c.tap('OK');
      c.screen('Startseite');
      final annaAsk = (await requestOf(mountains, annaId))!['id'];
      await lena.patch('channel_membership_requests', 'id=eq.$annaAsk', {'status': 'accepted'});
      await c.check('Anna im Album', () => eventually(() => isMember(mountains, annaId)));
      await c.check('Bergtouren', () => c.waitFor('Bergtouren', seconds: 20));
      await c.snap();

      // ================================================================ Smile-Karte
      c.clearMessages();
      c.step('Lenas Karte öffnen', 'Lena schickt ihren Link smileapp.app/@lena.huber. Anna tippt ihn an.',
          'Smile öffnet Lenas Karte: Bild, Lena Huber, @lena.huber und In ein Album einladen.',
          explain: 'Jeder kann seine Karte als Link oder QR-Code weitergeben (Kapitel 1, Meine Karte).');
      InviteLinks.pending.value = InviteLinks.parse('https://smileapp.app/@lena.huber');
      c.screen('Karte');
      await c.check('Lenas Karte', () => c.waitFor('@lena.huber', seconds: 10));
      await c.check('Einladen angeboten', () => c.waitFor('In ein Album einladen', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Über die Karte einladen', 'In ein Album einladen, dann Weihnachten.',
          'Zuerst die Frage In welches Album? mit Annas Alben, nach dem Tippen kurz: Einladung an Lena Huber gesendet.',
          explain: 'Zur Auswahl stehen nur Alben, die Anna verwaltet.');
      await c.tap('In ein Album einladen');
      c.screen('Album wählen');
      await c.check('Frage', () => c.waitFor('In welches Album?', seconds: 8));
      await c.check('Nicht Lenas Alben', () async => await c.waitFor('Weihnachten', seconds: 5) && await c.gone('Bergtouren', seconds: 1));
      await tapExact('Weihnachten');
      c.screen('Karte');
      await c.check('Meldung', () => c.waitFor('Einladung an Lena Huber gesendet', seconds: 8));
      await c.check('Einladung im Server', () async => (await requestOf(seed.albums['Weihnachten']!, lena.id))?['status'] == 'pending');
      await c.snap();

      // ================================================================ Verlassen
      c.clearMessages();
      c.step('Paul verlässt das Album', 'Zurück zur Startseite. Paul verlässt Geburtstage auf seinem Handy. Anna öffnet die Seite des Albums.',
          'Bei den Personen nur noch Anna und Lena, dazu Tom wartend.',
          explain: 'Jeder kann ein Album selbst verlassen. Anna sieht es von selbst.');
      await c.back();
      c.screen('Startseite');
      await paul.delete('channel_members', 'channel_id=eq.$birthdays&user_id=eq.${paul.id}');
      await c.check('Paul draußen', () async => !await isMember(birthdays, paul.id));
      await openInfo('Geburtstage');
      await c.check('2 Personen', () => c.waitFor('2 Personen', seconds: 10));
      await c.check('Paul nicht mehr da', () => c.gone('Paul Berger', seconds: 3));
      await c.snap();

      c.clearMessages();
      c.step('Album verlassen: Abbrechen', 'Zurück zur Startseite, Bergtouren öffnen, die Seite des Albums, ganz unten Album verlassen, dann Abbrechen.',
          'Smile fragt: Album verlassen? Du siehst die Fotos dieses Albums danach nicht mehr. Nach Abbrechen bleibt alles.',
          kind: 'Abzweigung', explain: 'Smile fragt vorher nach.');
      await c.back();
      await c.back();
      c.screen('Startseite');
      await openInfo('Bergtouren');
      await c.check('Kein Einladen bei Lenas Album', () => c.gone('Person einladen', seconds: 2));
      await tester.scrollUntilVisible(c.find_('Album verlassen'), 300, scrollable: find.byType(Scrollable).first);
      await c.tap('Album verlassen');
      c.screen('Verlassen-Frage');
      await c.check('Frage', () => c.waitFor('Du siehst die Fotos dieses Albums danach nicht mehr', seconds: 5));
      await c.tap('Abbrechen');
      c.screen('Album-Infos');
      await c.check('Noch drin', () async => await isMember(mountains, annaId));
      await c.snap();

      c.clearMessages();
      c.step('Album verlassen', 'Album verlassen, dann Verlassen.', 'Smile springt zur Startseite. Bergtouren ist nicht mehr da.',
          explain: 'Anna ist draußen. Wieder hinein kommt sie nur mit einer neuen Einladung.');
      await c.tap('Album verlassen');
      c.screen('Verlassen-Frage');
      await c.waitFor('Du siehst die Fotos', seconds: 5);
      await c.tap('Verlassen', last: true);
      c.screen('Startseite');
      await c.check('Draußen im Server', () => eventually(() async => !await isMember(mountains, annaId)));
      await c.check('Startseite', () => c.waitFor('Wanderungen', seconds: 10));
      await c.check('Bergtouren weg', () => c.gone('Bergtouren', seconds: 8));
      await c.snap();

      // ================================================================ Tom ist neu
      final hikingCode = (await lena.edge('create-invite-code', {'kind': 'album_member', 'target_id': hiking}))['code'] as String;
      c.clearMessages();
      c.step('Tom meldet sich an', 'Anna meldet sich ab (Einstellungen, Abmelden). Tom meldet sich auf dem Handy mit seiner E-Mail-Adresse an.',
          'Toms Startseite: noch kein Album, dafür Ich wurde eingeladen und oben Neuigkeiten mit einem Punkt.',
          explain: 'So sieht Smile für jemanden aus, der gerade eingeladen wurde.');
      await signOut();
      await signIn(c, tomMail, screen: 'Startseite (leer)');
      await c.check('Ich wurde eingeladen', () => c.waitFor('Ich wurde eingeladen', seconds: 20));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Ich wurde eingeladen', 'Ich wurde eingeladen antippen, Code eintippen, Lenas Code für Wanderungen eingeben, OK.',
          'Anfrage gesendet: Die Admins von Wanderungen entscheiden.',
          explain: 'Ich wurde eingeladen führt auf dieselbe Seite wie Code scannen.');
      await c.tap('Ich wurde eingeladen');
      c.screen('Code scannen');
      await openCodeDialog();
      await c.typeInto('z. B.', pretty(hikingCode));
      await c.tap('OK');
      await c.check('Anfrage gesendet', () => c.waitFor('Anfrage gesendet', seconds: 10));
      await c.snap();

      c.clearMessages();
      c.step('Tom nimmt Annas Einladung an', 'OK, dann oben Neuigkeiten und bei Geburtstage auf das Häkchen.',
          'Geburtstage ist jetzt in deinen Alben.',
          explain: 'Annas Einladung aus den Kontakten wartet in Toms Neuigkeiten.');
      await c.tap('OK');
      c.screen('Startseite (leer)');
      await c.tap('Neuigkeiten', seconds: 10);
      c.screen('Neuigkeiten');
      await c.check('Annas Einladung', () => c.waitFor('Anna Berger lädt dich als Member ein', seconds: 20));
      await c.tap('Annehmen');
      await c.check('Meldung', () => c.waitFor('Geburtstage ist jetzt in deinen Alben', seconds: 8));
      await c.check('Tom im Album', () => eventually(() => isMember(birthdays, tom.id)));
      await c.snap();

      c.clearMessages();
      c.step('Toms Alben', 'Oben links zurück. Lena nimmt Toms Anfrage an.',
          'Toms Startseite zeigt Geburtstage und, ohne Zutun, auch Wanderungen.',
          explain: 'Annas Fotos sind sofort bei Tom zu sehen.');
      await c.back();
      c.screen('Startseite');
      final tomAsk = (await requestOf(hiking, tom.id))!['id'];
      await lena.patch('channel_membership_requests', 'id=eq.$tomAsk', {'status': 'accepted'});
      await c.check('Geburtstage', () => c.waitFor('Geburtstage', seconds: 10));
      await c.check('Wanderungen', () => c.waitFor('Wanderungen', seconds: 20));
      await c.snap();

      c.clearMessages();
      c.step('Anna wieder da', 'Tom meldet sich ab, Anna meldet sich wieder an.',
          'Annas Startseite mit Geburtstage, Sommerurlaub 2026, Weihnachten und Wanderungen.',
          explain: 'So endet Kapitel 5.');
      await signOut();
      await signIn(c, anna);
      await c.check('Annas Alben', () async =>
          await c.waitFor('Sommerurlaub 2026', seconds: 20) && await c.waitFor('Wanderungen', seconds: 5));
      await c.check('Geburtstage mit Anna, Lena und Tom', () async =>
          (await TestBackend.select('channel_members', 'select=user_id&channel_id=eq.$birthdays')).length == 3);
      await c.hideKeyboard();
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
