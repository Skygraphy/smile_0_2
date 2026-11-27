// Kapitel 16: Frame-Abo und Gutscheine (tools/testsuite, 2026-11-27).
// Startet dort, wo Kapitel 4 endet, dazu Annas zweiter Space Ferienhaus.
// Kaufen in Google Play gibt es in der Test-App nicht (sie spricht nur mit
// dem Testprojekt): hier geht es um Kostenlos, Probezeit, die Stufen und
// Gutscheine. Die Gutscheinkarten macht "Smile-Team" (eine Testperson mit
// Gutschein-Recht in admin_users) über dieselbe Funktion wie die Verwaltung
// auf smileapp.app.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/screens/plan_screen.dart';
import 'package:smile_app/screens/redeem_voucher_screen.dart';
import 'package:smile_app/screens/space_info_screen.dart';
import 'package:smile_app/screens/spaces_screen.dart';
import 'package:smile_app/services/frame_service.dart';
import 'package:smile_app/services/invite_links.dart';
import 'package:smile_app/services/space_service.dart';

import 'support/backend.dart';
import 'support/chapter.dart';
import 'support/seed.dart';

const teamMail = 'smile.team@example.com';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 16: Frame-Abo und Gutscheine', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding,
        id: 'ch16',
        title: 'Frame-Abo und Gutscheine',
        intro: 'Alben und Fotos sind kostenlos. Frames bekommen neue Fotos mit einem Frame-Abo pro Space: mit dem ersten Frame '
            'beginnen 2 Monate Probezeit, danach ein Abo oder ein Gutschein. Anna sieht sich die Stufen an und löst Gutscheine ein: '
            'falsche, abgelaufene, gesperrte und schon verwendete Codes, eine Karte per Link und zu viele Versuche.');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    await freshAnna(tester, c);
    unawaited(app.main());
    try {
      // ---------------------------------------------------------------- Startzustand
      await signIn(c, anna);
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final seed = await endOfChapter4(tester);
      final berger = seed.spaceId;
      final ferienhaus = await SpaceService().createSpace('Ferienhaus');
      final annaId = await TestBackend.userId(anna);

      // Smile-Team macht Gutscheinkarten, wie in der Verwaltung.
      await TestBackend.person(teamMail, 'Smile-Team');
      await TestBackend.insert('admin_users', {'user_id': await TestBackend.userId(teamMail), 'role': 'admin', 'can_vouchers': true});
      final team = await TestUser.signIn(teamMail);
      Future<Map<String, dynamic>> batch(String name, int count, {String? cardName}) => team.edge('voucher-admin', {
            'action': 'create',
            'name': name,
            'kind': 'gift',
            'frames': 1,
            'months': 12,
            'count': count,
            'redeem_until': DateTime.now().add(const Duration(days: 60)).toUtc().toIso8601String(),
            'card_name': ?cardName,
          });
      final gifts = await batch('Weihnachtskarten', 2, cardName: 'die ganze Familie');
      final codes = (gifts['codes'] as List).cast<String>();
      if (codes.length != 2) throw TestFailure('Gutscheine nicht angelegt: $gifts');
      final old = await batch('Alte Aktion', 1);
      await TestBackend.patch('voucher_batches', 'id=eq.${(old['batch'] as Map)['id']}',
          {'redeem_until': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String()});
      final blocked = await batch('Gesperrte Karten', 1);
      await team.edge('voucher-admin', {'action': 'block', 'batch_id': (blocked['batch'] as Map)['id']});

      Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
        final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
        while (true) {
          if (await test()) return true;
          if (DateTime.now().isAfter(end)) return false;
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<List> plans(String space) =>
          TestBackend.select('space_plans', 'select=source,frames,starts_at,ends_at&space_id=eq.$space&order=starts_at.asc');

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

      Future<void> openSpace(String name) async {
        await home();
        await until(SpacesScreen, () => tapExact('Spaces'));
        c.screen('Spaces');
        await until(SpaceInfoScreen, () => c.tap(name, last: true));
        c.screen('Space');
        await c.waitFor('Admins', seconds: 10);
      }

      Future<void> typeCode(String code) async {
        await c.typeInto('SMILE-XXXX-XXXX', code, logAs: 'Eingabefeld: Code');
        await c.hideKeyboard();
        await tapExact('Einlösen');
      }

      await c.waitFor('Geburtstage', seconds: 20);
      await c.hideKeyboard();
      c.screen('Startseite');
      await c.start();

      // ================================================================ Kostenlos und Probezeit
      c.step('Ausgangslage', 'Unten Spaces, Familie Berger, nach unten zu Frame-Abo.',
          'Kostenlos: Alben und Fotos sind kostenlos. Mit dem ersten Frame beginnen 2 Monate Probezeit. Darunter der Speicher '
              '(von 5 GB) und Videos bis 2 Minuten, dann Gutschein einlösen.',
          explain: 'Ohne Frame kostet Smile nichts. Das Abo gilt immer für einen ganzen Space; Mitglieder zahlen nie etwas.');
      await openSpace('Familie Berger');
      await c.check('Kostenlos', () => c.dragTo('Kostenlos'));
      await c.check('Probezeit mit dem ersten Frame', () => c.waitFor('~Mit dem ersten Frame beginnen 2 Monate Probezeit', seconds: 3));
      await c.check('Videos bis 2 Minuten', () => c.waitFor('~Videos bis 2 Minuten', seconds: 3));
      await c.check('Gutschein einlösen', () => c.dragTo('Gutschein einlösen'));
      await c.check('Server: noch kein Abo', () async => (await plans(berger)).isEmpty);
      await c.snap();

      c.step('Probezeit', 'Anna verbindet den Frame Wohnzimmer (wie in Kapitel 6). Zurück und Familie Berger noch einmal öffnen.',
          'Bei Frame-Abo: Probezeit · noch 60 Tage (oder 59, je nach Monat), Alle Frames bekommen neue Fotos bis …',
          explain: 'Die Probezeit beginnt einmal pro Space, mit dem ersten verbundenen Frame.');
      final frames = FrameService();
      final wohnzimmer = await frames.createFrame(spaceId: berger, name: 'Wohnzimmer');
      await frames.assignChannel(frameId: wohnzimmer.id, channelId: seed.albums['Geburtstage']!);
      await frames.setRevoked(frameId: wohnzimmer.id, revoked: false);
      await TestBackend.patch('frames', 'id=eq.${wohnzimmer.id}', {'paired_at': DateTime.now().toUtc().toIso8601String()});
      await c.check('Server: Probezeit', () => eventually(() async => (await plans(berger)).any((p) => p['source'] == 'trial')));
      await openSpace('Familie Berger');
      await c.check('Probezeit', () => c.dragTo('~Probezeit · noch'));
      await c.check('Bis wann', () => c.waitFor('~Alle Frames bekommen neue Fotos bis', seconds: 3));
      await c.snap();

      // ================================================================ Die Stufen
      c.step('Frame-Abo', 'Auf Probezeit tippen.',
          'Frame-Abo: Für den ganzen Space „Familie Berger“. Mitglieder zahlen nie etwas. Dazu Monatlich und Jährlich, die Stufen '
              '1 Frame 4,99 €, 3 Frames 8,99 €, 5 Frames 12,99 € und Gutschein einlösen.',
          explain: 'Jede Stufe sagt, wie viel Speicher und wie lange Videos sie bringt. Die Test-App kauft nicht in Google Play, '
              'daher der Hinweis Kaufen geht bald direkt hier.');
      await until(PlanScreen, () => c.tap('~Probezeit · noch', last: true));
      c.screen('Frame-Abo');
      await c.check('Für den ganzen Space', () => c.waitFor('~Für den ganzen Space „Familie Berger“', seconds: 5));
      await c.check('Drei Stufen monatlich', () async =>
          await c.waitFor('4,99', seconds: 3) && await c.waitFor('8,99', seconds: 1) && await c.waitFor('12,99', seconds: 1));
      await c.check('Speicher und Videos', () => c.waitFor('25 GB · Videos 5 Min.', seconds: 1));
      await c.check('Kein Kauf in der Test-App', () => c.dragTo('~Kaufen geht bald direkt hier'));
      await c.snap();

      c.step('Jährlich', 'Oben Jährlich · 2 Monate gratis antippen.',
          'Die Preise pro Jahr: 49,99 €, 89,99 €, 129,99 €.', kind: 'Abzweigung',
          explain: 'Wer jährlich zahlt, bekommt 2 Monate geschenkt.');
      await c.dragTo('Monatlich', up: false);
      await tapExact('Jährlich · 2 Monate gratis');
      await c.check('Pro Jahr', () async =>
          await c.waitFor('49,99', seconds: 3) && await c.waitFor('89,99', seconds: 1) && await c.waitFor('129,99', seconds: 1));
      await c.check('pro Jahr', () => c.waitFor('pro Jahr', seconds: 1));
      await c.snap();

      // ================================================================ Gutscheine
      c.step('Gutschein einlösen', 'Ganz unten Gutschein einlösen.',
          'Gutschein einlösen: oben Für den Space Familie Berger, darunter das Feld SMILE-XXXX-XXXX, Einlösen und QR-Code scannen.',
          explain: 'Gutscheine gibt es als Karte zum Verschenken. Ein Gutschein gilt für einen Space.');
      await c.dragTo('Gutschein einlösen');
      await until(RedeemVoucherScreen, () => tapExact('Gutschein einlösen'));
      c.screen('Gutschein einlösen');
      await c.check('Für Familie Berger', () => c.waitFor('Familie Berger', seconds: 5));
      await c.check('Feld und Knöpfe', () async => await c.waitFor('Einlösen', seconds: 3) && await c.waitFor('QR-Code scannen', seconds: 1));
      await c.snap();

      c.step('Falscher Code', 'SMILE-AAAA-BBBB eingeben, Einlösen.', 'Rot: Diesen Code gibt es nicht. Prüf ihn bitte noch einmal.',
          kind: 'Abzweigung', explain: 'Ein Tippfehler kostet nichts; Smile zählt die falschen Versuche aber mit.');
      await typeCode('SMILE-AAAA-BBBB');
      await c.check('Meldung', () => c.waitFor('Diesen Code gibt es nicht.', seconds: 10));
      await c.check('Server: ein falscher Versuch', () async =>
          (await TestBackend.select('voucher_attempts', 'select=ok&user_id=eq.$annaId')).where((r) => r['ok'] == false).length == 1);
      await c.snap();

      c.step('Abgelaufener Code', 'Den Code einer alten Aktion eingeben, Einlösen.', 'Rot: Dieser Code ist abgelaufen.',
          kind: 'Abzweigung', explain: 'Jede Karte hat ein Datum, bis wann sie eingelöst werden kann.');
      await typeCode((old['codes'] as List).single as String);
      await c.check('Meldung', () => c.waitFor('Dieser Code ist abgelaufen.', seconds: 10));
      await c.snap();

      c.step('Gesperrter Code', 'Den Code einer gesperrten Karte eingeben, Einlösen.', 'Rot: Dieser Code gilt nicht mehr.',
          kind: 'Abzweigung', explain: 'Verlorene oder gestohlene Karten sperrt das Smile-Team in der Verwaltung.');
      await typeCode((blocked['codes'] as List).single as String);
      await c.check('Meldung', () => c.waitFor('Dieser Code gilt nicht mehr.', seconds: 10));
      await c.snap();

      final first = codes[0];
      final plain = first.replaceAll('-', '').substring(5).toLowerCase();
      c.step('Gutschein einlösen: richtig', 'Den Code der Karte klein und ohne Striche eingeben ($plain), Einlösen.',
          'Gutschein eingelöst: Familie Berger hat 1 Frame vom … bis … – direkt nach dem, was schon läuft. Darunter Ein Geschenk für '
              'die ganze Familie und Fertig.',
          explain: 'Groß- und Kleinschreibung und Striche sind egal. Der Gutschein schließt an die Probezeit an: nichts geht verloren.');
      await typeCode(plain);
      await c.check('Eingelöst', () => c.waitFor('Gutschein eingelöst', seconds: 10));
      await c.check('Nach der Probezeit', () => c.waitFor('~Familie Berger hat 1 Frame vom', seconds: 2));
      await c.check('Geschenk', () => c.waitFor('Ein Geschenk für die ganze Familie', seconds: 2));
      await c.check('Server: Gutschein nach der Probezeit', () => eventually(() async {
            final p = await plans(berger);
            final trial = p.firstWhere((x) => x['source'] == 'trial');
            final voucher = p.where((x) => x['source'] == 'voucher');
            return voucher.length == 1 && voucher.single['starts_at'] == trial['ends_at'] && voucher.single['frames'] == 1;
          }));
      await c.snap();

      c.step('Fertig', 'Fertig antippen.', 'Zurück auf der Seite von Familie Berger; die Probezeit läuft weiter.',
          explain: 'Die Abo-Seite schließt sich mit, denn es hat sich etwas geändert.');
      await tapExact('Fertig');
      c.screen('Space');
      await c.check('Space-Seite', () => eventually(() =>
          find.byType(PlanScreen).evaluate().isEmpty && find.byType(RedeemVoucherScreen).evaluate().isEmpty && find.byType(SpaceInfoScreen).evaluate().isNotEmpty));
      await c.check('Probezeit', () => c.dragTo('~Probezeit · noch'));
      await c.snap();

      c.step('Schon verwendet', 'Bei Frame-Abo Gutschein einlösen, noch einmal denselben Code, Einlösen.',
          'Rot: Dieser Code wurde schon verwendet.', kind: 'Abzweigung', explain: 'Jede Karte gilt genau einmal.');
      await c.dragTo('Gutschein einlösen');
      await until(RedeemVoucherScreen, () => tapExact('Gutschein einlösen'));
      c.screen('Gutschein einlösen');
      await typeCode(first);
      await c.check('Meldung', () => c.waitFor('Dieser Code wurde schon verwendet.', seconds: 10));
      await c.snap();

      // ================================================================ Karte per Link
      c.step('Karte per Link', 'Zurück zur Startseite. Den Link auf der zweiten Karte öffnen (smileapp.app/g/…).',
          'Gutschein einlösen mit dem Code schon im Feld. Oben Für den Space … und ändern, denn Anna hat zwei Spaces.',
          explain: 'Auf jeder Karte ist ein QR-Code mit Link; Smile öffnet ihn direkt. Der Space ist noch nicht gewählt.');
      await home();
      InviteLinks.pending.value = InviteLinks.parse('https://smileapp.app/g/${codes[1]}');
      await until(RedeemVoucherScreen, () async {});
      c.screen('Gutschein einlösen');
      await c.check('Code im Feld', () => c.waitFor(codes[1], seconds: 5));
      await c.check('ändern', () => c.waitFor('ändern', seconds: 5));
      await c.snap();

      c.step('Für welchen Space?', 'Einlösen antippen.', 'Unten die Frage Für welchen Space? mit Familie Berger und Ferienhaus.',
          explain: 'Ohne gewählten Space fragt Smile zuerst nach.');
      await tapExact('Einlösen');
      c.screen('Für welchen Space?');
      await c.check('Frage', () => c.waitFor('Für welchen Space?', seconds: 5));
      await c.check('Ferienhaus', () => c.waitFor('Ferienhaus', seconds: 2));
      await c.snap();

      c.step('Für Ferienhaus einlösen', 'Ferienhaus antippen.',
          'Gutschein eingelöst: Ferienhaus hat jetzt 1 Frame bis … (in einem Jahr).',
          explain: 'Ferienhaus hat noch keine Probezeit; der Gutschein gilt ab sofort.');
      await tapExact('Ferienhaus');
      c.screen('Gutschein einlösen');
      await c.check('Eingelöst', () => c.waitFor('~Ferienhaus hat jetzt 1 Frame bis', seconds: 10));
      await c.check('Server: Gutschein für Ferienhaus', () async {
        final p = await plans(ferienhaus);
        return p.length == 1 && p.single['source'] == 'voucher';
      });
      await c.snap();

      c.step('Abo im Ferienhaus', 'Fertig, dann unten Spaces, Ferienhaus, nach unten zu Frame-Abo.',
          'Frame-Abo: 1 Frame · aktiv, Gutschein · bis …; darunter 0 von 1 Frames und Videos bis 5 Minuten.',
          explain: 'Mit dem Gutschein bekommt der Space mehr Speicher (25 GB) und längere Videos.');
      await tapExact('Fertig');
      await openSpace('Ferienhaus');
      await c.check('Aktiv', () => c.dragTo('1 Frame · aktiv'));
      await c.check('Gutschein', () => c.waitFor('~Gutschein · bis', seconds: 3));
      await c.check('Videos bis 5 Minuten', () => c.waitFor('~Videos bis 5 Minuten', seconds: 3));
      await c.snap();

      // ================================================================ Zu viele Versuche
      c.step('Zu viele Versuche', 'Gutschein einlösen, noch viermal einen falschen Code eingeben, dann noch einen.',
          'Nach 5 falschen Versuchen: Zu viele Versuche. Bitte versuch es in einer Stunde wieder.', kind: 'Abzweigung',
          explain: 'Damit niemand Codes durchprobieren kann, sperrt Smile nach 5 falschen Versuchen für eine Stunde.');
      await c.dragTo('Gutschein einlösen');
      await until(RedeemVoucherScreen, () => tapExact('Gutschein einlösen'));
      c.screen('Gutschein einlösen');
      for (var i = 0; i < 4; i++) {
        await typeCode('SMILE-ZZZZ-000$i');
        await c.waitFor('Diesen Code gibt es nicht.', seconds: 10);
      }
      await typeCode('SMILE-ZZZZ-0009');
      await c.check('Meldung', () => c.waitFor('Zu viele Versuche.', seconds: 10));
      await c.check('Server: fünf falsche Versuche', () async =>
          (await TestBackend.select('voucher_attempts', 'select=ok&user_id=eq.$annaId')).where((r) => r['ok'] == false).length == 5);
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
