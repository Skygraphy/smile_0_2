// Kapitel 3: Fotos und Videos senden (tools/testsuite, 2026-10-21).
// Startet dort, wo Kapitel 2 endet: Anna ist angemeldet, ihr Space Familie
// Berger hat die Alben Weihnachten, Geburtstage und Sommerurlaub 2026.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/services/channel_service.dart';
import 'package:smile_app/services/object_picture_service.dart';
import 'package:smile_app/services/offline.dart';
import 'package:smile_app/services/space_service.dart';
import 'package:smile_app/services/upload_queue.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'support/backend.dart';
import 'support/chapter.dart';

const anna = 'anna.berger@example.com';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 3: Fotos und Videos senden', (tester) async {
    // ---------------------------------------------------------------- Startzustand (Ende Kapitel 2)
    await TestBackend.reset();
    await TestBackend.person('paul.berger@example.com', 'Paul Berger', handle: 'paul.berger');
    await TestBackend.person(anna, 'Anna Berger', handle: 'anna.berger');
    final support = (await getApplicationSupportDirectory()).path;
    await TestBackend.setAvatar(anna, await File('$support/fixtures/profiles/frau_mittel.png').readAsBytes(), 'image/png');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('tips_enabled', false); // Tipps haben ein eigenes Kapitel.
    final semantics = tester.ensureSemantics();
    var birthdays = '';

    Future<List<Map>> media([String? album]) async {
      final rows = await TestBackend.select('media_items', 'select=media_type,caption,processing_status,channel_id');
      if (album == null) return rows.cast<Map>();
      final ids = await TestBackend.select('channels', 'select=id&name=eq.${Uri.encodeComponent(album)}');
      final id = ids.isEmpty ? '' : (ids.first as Map)['id'];
      return rows.cast<Map>().where((r) => r['channel_id'] == id).toList();
    }

    Future<bool> mediaCount(int n, {String? album, double seconds = 30}) async {
      final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
      while (true) {
        if ((await media(album)).length == n) return true;
        if (DateTime.now().isAfter(end)) return false;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }

    final c = Chapter(tester, binding,
        id: 'ch03',
        title: 'Fotos und Videos senden',
        intro: 'Anna füllt ihre Alben: mehrere Fotos und ein Video auf einmal mit Titel, Fotos und Videos direkt mit der Kamera '
            '(mit Nochmal), ohne Verbindung (das Foto wartet mit einer Uhr und geht später von selbst raus, oder sie sagt Nicht senden) '
            'und mit der Kamera auf der Startseite, wo sie erst danach das Album wählt.');

    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    unawaited(app.main());
    try {
      // Anmelden und den Stand von Kapitel 2 herstellen (nicht Teil des Kapitels).
      c.screen('Anmeldung');
      if (!await c.waitFor('Code anfordern', seconds: 20)) throw TestFailure('Anmeldung erscheint nicht');
      await c.typeInto('E-Mail-Adresse', anna);
      await c.tap('Code anfordern');
      await c.waitFor('Wir haben einen Code', seconds: 10);
      await c.typeInto('', await TestBackend.otp(anna), logAs: 'Code-Kästchen');
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final spaceId = await SpaceService().createSpace('Familie Berger');
      final pictures = ObjectPictureService();
      final house = (bytes: await File('$support/fixtures/media/04_haus_mit_garten.jpg').readAsBytes(), mimeType: 'image/jpeg');
      await pictures.save(ObjectKind.space, spaceId, await pictures.uploadPicked(ObjectKind.space, spaceId, house));
      final summer = await ChannelService().createChannel(spaceId: spaceId, name: 'Sommerurlaub 2026');
      final beach = (bytes: await File('$support/fixtures/media/26_strand_am_abend.jpg').readAsBytes(), mimeType: 'image/jpeg');
      await pictures.save(ObjectKind.album, summer, await pictures.uploadPicked(ObjectKind.album, summer, beach));
      birthdays = await ChannelService().createChannel(spaceId: spaceId, name: 'Geburtstage');
      await ChannelService().createChannel(spaceId: spaceId, name: 'Weihnachten');
      // The start page picks them up on its next load: pull to refresh.
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1500);
      await c.waitFor('Weihnachten', seconds: 15);
      await c.hideKeyboard();
      await c.start();

      Future<void> pickTest(List<String> labels, {bool confirm = true}) async {
        c.screen('Testbilder');
        if (!await c.waitFor('Testbilder', seconds: 15)) throw TestFailure('Testbilder erscheinen nicht');
        await c.settle();
        for (final l in labels) {
          final f = find.bySemanticsLabel(l);
          await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
          await tester.tap(f.first, warnIfMissed: false);
          c.logTap(l);
          await c.settle();
        }
        if (confirm) await c.tap('Auswählen');
      }

      // ---------------------------------------------------------------- Mehrere auf einmal
      c.step('Ausgangslage', 'Smile ist geöffnet, Anna ist angemeldet.',
          'Die Startseite mit den drei Alben Weihnachten, Geburtstage und Sommerurlaub 2026, alle mit Noch keine Fotos.',
          explain: 'So endet Kapitel 2: der Space Familie Berger mit drei leeren Alben.');
      c.screen('Startseite');
      await c.check('Drei Alben, noch keine Fotos', () async => (await media()).isEmpty);
      // The cover of Sommerurlaub 2026, not the initials shown while it loads (0.0.17 review).
      await c.check('Titelbild geladen', () => c.gone('SO', seconds: 15));
      await c.snap();

      c.step('Album Geburtstage öffnen', 'Geburtstage antippen.', 'Das leere Album mit Kamera und + rechts unten.',
          explain: 'Gesendet wird immer in ein Album.');
      await c.tap('Geburtstage');
      c.screen('Album');
      await c.check('Leeres Album', () => c.waitFor('Noch keine Fotos', seconds: 10));
      await c.snap();

      c.step('Fotos auswählen', 'Auf + tippen.',
          'Die Auswahl der Fotos und Videos. (In der Test-App: 50 gezeichnete Testbilder und -videos statt der Galerie.)',
          explain: 'Normalerweise öffnet sich die Galerie des Handys; man kann mehrere Fotos und Videos auf einmal wählen.');
      await c.tap('Foto oder Video teilen');
      c.screen('Testbilder');
      await c.check('Auswahl offen', () => c.waitFor('Geburtstagstorte', seconds: 15));
      await c.snap();

      c.step('Auswahl abbrechen', 'Zurück, ohne etwas zu wählen.', 'Wieder das leere Album, nichts wurde gesendet.',
          kind: 'Abzweigung', explain: 'Ohne Auswahl passiert nichts.');
      await c.back();
      c.screen('Album');
      await c.check('Noch leer', () => c.waitFor('Noch keine Fotos', seconds: 5));
      await c.snap();

      c.step('Drei auswählen', 'Auf + tippen, Geburtstagstorte, Luftballons (ein Video) und Torte mit Kerzen antippen, dann Auswählen (3).',
          'Die Vorschau: oben groß das erste Bild, darunter alle drei klein, ein Feld Titel hinzufügen und der Knopf zum Senden.',
          explain: 'Vor dem Senden zeigt Smile, was gesendet wird. Jedes Foto und Video kann einen eigenen Titel bekommen.');
      await c.tap('Foto oder Video teilen');
      await pickTest(['Geburtstagstorte', 'Luftballons', 'Torte mit Kerzen']);
      c.screen('Vorschau');
      await c.check('Vorschau mit Titelfeld', () => c.waitFor('Titel hinzufügen', seconds: 10));
      await c.snap();

      c.step('Vorschau schließen', 'Oben links auf das Kreuz tippen.', 'Wieder das leere Album, nichts wurde gesendet.',
          kind: 'Abzweigung', explain: 'Das Kreuz bricht ab, bevor etwas hochgeladen wird.');
      await tester.tap(find.byIcon(SmileIcons.close).first, warnIfMissed: false);
      c.logTap('Schließen');
      await c.settle();
      c.screen('Album');
      await c.check('Noch leer', () => c.waitFor('Noch keine Fotos', seconds: 5));
      await c.check('Nichts auf dem Server', () async => (await media()).isEmpty);
      await c.snap();

      c.step('Titel eingeben', 'Noch einmal dieselben drei auswählen, in der Vorschau beim ersten Bild Omas 80. Geburtstag als Titel eingeben.',
          'Der Titel steht im Feld unter dem großen Bild.',
          explain: 'Der Titel ist freiwillig. Er erscheint im Album unter dem Foto und auf dem Frame.');
      await c.tap('Foto oder Video teilen');
      await pickTest(['Geburtstagstorte', 'Luftballons', 'Torte mit Kerzen']);
      c.screen('Vorschau');
      await c.waitFor('Titel hinzufügen', seconds: 10);
      await c.typeInto('Titel hinzufügen', 'Omas 80. Geburtstag');
      await c.hideKeyboard();
      await c.snap();

      c.step('Drei senden', 'Auf Senden tippen (hier absichtlich zweimal schnell).',
          'Die drei stehen sofort im Album, erst mit einem Ring, dann fertig. Unter der Torte steht Omas 80. Geburtstag.',
          explain: 'Wie bei WhatsApp: die Fotos stehen sofort im Album und gehen im Hintergrund hinaus. Fotos werden vorher verkleinert, '
              'das Video auf dem Handy umgewandelt. Der doppelte Tipp darf nichts doppelt senden.');
      await c.tap('Senden', twice: true);
      c.screen('Album');
      await c.check('Genau drei auf dem Server', () => mediaCount(3, seconds: 90));
      await c.check('Ein Video und zwei Fotos', () async {
        final m = await media();
        return m.where((r) => r['media_type'] == 'video').length == 1 && m.where((r) => r['media_type'] == 'photo').length == 2;
      });
      await c.check('Genau ein Titel: Omas 80. Geburtstag', () async {
        final caps = (await media()).map((r) => r['caption']).where((x) => x != null).toList();
        return caps.length == 1 && caps.first == 'Omas 80. Geburtstag';
      });
      await c.check('Titel im Album', () async {
        for (var i = 0; i < 40; i++) {
          if (find.text('Omas 80. Geburtstag', skipOffstage: false).evaluate().isNotEmpty) return true;
          await tester.pump(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Alles fertig gesendet', () async {
        for (var i = 0; i < 120; i++) {
          if (UploadQueue.instance.itemsFor(birthdays).every((q) => q.done)) return true;
          await tester.pump(const Duration(milliseconds: 500));
        }
        return false;
      });
      await c.settle(max: const Duration(seconds: 3));
      await c.snap();

      // ---------------------------------------------------------------- Kamera im Album
      c.step('Kamera im Album', 'Auf die Kamera über dem + tippen.', 'Unten die Wahl: Foto aufnehmen oder Video aufnehmen.',
          explain: 'Die Kamera im Album nimmt direkt für dieses Album auf.');
      await c.tap('Aufnehmen');
      c.screen('Kamera-Wahl');
      await c.check('Foto oder Video', () async =>
          await c.waitFor('Foto aufnehmen', seconds: 3) && await c.waitFor('Video aufnehmen', seconds: 1));
      await c.snap();

      c.step('Kamera-Wahl: daneben tippen', 'Oben neben die Wahl tippen.', 'Die Wahl schließt sich, nichts passiert.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt die Wahl.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Album');
      await c.check('Wahl zu', () => c.gone('Video aufnehmen', seconds: 3));
      await c.snap();

      c.step('Foto aufnehmen', 'Noch einmal auf die Kamera, dann Foto aufnehmen und ein Foto machen. (In der Test-App: Kaffee aus den Testbildern.)',
          'Die Vorschau des Fotos mit Titel hinzufügen, Nochmal und Senden.',
          explain: 'Erst die Vorschau: so geht kein verwackeltes Foto aus Versehen hinaus.');
      await c.tap('Aufnehmen');
      c.screen('Kamera-Wahl');
      await c.tap('Foto aufnehmen');
      await pickTest(['Kaffee'], confirm: false);
      c.screen('Aufnahme-Vorschau');
      await c.check('Vorschau mit Nochmal', () => c.waitFor('Nochmal', seconds: 10));
      await c.snap();

      c.step('Nochmal', 'Nochmal antippen und ein neues Foto machen (hier: Obstschale).', 'Die Vorschau zeigt jetzt die Obstschale.',
          kind: 'Abzweigung', explain: 'Nochmal verwirft das erste Foto, ohne es zu senden.');
      await c.tap('Nochmal');
      await pickTest(['Obstschale'], confirm: false);
      c.screen('Aufnahme-Vorschau');
      await c.check('Wieder die Vorschau', () => c.waitFor('Nochmal', seconds: 10));
      await c.check('Nichts dazugekommen', () async => (await media()).length == 3);
      await c.snap();

      c.step('Aufgenommenes Foto senden', 'Als Titel Obst für alle eingeben, dann Senden antippen.',
          'Die Obstschale steht im Album, darunter Obst für alle. Der Kaffee nicht.',
          explain: 'Gesendet wird nur, was in der Vorschau zu sehen war, mit seinem Titel.');
      await c.typeInto('Titel hinzufügen', 'Obst für alle');
      await c.tap('Senden');
      c.screen('Album');
      await c.check('Vier auf dem Server', () => mediaCount(4));
      await c.check('Titel Obst für alle', () async => (await media()).any((r) => r['caption'] == 'Obst für alle'));
      await c.hideKeyboard();
      await c.snap();

      c.step('Video aufnehmen', 'Kamera, Video aufnehmen, ein Video drehen (hier: Hund läuft), dann Senden.',
          'Das Video steht im Album, mit einem Ring, bis es fertig ist.',
          explain: 'Videos werden auf dem Handy auf die gewählte Qualität (Einstellungen, Videos senden: Mittel) gebracht und dann gesendet.');
      await c.tap('Aufnehmen');
      c.screen('Kamera-Wahl');
      await c.tap('Video aufnehmen');
      await pickTest(['Hund läuft'], confirm: false);
      c.screen('Aufnahme-Vorschau');
      await c.waitFor('Senden', seconds: 10);
      await c.tap('Senden');
      c.screen('Album');
      await c.check('Fünf auf dem Server', () => mediaCount(5, seconds: 90));
      await c.check('Zwei Videos', () async => (await media()).where((r) => r['media_type'] == 'video').length == 2);
      await c.snap();

      // ---------------------------------------------------------------- Ohne Verbindung
      Offline.simulated.value = true;
      c.step('Ohne Verbindung senden', 'Ohne Internet: +, Schneemann wählen, Senden.',
          'Der Schneemann steht im Album, darunter eine kleine Uhr: er wartet auf eine Verbindung.',
          explain: 'Wie bei WhatsApp: ohne Verbindung wartet das Foto auf dem Handy und geht von selbst hinaus, sobald es wieder Internet gibt, '
              'auch wenn Smile dann geschlossen ist. (Die Test-App schaltet dafür ihr Internet ab, nicht das WLAN.)');
      await c.tap('Foto oder Video teilen');
      await pickTest(['Schneemann']);
      c.screen('Vorschau');
      await c.waitFor('Titel hinzufügen', seconds: 10);
      await c.tap('Senden');
      c.screen('Album');
      await c.check('Wartet auf Verbindung', () async {
        for (var i = 0; i < 40; i++) {
          if (UploadQueue.instance.itemsFor(birthdays).any((q) => q.waiting && !q.done)) return true;
          await tester.pump(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Nicht auf dem Server', () async => (await media()).length == 5);
      await c.settle(max: const Duration(seconds: 2));
      await c.snap();

      c.step('Nicht senden', 'Auf die drei Punkte am wartenden Schneemann tippen, dann Nicht senden.',
          'Der Schneemann verschwindet aus dem Album. Er wird nie gesendet.',
          kind: 'Abzweigung', explain: 'Solange etwas wartet, kann man es noch zurückhalten.');
      final dots = find.byWidgetPredicate((w) => w is PopupMenuButton<void>);
      await tester.tap(dots.first, warnIfMissed: false);
      c.logTap('Wartendes Foto: Menü');
      await c.settle();
      c.screen('Wartendes Foto');
      await c.tap('Nicht senden', last: true);
      c.screen('Album');
      await c.check('Nichts wartet mehr', () async {
        for (var i = 0; i < 20; i++) {
          if (!UploadQueue.instance.itemsFor(birthdays).any((q) => !q.done)) return true;
          await tester.pump(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.snap();

      c.step('Wieder ohne Verbindung senden', 'Noch ohne Internet: +, Herbstwald wählen, Senden.',
          'Der Herbstwald steht mit Uhr im Album und wartet.', explain: 'Diesmal lässt Anna ihn warten.');
      await c.tap('Foto oder Video teilen');
      await pickTest(['Herbstwald']);
      c.screen('Vorschau');
      await c.waitFor('Titel hinzufügen', seconds: 10);
      await c.tap('Senden');
      c.screen('Album');
      await c.check('Wartet auf Verbindung', () async {
        for (var i = 0; i < 40; i++) {
          if (UploadQueue.instance.itemsFor(birthdays).any((q) => q.waiting && !q.done)) return true;
          await tester.pump(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Schneemann nie gesendet, Herbstwald noch nicht', () async => (await media()).length == 5);
      await c.settle(max: const Duration(seconds: 2));
      await c.snap();

      c.step('Verbindung wieder da', 'Internet wieder an (in der Test-App: ihr Schalter).',
          'Ohne etwas zu tippen geht der Herbstwald hinaus; die Uhr verschwindet.',
          explain: 'Sobald es wieder eine Verbindung gibt, sendet Smile von selbst.');
      Offline.simulated.value = false;
      await c.check('Herbstwald gesendet', () => mediaCount(6));
      await c.check('Nichts wartet mehr', () async {
        for (var i = 0; i < 40; i++) {
          if (!UploadQueue.instance.itemsFor(birthdays).any((q) => !q.done)) return true;
          await tester.pump(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.settle(max: const Duration(seconds: 3));
      await c.snap();

      // ---------------------------------------------------------------- Kamera auf der Startseite
      c.step('Zurück zur Startseite', 'Zurück.', 'Die Startseite: Geburtstage steht oben mit Du: und dem zuletzt Gesendeten.',
          explain: 'Die Startseite zeigt bei jedem Album, wer zuletzt was gesendet hat; das neueste Album steht oben.');
      await c.back();
      c.screen('Startseite');
      await c.check('Geburtstage zeigt das Gesendete', () => c.waitFor('~Du:', seconds: 10));
      await c.snap();

      c.step('Kamera auf der Startseite', 'Oben auf die Kamera tippen, Foto aufnehmen, ein Foto machen (hier: Strand am Abend).',
          'Senden an …: das Foto oben, darunter ein Feld für den Titel und die Liste der Alben.',
          explain: 'Erst fotografieren, dann das Album wählen: für den schnellen Schnappschuss.');
      await c.tap('Aufnehmen');
      c.screen('Kamera-Wahl');
      await c.tap('Foto aufnehmen');
      await pickTest(['Strand am Abend'], confirm: false);
      c.screen('Senden an');
      await c.check('Albenliste', () async =>
          await c.waitFor('Senden an', seconds: 10) && await c.waitFor('Sommerurlaub 2026', seconds: 5));
      await c.snap();

      c.step('Senden an: Zurück', 'Zurück, ohne ein Album zu wählen.', 'Wieder die Startseite; das Foto wurde nicht gesendet.',
          kind: 'Abzweigung', explain: 'Ohne Album geht nichts hinaus.');
      await c.back();
      c.screen('Startseite');
      await c.check('Startseite', () => c.waitFor('Weihnachten', seconds: 5));
      await c.check('Nichts dazugekommen', () async => (await media()).length == 6);
      await c.snap();

      c.step('Kamera auf der Startseite mit Titel', 'Noch einmal: Kamera, Foto aufnehmen (Strand am Abend), als Titel Erster Abend am Meer eingeben.',
          'Senden an … mit dem Foto und dem Titel im Feld.',
          explain: 'Auch hier kann das Foto gleich einen Titel bekommen.');
      await c.tap('Aufnehmen');
      c.screen('Kamera-Wahl');
      await c.tap('Foto aufnehmen');
      await pickTest(['Strand am Abend'], confirm: false);
      c.screen('Senden an');
      await c.waitFor('Senden an', seconds: 10);
      await c.typeInto('Titel hinzufügen', 'Erster Abend am Meer');
      await c.hideKeyboard();
      await c.snap();

      c.step('Album wählen und senden', 'Sommerurlaub 2026 antippen.',
          'Das Album Sommerurlaub 2026 öffnet sich, darin der Strand am Abend.',
          explain: 'Ein Tipp auf das Album sendet das Foto dorthin und öffnet das Album, damit man sieht, dass es angekommen ist.');
      await c.tap('Sommerurlaub 2026');
      c.screen('Album');
      await c.check('Im Sommerurlaub angekommen', () => mediaCount(1, album: 'Sommerurlaub 2026'));
      await c.check('Insgesamt sieben', () => mediaCount(7));
      await c.check('Mit Titel Erster Abend am Meer', () async => (await media('Sommerurlaub 2026')).first['caption'] == 'Erster Abend am Meer');
      await c.settle(max: const Duration(seconds: 3));
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      Offline.simulated.value = false;
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
