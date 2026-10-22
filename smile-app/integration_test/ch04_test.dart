// Kapitel 4: Im Album (tools/testsuite, 2026-10-21).
// Startet dort, wo Kapitel 3 endet: im Album Geburtstage liegen vier Fotos
// und zwei Videos, im Sommerurlaub 2026 ein Foto.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_app/services/channel_service.dart';
import 'package:smile_app/services/object_picture_service.dart';
import 'package:smile_app/services/space_service.dart';
import 'package:smile_app/services/upload_queue.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'support/backend.dart';
import 'support/chapter.dart';

const anna = 'anna.berger@example.com';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 4: Im Album', (tester) async {
    // ---------------------------------------------------------------- Startzustand (Ende Kapitel 3)
    await TestBackend.reset();
    await TestBackend.person('paul.berger@example.com', 'Paul Berger', handle: 'paul.berger');
    await TestBackend.person(anna, 'Anna Berger', handle: 'anna.berger');
    final support = (await getApplicationSupportDirectory()).path;
    final media = '$support/fixtures/media';
    await TestBackend.setAvatar(anna, await File('$support/fixtures/profiles/frau_mittel.png').readAsBytes(), 'image/png');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('tips_enabled', false); // Tipps haben ein eigenes Kapitel.
    final semantics = tester.ensureSemantics();
    var birthdays = '';

    Future<List<Map>> items([String? album]) async {
      final rows = await TestBackend.select(
          'media_items', 'select=id,media_type,caption,channel_id,created_at&order=created_at.asc');
      final id = album == null ? birthdays : (await TestBackend.select('channels', 'select=id&name=eq.${Uri.encodeComponent(album)}')).first['id'];
      return rows.cast<Map>().where((r) => r['channel_id'] == id).toList();
    }

    Future<String> idOf(String caption) async => (await items()).firstWhere((r) => r['caption'] == caption)['id'] as String;
    Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
      final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
      while (true) {
        if (await test()) return true;
        if (DateTime.now().isAfter(end)) return false;
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    final c = Chapter(tester, binding,
        id: 'ch04',
        title: 'Im Album',
        intro: 'Anna schaut sich ihre Fotos und Videos an, gibt einem Foto einen Titel, ändert und löscht ihn wieder, wählt mehrere '
            'Fotos aus, macht eines zum Titelbild, blendet Fotos nur für sich aus und holt sie zurück, löscht ein Foto für alle und '
            'spielt das Album als Diashow ab.');

    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    unawaited(app.main());
    try {
      // Anmelden und den Stand von Kapitel 3 herstellen (nicht Teil des Kapitels).
      c.screen('Anmeldung');
      if (!await c.waitFor('Code anfordern', seconds: 20)) throw TestFailure('Anmeldung erscheint nicht');
      await c.typeInto('E-Mail-Adresse', anna);
      await c.tap('Code anfordern');
      await c.waitFor('Wir haben einen Code', seconds: 10);
      await c.typeInto('', await TestBackend.otp(anna), logAs: 'Code-Kästchen');
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      final spaceId = await SpaceService().createSpace('Familie Berger');
      final pictures = ObjectPictureService();
      final house = (bytes: await File('$media/04_haus_mit_garten.jpg').readAsBytes(), mimeType: 'image/jpeg');
      await pictures.save(ObjectKind.space, spaceId, await pictures.uploadPicked(ObjectKind.space, spaceId, house));
      final summer = await ChannelService().createChannel(spaceId: spaceId, name: 'Sommerurlaub 2026');
      final beach = (bytes: await File('$media/26_strand_am_abend.jpg').readAsBytes(), mimeType: 'image/jpeg');
      await pictures.save(ObjectKind.album, summer, await pictures.uploadPicked(ObjectKind.album, summer, beach));
      birthdays = await ChannelService().createChannel(spaceId: spaceId, name: 'Geburtstage');
      await ChannelService().createChannel(spaceId: spaceId, name: 'Weihnachten');
      // Sent one after another, as in chapter 3 (the real upload queue).
      for (final (file, caption) in [
        ('07_geburtstagstorte.jpg', 'Omas 80. Geburtstag'),
        ('20_luftballons.mp4', null),
        ('49_torte_mit_kerzen.jpg', null),
        ('21_obstschale.jpg', 'Obst für alle'),
        ('40_hund_laeuft.mp4', null),
        ('11_herbstwald.jpg', null),
      ]) {
        await UploadQueue.instance.enqueue(birthdays, [XFile('$media/$file')], captions: [caption]);
        final n = (await items()).length + 1;
        if (!await eventually(() async => (await items()).length >= n, seconds: 120)) throw TestFailure('Senden von $file dauert zu lange');
      }
      await UploadQueue.instance.enqueue(summer, [XFile('$media/26_strand_am_abend.jpg')], captions: ['Erster Abend am Meer']);
      if (!await eventually(() async => (await items('Sommerurlaub 2026')).length == 1, seconds: 60)) {
        throw TestFailure('Senden in den Sommerurlaub dauert zu lange');
      }
      await eventually(() async => (await items()).every((r) => true) &&
          (await TestBackend.select('media_items', 'select=processing_status')).every((r) => (r as Map)['processing_status'] == 'ready'),
          seconds: 120);
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1500);
      await c.waitFor('~Du:', seconds: 15);
      await c.hideKeyboard();
      await c.start();

      final rows = await items();
      final herbst = rows[5]['id'] as String, hund = rows[4]['id'] as String, kerzen = rows[2]['id'] as String;
      final obst = await idOf('Obst für alle');

      Future<void> tapItem(String id, String label, {bool long = false}) async {
        final f = find.byKey(ValueKey(id));
        // Up or down, wherever it is (the album is a reversed list).
        final any = find.byKey(ValueKey(id), skipOffstage: false);
        if (any.evaluate().isEmpty) {
          // Not built: walk the list from one end to the other in half screens.
          final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
          for (var at = position.minScrollExtent; at <= position.maxScrollExtent + 1; at += position.viewportDimension / 2) {
            position.jumpTo(at.clamp(position.minScrollExtent, position.maxScrollExtent));
            await tester.pump(const Duration(milliseconds: 50));
            if (any.evaluate().isNotEmpty) break;
          }
          if (any.evaluate().isNotEmpty) await Scrollable.ensureVisible(any.evaluate().first, alignment: 0.5);
        } else {
          await Scrollable.ensureVisible(any.evaluate().first, alignment: 0.5);
        }
        await c.settle();
        if (long) {
          await tester.longPress(f, warnIfMissed: false);
        } else {
          await tester.tap(f, warnIfMissed: false);
        }
        c.logTap(label);
        await c.settle();
      }

      Future<void> tapExact(String text) async {
        await tester.tap(find.text(text).last, warnIfMissed: false);
        c.logTap(text);
        await c.settle();
      }

      // ---------------------------------------------------------------- Ansehen
      c.step('Ausgangslage', 'Smile ist geöffnet, Anna ist angemeldet.',
          'Die Startseite: Geburtstage mit Du: 4 Fotos, 2 Videos, Sommerurlaub 2026 mit Du: Foto, Weihnachten noch leer.',
          explain: 'So endet Kapitel 3.');
      c.screen('Startseite');
      await c.check('Sieben im Server', () async => (await TestBackend.select('media_items', 'select=id')).length == 7);
      await c.snap();

      c.step('Album öffnen', 'Geburtstage antippen.', 'Das Album: die Fotos und Videos untereinander, das neueste (Herbstwald) ganz unten.',
          explain: 'Wie ein Chat: unten das Neueste. Eigene Fotos stehen rechts.');
      await c.tap('Geburtstage');
      c.screen('Album');
      await c.check('Album offen', () => c.waitFor('Geburtstage', seconds: 10));
      await c.snap();

      c.step('Foto öffnen', 'Auf den Herbstwald tippen.', 'Der Herbstwald füllt den Bildschirm, oben Zurück und das Zeichen für den Titel.',
          explain: 'Im Album ist ein Foto zugeschnitten; hier ist es ganz zu sehen.');
      await tapItem(herbst, 'Foto');
      c.screen('Foto');
      await c.check('Großansicht mit Titel-Knopf', () => c.waitFor('Titel bearbeiten', seconds: 5));
      await c.snap();

      c.step('Titel hinzufügen', 'Auf das Titel-Zeichen tippen, Herbst im Park eingeben und Speichern antippen.',
          'Unten im Bild steht jetzt Herbst im Park.',
          explain: 'Auch nachträglich kann ein Foto einen Titel bekommen, aber nur von dem, der es gesendet hat (oder vom Admin).');
      await c.tap('Titel bearbeiten');
      c.screen('Titel bearbeiten');
      await c.waitFor('Speichern', seconds: 3);
      await c.typeInto('Titel hinzufügen', 'Herbst im Park');
      await c.tap('Speichern', last: true);
      c.screen('Foto');
      await c.check('Titel gespeichert', () => eventually(() async => (await items()).any((r) => r['caption'] == 'Herbst im Park')));
      await c.check('Titel im Bild', () => c.waitFor('Herbst im Park', seconds: 5));
      await c.hideKeyboard();
      await c.snap();

      c.step('Titel bearbeiten: Abbrechen', 'Noch einmal auf das Titel-Zeichen tippen, dann Abbrechen.',
          'Der Titel bleibt Herbst im Park.', kind: 'Abzweigung', explain: 'Abbrechen ändert nichts.');
      await c.tap('Titel bearbeiten');
      c.screen('Titel bearbeiten');
      await c.waitFor('Speichern', seconds: 3);
      await c.tap('Abbrechen', last: true);
      c.screen('Foto');
      await c.check('Titel unverändert', () async => (await items()).any((r) => r['caption'] == 'Herbst im Park'));
      await c.hideKeyboard();
      await c.snap();

      c.step('Titel ändern', 'Auf das Titel-Zeichen tippen, Herbstspaziergang eingeben und Speichern.',
          'Unten im Bild steht jetzt Herbstspaziergang.', explain: 'Der alte Titel wird ersetzt.');
      await c.tap('Titel bearbeiten');
      c.screen('Titel bearbeiten');
      await c.waitFor('Speichern', seconds: 3);
      await c.typeInto('Titel hinzufügen', 'Herbstspaziergang');
      await c.tap('Speichern', last: true);
      c.screen('Foto');
      await c.check('Neuer Titel gespeichert', () => eventually(() async => (await items()).any((r) => r['caption'] == 'Herbstspaziergang')));
      await c.hideKeyboard();
      await c.snap();

      c.step('Titel löschen', 'Auf das Titel-Zeichen tippen, dann rechts im Feld auf den Papierkorb (Titel löschen).',
          'Das Fenster schließt sich, das Foto hat keinen Titel mehr.',
          kind: 'Abzweigung', explain: 'Mit einem Tipp ist der Titel weg; das Foto bleibt.');
      await c.tap('Titel bearbeiten');
      c.screen('Titel bearbeiten');
      await c.waitFor('Speichern', seconds: 3);
      await c.tap('Titel löschen', last: true);
      c.screen('Foto');
      await c.check('Titel entfernt', () => eventually(() async => (await items()).firstWhere((r) => r['id'] == herbst)['caption'] == null));
      await c.check('Nicht mehr im Bild', () => c.gone('Herbstspaziergang', seconds: 3));
      await c.hideKeyboard();
      await c.snap();

      c.step('Zurück ins Album', 'Oben links zurück.', 'Wieder das Album.', explain: 'Die Großansicht schließt sich.');
      await c.back();
      c.screen('Album');
      await c.check('Album', () => c.waitFor('Geburtstage', seconds: 5));
      await c.snap();

      c.step('Video ansehen', 'Auf das Video Hund läuft tippen.', 'Das Video läuft bildschirmfüllend.',
          explain: 'Videos spielen mit einem Tipp; ein weiterer Tipp hält sie an.');
      await tapItem(hund, 'Video');
      c.screen('Video');
      await c.settle(max: const Duration(seconds: 2));
      await c.snap();

      c.step('Video schließen', 'Zurück.', 'Wieder das Album.', explain: 'Das Video hört auf.');
      await c.back();
      c.screen('Album');
      await c.check('Album', () => c.waitFor('Geburtstage', seconds: 5));
      await c.snap();

      // ---------------------------------------------------------------- Auswählen
      c.step('Auswählen', 'Lange auf die Torte mit Kerzen drücken.',
          'Oben steht 1 ausgewählt, die Torte ist markiert. Unten: Alle, Titelbild und Löschen.',
          explain: 'Langes Drücken wählt aus, wie in WhatsApp. Danach wählt jeder Tipp ein weiteres aus oder ab.');
      await tapItem(kerzen, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await c.check('1 ausgewählt', () => c.waitFor('1 ausgewählt', seconds: 3));
      await c.check('Titelbild angeboten', () => c.waitFor('Titelbild', seconds: 2));
      await c.snap();

      c.step('Weiteres auswählen', 'Auf die Obstschale tippen.', 'Oben steht 2 ausgewählt. Titelbild gibt es jetzt nicht mehr (nur bei einem Foto).',
          explain: 'Ein Titelbild kann nur ein einzelnes Foto sein.');
      await tapItem(obst, 'Foto in der Auswahl');
      await c.check('2 ausgewählt', () => c.waitFor('2 ausgewählt', seconds: 3));
      await c.check('Kein Titelbild bei zweien', () => c.gone('Titelbild', seconds: 2));
      await c.snap();

      c.step('Alle auswählen', 'Unten auf Alle tippen.', 'Oben steht Alle 6 ausgewählt, unten heißt der Knopf jetzt Keine.',
          kind: 'Abzweigung', explain: 'Alle wählt das ganze Album aus.');
      await tapExact('Alle');
      await c.check('Alle 6 ausgewählt', () => c.waitFor('Alle 6 ausgewählt', seconds: 3));
      await c.snap();

      c.step('Keine auswählen', 'Auf Keine tippen.', 'Die Auswahl endet, wieder das normale Album.',
          kind: 'Abzweigung', explain: 'Keine hebt alles auf.');
      await tapExact('Keine');
      c.screen('Album');
      await c.check('Auswahl beendet', () => c.gone('ausgewählt', seconds: 3));
      await c.snap();

      c.step('Auswahl schließen', 'Lange auf die Torte mit Kerzen drücken, dann oben links auf das Kreuz.',
          'Die Auswahl endet, nichts ist passiert.', kind: 'Abzweigung', explain: 'Das Kreuz bricht die Auswahl ab.');
      await tapItem(kerzen, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await c.waitFor('1 ausgewählt', seconds: 3);
      await tester.tap(find.byIcon(SmileIcons.close).first,
          warnIfMissed: false);
      c.logTap('Schließen');
      await c.settle();
      c.screen('Album');
      await c.check('Auswahl beendet', () => c.gone('ausgewählt', seconds: 3));
      await c.snap();

      c.step('Auswahl mit Zurück beenden', 'Lange auf die Torte mit Kerzen drücken, dann die Zurück-Geste von Android.',
          'Die Auswahl endet, Anna bleibt im Album.', kind: 'Abzweigung',
          explain: 'Wie in WhatsApp: Zurück hebt zuerst die Auswahl auf, statt das Album zu verlassen.');
      await tapItem(kerzen, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await c.waitFor('1 ausgewählt', seconds: 3);
      await c.back();
      c.screen('Album');
      await c.check('Auswahl beendet', () => c.gone('ausgewählt', seconds: 3));
      await c.check('Noch im Album', () => c.waitFor('Geburtstage', seconds: 2));
      await c.snap();

      c.step('Als Titelbild', 'Lange auf die Torte mit Kerzen drücken, dann Titelbild antippen.',
          'Die Auswahl endet; oben neben dem Namen ist jetzt die Torte mit Kerzen das Bild des Albums.',
          explain: 'Ein Foto aus dem Album wird sein Titelbild, auch auf der Startseite.');
      await tapItem(kerzen, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await c.waitFor('Titelbild', seconds: 3);
      await tapExact('Titelbild');
      c.screen('Album');
      await c.check('Titelbild gespeichert', () => eventually(() async =>
          (await TestBackend.select('channels', 'select=cover_media_id&id=eq.$birthdays')).first['cover_media_id'] == kerzen));
      await c.snap();

      // ---------------------------------------------------------------- Löschen und Ausblenden
      c.step('Löschen: die Frage', 'Lange auf den Herbstwald drücken, dann Löschen.',
          'Foto löschen?: Für alle löschen (bei allen und auf allen Frames, endgültig) oder Für mich löschen (nur bei dir weg, zurückholbar), dazu Abbrechen.',
          explain: 'Wer ein Foto gesendet hat, kann es für alle löschen. Für mich löschen blendet es nur bei einem selbst aus.');
      await tapItem(herbst, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await c.waitFor('Löschen', seconds: 3);
      await tapExact('Löschen');
      c.screen('Löschen-Frage');
      await c.check('Zwei Wege', () async =>
          await c.waitFor('Für alle löschen', seconds: 3) && await c.waitFor('Für mich löschen', seconds: 1));
      await c.snap();

      c.step('Löschen: daneben tippen', 'Oben neben die Frage tippen.', 'Die Frage schließt sich, nichts ist gelöscht.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben wirkt wie Abbrechen.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Auswahl');
      await c.check('Nichts gelöscht', () async => (await items()).length == 6);
      await c.snap();

      c.step('Löschen: Abbrechen', 'Noch einmal Löschen, dann Abbrechen.', 'Die Frage schließt sich, der Herbstwald bleibt.',
          kind: 'Abzweigung', explain: 'Abbrechen löscht nichts.');
      await tapExact('Löschen');
      c.screen('Löschen-Frage');
      await c.waitFor('Für alle löschen', seconds: 3);
      await c.tap('Abbrechen', last: true);
      await c.check('Nichts gelöscht', () async => (await items()).length == 6);
      final closeSel = find.byIcon(SmileIcons.close);
      if (closeSel.evaluate().isNotEmpty) await tester.tap(closeSel.first, warnIfMissed: false);
      await c.settle();
      c.screen('Album');
      await c.snap();

      c.step('Für mich löschen', 'Lange auf den Herbstwald drücken, Löschen, Für mich löschen.',
          'Der Herbstwald ist aus dem Album verschwunden.',
          explain: 'Nur Anna sieht ihn nicht mehr. Für alle anderen und auf den Frames bleibt er.');
      await tapItem(herbst, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await tapExact('Löschen');
      c.screen('Löschen-Frage');
      await c.tap('Für mich löschen');
      c.screen('Album');
      await c.check('Ausgeblendet gespeichert', () => eventually(() async => (await TestBackend.select('media_item_hides', 'select=media_item_id')).length == 1));
      await c.check('Für alle noch da', () async => (await items()).length == 6);
      await c.check('Im Album weg', () => eventually(() => find.byKey(ValueKey(herbst)).evaluate().isEmpty));
      await c.snap();

      c.step('Ausgeblendete anzeigen', 'Oben rechts auf die drei Punkte, dann Ausgeblendete anzeigen.',
          'Ausgeblendete Fotos: hier steht der Herbstwald.', explain: 'Was man für sich gelöscht hat, findet man hier wieder.');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Albums');
      await c.tap('Ausgeblendete anzeigen');
      c.screen('Ausgeblendete');
      await c.check('Ausgeblendete Fotos', () => c.waitFor('Ausgeblendete Fotos', seconds: 5));
      await c.check('Herbstwald da', () => eventually(() => find.byKey(ValueKey(herbst)).evaluate().isNotEmpty));
      await c.snap();

      c.step('Wieder einblenden', 'Lange auf den Herbstwald drücken, dann Einblenden.',
          'Hier steht jetzt Keine ausgeblendeten Fotos.', explain: 'Einblenden holt das Foto ins Album zurück.');
      await tapItem(herbst, 'Foto lange drücken', long: true);
      c.screen('Auswahl (ausgeblendet)');
      await tapExact('Einblenden');
      c.screen('Ausgeblendete');
      await c.check('Keine ausgeblendeten', () => c.waitFor('Keine ausgeblendeten Fotos', seconds: 5));
      await c.check('Nicht mehr ausgeblendet', () => eventually(() async => (await TestBackend.select('media_item_hides', 'select=media_item_id')).isEmpty));
      await c.snap();

      c.step('Aus den Ausgeblendeten zurück', 'Die Zurück-Geste von Android.', 'Das Album, der Herbstwald ist wieder da.',
          explain: 'Zurück führt aus den ausgeblendeten Fotos ins Album, nicht aus dem Album hinaus.');
      await c.back();
      c.screen('Album');
      await c.check('Herbstwald wieder im Album', () => eventually(() => find.byKey(ValueKey(herbst)).evaluate().isNotEmpty));
      await c.snap();

      c.step('Für alle löschen', 'Lange auf den Herbstwald drücken, Löschen, Für alle löschen.',
          'Der Herbstwald ist weg, für alle und auf allen Frames.', explain: 'Endgültig: das Foto ist auf dem Server gelöscht.');
      await tapItem(herbst, 'Foto lange drücken', long: true);
      c.screen('Auswahl');
      await tapExact('Löschen');
      c.screen('Löschen-Frage');
      await c.tap('Für alle löschen');
      c.screen('Album');
      await c.check('Auf dem Server gelöscht', () => eventually(() async => (await items()).length == 5));
      await c.check('Im Album weg', () => eventually(() => find.byKey(ValueKey(herbst)).evaluate().isEmpty));
      await c.snap();

      // ---------------------------------------------------------------- Diashow und Infos
      c.step('Diashow', 'Oben auf das Diashow-Zeichen tippen.', 'Die Fotos und Videos laufen nacheinander bildschirmfüllend.',
          explain: 'Wie auf einem Frame, nur auf dem Handy.');
      await c.tap('Diashow');
      c.screen('Diashow');
      await c.settle(max: const Duration(seconds: 2));
      await c.snap();

      c.step('Diashow: Einstellungen', 'Auf den Bildschirm tippen, dann auf das Zahnrad.',
          'Die Einstellungen der Diashow: Anzeigedauer, Reihenfolge, Ausrichtung, Videos, Füllen und mehr.',
          explain: 'Dieselben Einstellungen wie beim Frame (Kapitel 7 prüft sie einzeln).');
      // The buttons come with a tap on the picture (they hide again by themselves).
      await c.tapAt(tester.getCenter(find.byType(Scaffold).last), 'Bildschirm antippen');
      await tester.tap(find.byTooltip('Diashow-Einstellungen').first, warnIfMissed: false);
      c.logTap('Diashow-Einstellungen');
      await c.settle();
      c.screen('Diashow-Einstellungen');
      await c.check('Einstellungen offen', () => c.waitFor('Gilt für die Diashow', seconds: 3));
      await c.settle(max: const Duration(seconds: 2));
      await c.snap();

      // Every option, group by group: tapped, then read back from the phone.
      Future<Map<String, dynamic>> slidePrefs() async {
        final p = await SharedPreferences.getInstance();
        await p.reload();
        final raw = p.getString('phone_slideshow');
        return raw == null ? {} : (jsonDecode(raw) as Map).cast<String, dynamic>();
      }

      Future<void> option(String label, String key, Object value) async {
        final f = find.text(label);
        await Scrollable.ensureVisible(find.text(label, skipOffstage: false).evaluate().first);
        await tester.tap(f.last, warnIfMissed: false);
        c.logTap(label);
        await c.settle();
        await c.check('$label gespeichert', () async => (await slidePrefs())[key] == value);
      }

      c.step('Diashow: Anzeigedauer', 'Nacheinander 5 Sekunden, 20 Sekunden und 1 Minute wählen, dann wieder 10 Sekunden.',
          'Das gewählte Kästchen hat jeweils ein Häkchen; am Ende wieder 10 Sekunden.',
          kind: 'Abzweigung', explain: 'So lange bleibt jedes Foto stehen. Die Einstellungen gelten nur für die Diashow auf diesem Handy.');
      await option('5 Sekunden', 'seconds', 5);
      await option('20 Sekunden', 'seconds', 20);
      await option('1 Minute', 'seconds', 60);
      await option('10 Sekunden', 'seconds', 10);
      await c.snap();

      c.step('Diashow: Reihenfolge', 'Neueste zuerst, dann Zufällig, dann wieder Der Reihe nach wählen.',
          'Am Ende hat Der Reihe nach das Häkchen.', kind: 'Abzweigung',
          explain: 'Der Reihe nach heißt: vom ältesten zum neuesten Foto.');
      await option('Neueste zuerst', 'order', 'newest');
      await option('Zufällig', 'order', 'shuffle');
      await option('Der Reihe nach', 'order', 'oldest');
      await c.snap();

      c.step('Diashow: Videos', 'Wie ein Foto (10 s), dann Keine Videos, dann wieder Ganze Länge wählen.', 'Am Ende hat Ganze Länge das Häkchen.',
          kind: 'Abzweigung', explain: 'Videos laufen ganz, nur so lange wie ein Foto oder gar nicht.');
      await option('Wie ein Foto (10 s)', 'video_length', 'photo');
      await option('Keine Videos', 'video_length', 'none');
      await option('Ganze Länge', 'video_length', 'full');
      await c.snap();

      c.step('Diashow: Bildschirm füllen', 'Nie, dann Immer, dann wieder Wenn passend wählen.', 'Am Ende hat Wenn passend das Häkchen.',
          kind: 'Abzweigung', explain: 'Füllen schneidet das Foto so zu, dass kein schwarzer Rand bleibt.');
      await option('Nie', 'fill_mode', 'fit');
      await option('Immer', 'fill_mode', 'fill');
      await option('Wenn passend', 'fill_mode', 'auto');
      await c.snap();

      c.step('Diashow: Schalter', 'Langsamer Zoom, Videos mit Ton und Titel anzeigen je zweimal umschalten.',
          'Jeder Schalter springt um und wieder zurück.', kind: 'Abzweigung',
          explain: 'Zoom lässt Fotos langsam größer werden; Ton spielt Videos mit Ton; Titel zeigt den Titel unten im Bild.');
      for (final (label, key) in [('Langsamer Zoom', 'slow_zoom'), ('Videos mit Ton', 'sound'), ('Titel anzeigen', 'captions')]) {
        final before = (await slidePrefs())[key];
        for (var round = 0; round < 2; round++) {
          final f = find.text(label);
          await Scrollable.ensureVisible(find.text(label, skipOffstage: false).evaluate().first);
          await tester.tap(f.last, warnIfMissed: false);
          c.logTap(label);
          await c.settle();
        }
        await c.check('$label zweimal umgeschaltet, wieder wie vorher', () async => (await slidePrefs())[key] == (before ?? (await slidePrefs())[key]));
      }
      await c.snap();

      c.step('Diashow: Ausrichtung', 'Querformat, dann Hochformat, dann wieder Automatisch wählen.', 'Am Ende hat Automatisch das Häkchen, das Handy steht hochkant.',
          kind: 'Abzweigung', explain: 'Hoch- oder Querformat dreht das Bild sofort, aber nur während der Diashow. Bei Automatisch entscheidet, wie man das Handy hält.');
      Future<void> turned() async {
        final end = DateTime.now().add(const Duration(milliseconds: 1500));
        while (DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await c.settle();
      }
      await option('Querformat', 'orientation', 'landscape');
      await turned();
      await option('Hochformat', 'orientation', 'portrait');
      await turned();
      await option('Automatisch', 'orientation', 'auto');
      await c.snap();

      c.step('Diashow-Einstellungen: daneben tippen', 'Oben neben die Einstellungen tippen.', 'Die Einstellungen schließen sich, die Diashow läuft weiter.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt die Einstellungen.');
      await c.tapAt(const Offset(200, 60), 'Schließen');
      c.screen('Diashow');
      await c.check('Einstellungen zu', () => c.gone('Gilt für die Diashow', seconds: 3));
      await c.snap();

      c.step('Diashow beenden', 'Auf den Bildschirm tippen, dann oben rechts auf das Kreuz.', 'Wieder das Album.',
          explain: 'Das Kreuz beendet die Diashow.');
      // Tapping the picture hides the buttons, tapping again shows them.
      await c.tapAt(tester.getCenter(find.byType(Scaffold).last), 'Bildschirm antippen');
      await c.tapAt(tester.getCenter(find.byType(Scaffold).last), 'Bildschirm antippen');
      await tester.tap(find.byIcon(SmileIcons.close).last, warnIfMissed: false);
      c.logTap('Schließen');
      await c.settle();
      c.screen('Album');
      await c.check('Album', () => c.waitFor('Geburtstage', seconds: 5));
      await c.snap();

      c.step('Infos über das Menü', 'Oben rechts auf die drei Punkte, dann Infos zum Album.', 'Die Seite des Albums Geburtstage.',
          kind: 'Abzweigung', explain: 'Derselbe Weg wie der Tipp auf den Namen (Kapitel 2).');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Albums');
      await c.tap('Infos zum Album', last: true);
      c.screen('Album-Infos');
      await c.check('Album-Infos', () => c.waitFor('Album löschen', seconds: 10));
      await c.check('Annas Profilbild (lila) in der Personenliste', () => c.colorIn('SmileAvatar', '#c9b6e4', seconds: 8));
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
