// Kapitel 2: Space und Alben (tools/testsuite, 2026-10-21).
// Startet dort, wo Kapitel 1 endet: Anna ist angemeldet, hat Namen, Bild
// und Smile-Namen. Sie legt ihren Space an, gibt ihm Namen und Bild, legt
// Alben auf allen Wegen an und gibt einem davon ein Titelbild.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_app/main.dart' as app;

import 'support/backend.dart';
import 'support/chapter.dart';

const anna = 'anna.berger@example.com';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 2: Space und Alben', (tester) async {
    // ---------------------------------------------------------------- Startzustand (Ende Kapitel 1)
    await TestBackend.reset();
    await TestBackend.person('paul.berger@example.com', 'Paul Berger', handle: 'paul.berger');
    await TestBackend.person(anna, 'Anna Berger', handle: 'anna.berger');
    final fixtures = '${(await getApplicationSupportDirectory()).path}/fixtures/profiles';
    await TestBackend.setAvatar(anna, await File('$fixtures/frau_mittel.png').readAsBytes(), 'image/png');
    final media = '${(await getApplicationSupportDirectory()).path}/fixtures/media';
    final houseUrl = await TestBackend.putPublic(
        'testsuite/haus_am_abend.jpg', await File('$media/29_haus_am_abend.jpg').readAsBytes(), 'image/jpeg');
    final beachUrl = await TestBackend.putPublic(
        'testsuite/strand_am_abend.jpg', await File('$media/26_strand_am_abend.jpg').readAsBytes(), 'image/jpeg');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('tips_enabled', false); // Tipps haben ein eigenes Kapitel.
    final semantics = tester.ensureSemantics();

    Future<int> rows(String table) async => ((await TestBackend.state())['rows'] as Map)[table] as int;
    Future<Map> space() async {
      final r = await TestBackend.select('spaces', 'select=name,avatar_path');
      return r.isEmpty ? {} : r.first as Map;
    }

    Future<Map> album(String name) async {
      final r = await TestBackend.select('channels', 'select=name,cover_path,cover_media_id&name=eq.${Uri.encodeComponent(name)}');
      return r.isEmpty ? {} : r.first as Map;
    }

    // Files of one picture folder (state.sql names them), once the old ones are cleaned up.
    Future<bool> filesSettle(String key, int count) async {
      for (var i = 0; i < 40; i++) {
        if ((((await TestBackend.state())['files'] as Map)[key] as int? ?? 0) == count) return true;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return false;
    }

    Future<List<String>> albumNames() async =>
        [for (final r in await TestBackend.select('channels', 'select=name&order=name')) (r as Map)['name'] as String];

    final c = Chapter(tester, binding,
        id: 'ch02',
        title: 'Space und Alben',
        intro: 'Anna richtet Smile für ihre Familie ein: Sie legt den Space Familie Berger an, gibt ihm einen Namen und ein Bild, '
            'legt Alben auf allen Wegen an (auf der Space-Seite, im Menü der Startseite), benennt ein Album um und gibt ihm ein '
            'Titelbild. Mitgeprüft: Abbrechen, leerer Name, unveränderter Name, Bild entfernen, doppelt tippen.');

    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    unawaited(app.main());
    try {
      // Anmelden wie am Ende von Kapitel 1 (nicht Teil des Kapitels).
      c.screen('Anmeldung');
      if (!await c.waitFor('Code anfordern', seconds: 20)) throw TestFailure('Anmeldung erscheint nicht');
      await c.typeInto('E-Mail-Adresse', anna);
      await c.tap('Code anfordern');
      await c.waitFor('Wir haben einen Code', seconds: 10);
      await c.typeInto('', await TestBackend.otp(anna), logAs: 'Code-Kästchen');
      if (!await c.waitFor('Willkommen bei Smile', seconds: 20)) throw TestFailure('Startseite erscheint nicht');
      await c.hideKeyboard();
      await c.start();

      Future<void> tapExact(String text) async {
        await tester.tap(find.text(text).last, warnIfMissed: false);
        c.logTap(text);
        await c.settle();
      }

      // ---------------------------------------------------------------- Space anlegen
      c.step('Ausgangslage', 'Smile ist geöffnet, Anna ist angemeldet.',
          'Die Startseite: Willkommen bei Smile mit Ich wurde eingeladen und Ich richte Smile ein.',
          explain: 'So endet Kapitel 1. Anna hat noch keinen Space und kein Album.');
      c.screen('Startseite (leer)');
      await c.check('Noch kein Space', () async => await rows('spaces') == 0);
      await c.snap();

      c.step('Ich richte Smile ein', 'Ich richte Smile ein antippen.',
          'Ein Fenster Space anlegen mit einem Feld Name (Beispiel: z. B. Familie Müller), dazu Abbrechen und Anlegen.',
          explain: 'Ein Space ist das Zuhause für Alben und Frames, zum Beispiel eine Familie oder ein Hotel. Wer ihn anlegt, ist sein Admin.');
      await c.tap('Ich richte Smile ein');
      c.screen('Space anlegen');
      await c.check('Fenster Space anlegen', () => c.waitFor('Space anlegen', seconds: 3));
      await c.snap();

      c.step('Space anlegen: Abbrechen', 'Abbrechen antippen.', 'Das Fenster schließt sich, es entsteht kein Space.',
          kind: 'Abzweigung', explain: 'Abbrechen legt nichts an.');
      await c.tap('Abbrechen', last: true);
      c.screen('Startseite (leer)');
      await c.check('Fenster zu', () => c.gone('Space anlegen', seconds: 3));
      await c.check('Kein Space', () async => await rows('spaces') == 0);
      await c.hideKeyboard();
      await c.snap();

      c.step('Space anlegen: daneben tippen', 'Noch einmal Ich richte Smile ein, dann oben neben das Fenster tippen.',
          'Das Fenster schließt sich, es entsteht kein Space.',
          kind: 'Abzweigung', explain: 'Ein Tipp neben das Fenster wirkt wie Abbrechen.');
      await c.tap('Ich richte Smile ein');
      c.screen('Space anlegen');
      await c.waitFor('Space anlegen', seconds: 3);
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Startseite (leer)');
      await c.check('Fenster zu', () => c.gone('Space anlegen', seconds: 3));
      await c.check('Kein Space', () async => await rows('spaces') == 0);
      await c.hideKeyboard();
      await c.snap();

      c.step('Space anlegen ohne Namen', 'Noch einmal Ich richte Smile ein, dann gleich Anlegen antippen.',
          'Das Fenster bleibt offen, unter dem Feld steht: Bitte gib einen Namen ein.',
          kind: 'Abzweigung', explain: 'Ohne Namen wird nichts angelegt; das Fenster sagt, was fehlt.');
      await c.tap('Ich richte Smile ein');
      c.screen('Space anlegen');
      await c.waitFor('Space anlegen', seconds: 3);
      await c.tap('Anlegen', last: true);
      await c.check('Meldung Bitte gib einen Namen ein', () => c.waitFor('Bitte gib einen Namen ein', seconds: 3));
      await c.check('Fenster noch offen', () => c.waitFor('Space anlegen', seconds: 1));
      await c.check('Kein Space', () async => await rows('spaces') == 0);
      await c.snap();

      c.step('Space anlegen', 'Im selben Fenster Familie Berger eingeben und Anlegen antippen (hier absichtlich zweimal schnell).',
          'Die Seite des neuen Space: Familie Berger, darunter Du bist Admin, die Knöpfe Album, Frame und Co-Admin, dann Noch kein Album, Noch kein Frame und Admins mit Du.',
          explain: 'Der Server legt den Space an und macht Anna zur Admin. Danach zeigt Smile gleich die Seite des Space, auf der es weitergeht. '
              'Der doppelte Tipp darf keinen zweiten Space anlegen.');
      await c.typeInto('Name', 'Familie Berger');
      await c.check('Meldung beim Tippen verschwunden', () => c.gone('Bitte gib einen Namen ein', seconds: 2));
      await c.tap('Anlegen', last: true, twice: true);
      c.screen('Space');
      await c.check('Seite des Space', () => c.waitFor('Du bist Admin', seconds: 15));
      await c.check('Genau ein Space', () async => await rows('spaces') == 1);
      await c.check('Name Familie Berger', () async => (await space())['name'] == 'Familie Berger');
      await c.hideKeyboard();
      await c.snap();

      // ---------------------------------------------------------------- Space: Menü, Name, Bild
      c.step('Menü des Space', 'Oben rechts auf die drei Punkte tippen.',
          'Das Menü zeigt Space umbenennen, Bild ändern, Album anlegen, Frame verbinden und Co-Admin einladen.',
          kind: 'Abzweigung', explain: 'Alles, was man auf der Seite tun kann, steht auch im Menü.');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Space');
      await c.check('Fünf Einträge', () async =>
          await c.waitFor('Space umbenennen', seconds: 2) && await c.waitFor('Co-Admin einladen', seconds: 1));
      await c.snap();

      c.step('Menü schließen', 'Neben das Menü tippen.', 'Das Menü schließt sich.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt das Menü, ohne etwas zu tun.');
      await c.tapAt(const Offset(60, 500), 'Schließen');
      c.screen('Space');
      // The entries are also on the page itself: the menu's own items must be gone.
      await c.check('Menü zu', () async {
        await c.settle();
        return find.byWidgetPredicate((w) => w is PopupMenuItem).evaluate().isEmpty;
      });
      await c.snap();

      c.step('Menü: Space umbenennen', 'Drei Punkte, Space umbenennen, dann Abbrechen.',
          'Dasselbe Fenster wie beim Stift; nach Abbrechen bleibt der Name.',
          kind: 'Abzweigung', explain: 'Der Menüeintrag führt zum selben Fenster wie der Stift.');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Space');
      await c.tap('Space umbenennen', last: true);
      c.screen('Space umbenennen');
      await c.check('Fenster Space umbenennen', () => c.waitFor('Speichern', seconds: 3));
      await c.tap('Abbrechen', last: true);
      c.screen('Space');
      await c.check('Name unverändert', () async => (await space())['name'] == 'Familie Berger');
      await c.hideKeyboard();
      await c.snap();

      c.step('Menü: Bild ändern', 'Drei Punkte, Bild ändern, dann die Auswahl am Griff oben antippen.',
          'Dieselbe Auswahl wie beim Tipp auf das Bild; sie schließt sich wieder.',
          kind: 'Abzweigung', explain: 'Auch dieser Menüeintrag führt zur selben Auswahl.');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Space');
      await c.tap('Bild ändern', last: true);
      c.screen('Bild für den Space');
      await c.check('Auswahl offen', () => c.waitFor('Bild für Familie Berger', seconds: 3));
      await tester.tap(find.bySemanticsLabel(RegExp('Gitter|Ziehpunkt|Drag handle', caseSensitive: false)).first, warnIfMissed: false);
      c.logTap('Gitter');
      await c.settle();
      c.screen('Space');
      await c.check('Auswahl zu', () => c.gone('Bild für Familie Berger', seconds: 3));
      await c.snap();

      c.step('Menü: Album anlegen', 'Drei Punkte, Album anlegen, dann Abbrechen.',
          'Dasselbe Fenster wie beim Knopf Album; nach Abbrechen entsteht kein Album.',
          kind: 'Abzweigung', explain: 'Der dritte Weg zum selben Fenster.');
      await c.tap('Weitere Optionen');
      c.screen('Menü des Space');
      await c.tap('Album anlegen', last: true);
      c.screen('Album anlegen');
      await c.check('Fenster Album anlegen', () => c.waitFor('Anlegen', seconds: 3));
      await c.tap('Abbrechen', last: true);
      c.screen('Space');
      await c.check('Kein Album', () async => await rows('channels') == 0);
      await c.hideKeyboard();
      await c.snap();

      c.step('Space umbenennen: Abbrechen', 'Auf den Stift neben Familie Berger tippen, dann Abbrechen.',
          'Das Fenster schließt sich, der Name bleibt Familie Berger.',
          kind: 'Abzweigung', explain: 'Abbrechen ändert nichts.');
      await c.tap('Space umbenennen');
      c.screen('Space umbenennen');
      await c.waitFor('Speichern', seconds: 3);
      await c.tap('Abbrechen', last: true);
      c.screen('Space');
      await c.check('Name unverändert', () async => (await space())['name'] == 'Familie Berger');
      await c.hideKeyboard();
      await c.snap();

      c.step('Space umbenennen', 'Auf den Stift tippen, Familie Berger-Huber eingeben und Speichern antippen.',
          'Oben steht jetzt Familie Berger-Huber.',
          explain: 'Der neue Name erscheint sofort und wird im Hintergrund gespeichert. Alle Mitglieder sehen ihn.');
      await c.tap('Space umbenennen');
      c.screen('Space umbenennen');
      await c.waitFor('Speichern', seconds: 3);
      await c.typeInto('Name', 'Familie Berger-Huber');
      await c.tap('Speichern', last: true);
      c.screen('Space');
      await c.check('Neuer Name sichtbar', () => c.waitFor('Familie Berger-Huber', seconds: 5));
      await c.check('Neuer Name gespeichert', () async {
        for (var i = 0; i < 20; i++) {
          if ((await space())['name'] == 'Familie Berger-Huber') return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.hideKeyboard();
      await c.snap();

      c.step('Space zurück umbenennen', 'Noch einmal umbenennen in Familie Berger.', 'Oben steht wieder Familie Berger.',
          explain: 'Zurück zum ursprünglichen Namen.');
      await c.tap('Space umbenennen');
      c.screen('Space umbenennen');
      await c.waitFor('Speichern', seconds: 3);
      await c.typeInto('Name', 'Familie Berger');
      await c.tap('Speichern', last: true);
      c.screen('Space');
      await c.check('Name wieder Familie Berger', () async {
        for (var i = 0; i < 20; i++) {
          if ((await space())['name'] == 'Familie Berger') return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.hideKeyboard();
      await c.snap();

      c.step('Space-Namen unverändert speichern', 'Auf den Stift tippen und gleich Speichern antippen.',
          'Das Fenster schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Ein unveränderter Name wird gar nicht erst gespeichert.');
      await c.tap('Space umbenennen');
      c.screen('Space umbenennen');
      await c.waitFor('Speichern', seconds: 3);
      await c.tap('Speichern', last: true);
      c.screen('Space');
      await c.check('Name weiter Familie Berger', () async => (await space())['name'] == 'Familie Berger');
      await c.hideKeyboard();
      await c.snap();

      c.step('Bild des Space: Auswahl', 'Auf das runde Bild des Space tippen.',
          'Unten öffnet sich Bild für Familie Berger mit Foto aufnehmen, Vorhandenes Bild wählen und Von einer Internetadresse laden.',
          explain: 'Ein Space hat ein Bild wie ein Profil. Ohne Bild zeigt Smile die Anfangsbuchstaben.');
      await c.tap('Bild ändern');
      c.screen('Bild für den Space');
      await c.check('Drei Möglichkeiten', () async =>
          await c.waitFor('Bild für Familie Berger', seconds: 3) && await c.waitFor('Von einer Internetadresse', seconds: 1));
      await c.check('Noch kein Bild entfernen (es gibt keins)', () => c.gone('Bild entfernen', seconds: 1));
      await c.snap();

      c.step('Bild-Auswahl: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich, nichts ändert sich.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt die Auswahl.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Space');
      await c.check('Auswahl zu', () => c.gone('Bild für Familie Berger', seconds: 3));
      await c.snap();

      c.step('Bild des Space wählen', 'Auf das Bild tippen, Vorhandenes Bild wählen, dann Haus mit Garten antippen.',
          'Das Bild steht sofort im Kreis oben.',
          explain: 'Das Bild erscheint sofort und wird im Hintergrund hochgeladen. (In der Test-App: gezeichnete Testbilder statt der Galerie.)');
      await c.tap('Bild ändern');
      c.screen('Bild für den Space');
      await c.tap('Vorhandenes Bild');
      c.screen('Bildauswahl');
      await c.tap('Haus mit Garten', seconds: 10);
      c.screen('Space');
      await c.gone('Testbilder', seconds: 10);
      await c.check('Bild gespeichert', () async {
        for (var i = 0; i < 40; i++) {
          if ((await space())['avatar_path'] != null) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Genau eine Bilddatei, keine Überbleibsel', () => filesSettle('avatars/spaces/Familie Berger', 1));
      await c.snap();

      c.step('Bild des Space entfernen', 'Auf das Bild tippen und Bild entfernen wählen.',
          'Statt des Bildes stehen wieder die Anfangsbuchstaben FB.',
          kind: 'Abzweigung', explain: 'Bild entfernen gibt es erst, wenn ein Bild da ist. Danach zeigt Smile wieder die Anfangsbuchstaben.');
      await c.tap('Bild ändern');
      c.screen('Bild für den Space');
      await c.tap('Bild entfernen', seconds: 3);
      c.screen('Space');
      await c.check('Anfangsbuchstaben FB', () => c.waitFor('FB', seconds: 5));
      await c.check('Bild auf dem Server entfernt', () async {
        for (var i = 0; i < 20; i++) {
          if ((await space())['avatar_path'] == null) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Keine Bilddatei mehr', () => filesSettle('avatars/spaces/Familie Berger', 0));
      await c.snap();

      c.step('Bild des Space aufnehmen', 'Auf das Bild tippen, Foto aufnehmen, dann Haus mit Garten antippen.',
          'Das Haus steht wieder im Kreis.',
          explain: 'Normalerweise öffnet sich die Kamera. Die Test-App zeigt stattdessen ihre Testbilder.');
      await c.tap('Bild ändern');
      c.screen('Bild für den Space');
      await c.tap('Foto aufnehmen');
      c.screen('Bildauswahl');
      await c.tap('Haus mit Garten', seconds: 10);
      c.screen('Space');
      await c.gone('Testbilder', seconds: 10);
      await c.check('Bild gespeichert', () async {
        for (var i = 0; i < 40; i++) {
          if ((await space())['avatar_path'] != null) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Genau eine Bilddatei, keine Überbleibsel', () => filesSettle('avatars/spaces/Familie Berger', 1));
      await c.snap();

      c.step('Bild des Space von einer Internetadresse', 'Auf das Bild tippen, Von einer Internetadresse laden, die Adresse eines Bildes (Haus am Abend) eingeben und Laden antippen.',
          'Das Fenster lädt das Bild und schließt sich; im Kreis steht jetzt das Haus am Abend.',
          explain: 'Wie beim Profilbild in Kapitel 1: das Bild wird erst geladen und geprüft, dann übernommen.');
      final before = (await space())['avatar_path'];
      await c.tap('Bild ändern');
      c.screen('Bild für den Space');
      await c.tap('Von einer Internetadresse');
      c.screen('Bild-URL');
      await c.typeInto('https://', houseUrl);
      await c.tap('Laden', last: true);
      c.screen('Space');
      await c.check('Fenster zu', () => c.gone('Bild-URL', seconds: 15));
      await c.check('Neues Bild gespeichert', () async {
        for (var i = 0; i < 40; i++) {
          final now = (await space())['avatar_path'];
          if (now != null && now != before) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Genau eine Bilddatei, keine Überbleibsel', () => filesSettle('avatars/spaces/Familie Berger', 1));
      await c.hideKeyboard();
      await c.snap();

      // ---------------------------------------------------------------- Alben anlegen
      c.step('Album anlegen: Abbrechen', 'Auf den Knopf Album tippen, dann Abbrechen.', 'Das Fenster schließt sich, es entsteht kein Album.',
          kind: 'Abzweigung', explain: 'Abbrechen legt nichts an.');
      await tapExact('Album');
      c.screen('Album anlegen');
      await c.waitFor('Anlegen', seconds: 3);
      await c.tap('Abbrechen', last: true);
      c.screen('Space');
      await c.check('Kein Album', () async => await rows('channels') == 0);
      await c.hideKeyboard();
      await c.snap();

      c.step('Erstes Album anlegen', 'Auf den Knopf Album tippen, Urlaub 2026 eingeben und Anlegen antippen.',
          'Unter 1 Album steht Urlaub 2026.',
          explain: 'Ein Album gehört immer zu einem Space. Fotos und Videos werden in Alben gesendet, und ein Frame zeigt Alben.');
      await tapExact('Album');
      c.screen('Album anlegen');
      await c.waitFor('Anlegen', seconds: 3);
      await c.typeInto('Name', 'Urlaub 2026');
      await c.tap('Anlegen', last: true);
      c.screen('Space');
      await c.check('Album in der Liste', () => c.waitFor('Urlaub 2026', seconds: 10));
      await c.check('Genau ein Album', () async => await rows('channels') == 1);
      await c.hideKeyboard();
      await c.snap();

      c.step('Zweites Album anlegen', 'Unter den Alben Album anlegen antippen, Geburtstage eingeben und Anlegen antippen (hier absichtlich zweimal schnell).',
          'Unter 2 Alben stehen Urlaub 2026 und Geburtstage.',
          explain: 'Derselbe Weg über die Zeile unter den Alben. Der doppelte Tipp darf kein zweites Album Geburtstage anlegen.');
      await c.tap('Album anlegen');
      c.screen('Album anlegen');
      await c.waitFor('Anlegen', seconds: 3);
      await c.typeInto('Name', 'Geburtstage');
      await c.tap('Anlegen', last: true, twice: true);
      c.screen('Space');
      await c.check('Zweites Album in der Liste', () => c.waitFor('Geburtstage', seconds: 10));
      await c.check('Genau zwei Alben', () async => await rows('channels') == 2);
      await c.hideKeyboard();
      await c.snap();

      // ---------------------------------------------------------------- Im Album
      c.step('Album öffnen', 'Urlaub 2026 antippen.',
          'Das leere Album: oben Urlaub 2026, in der Mitte Noch keine Fotos und Tippe auf +, um das erste Foto oder Video zu teilen. Rechts unten Kamera und +.',
          explain: 'Hier landen später Fotos und Videos (Kapitel 3).');
      await c.tap('Urlaub 2026');
      c.screen('Album (leer)');
      await c.check('Leeres Album', () => c.waitFor('Noch keine Fotos', seconds: 10));
      await c.snap();

      c.step('Infos zum Album', 'Oben auf den Namen des Albums tippen.',
          'Die Seite des Albums: Name mit Stift, Einladen und Mit Space teilen, die Personen (Anna) und unten Album löschen.',
          explain: 'Wie in WhatsApp: ein Tipp auf den Namen öffnet die Infos.');
      await c.tap('Infos zum Album');
      c.screen('Album-Infos');
      await c.check('Album-Infos', () => c.waitFor('Album löschen', seconds: 10));
      await c.snap();

      c.step('Album umbenennen', 'Auf den Stift tippen, Sommerurlaub 2026 eingeben und Speichern antippen.',
          'Oben steht jetzt Sommerurlaub 2026.',
          explain: 'Der neue Name erscheint sofort überall: im Album, auf der Space-Seite und auf der Startseite.');
      await c.tap('Album umbenennen');
      c.screen('Album umbenennen');
      await c.waitFor('Speichern', seconds: 3);
      await c.typeInto('Name', 'Sommerurlaub 2026');
      await c.tap('Speichern', last: true);
      c.screen('Album-Infos');
      await c.check('Neuer Name sichtbar', () => c.waitFor('Sommerurlaub 2026', seconds: 5));
      await c.check('Neuer Name gespeichert', () async {
        for (var i = 0; i < 20; i++) {
          if ((await albumNames()).contains('Sommerurlaub 2026')) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.hideKeyboard();
      await c.snap();

      c.step('Titelbild: Auswahl', 'Auf das Bild des Albums tippen.',
          'Unten öffnet sich Titelbild für Sommerurlaub 2026 mit Foto aus dem Album wählen, Foto aufnehmen, Vorhandenes Bild wählen und Von einer Internetadresse laden.',
          explain: 'Ohne eigenes Titelbild zeigt ein Album sein neuestes Foto. Man kann aber ein Foto aus dem Album oder ein anderes Bild festlegen.');
      await c.tap('Bild ändern');
      c.screen('Titelbild');
      await c.check('Vier Möglichkeiten', () async =>
          await c.waitFor('Foto aus dem Album', seconds: 3) && await c.waitFor('Von einer Internetadresse', seconds: 1));
      await c.snap();

      c.step('Titelbild-Auswahl: daneben tippen', 'Oben neben die Auswahl tippen.', 'Die Auswahl schließt sich.',
          kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt die Auswahl, nichts ändert sich.');
      await c.tapAt(const Offset(200, 100), 'Schließen');
      c.screen('Album-Infos');
      await c.check('Auswahl zu', () => c.gone('Titelbild für', seconds: 3));
      await c.snap();

      c.step('Titelbild aus dem leeren Album', 'Auf das Bild tippen, dann Foto aus dem Album wählen.',
          'Eine Auswahl der Fotos dieses Albums; weil es noch leer ist, steht dort, dass es noch keine Fotos gibt.',
          kind: 'Abzweigung', explain: 'Im leeren Album gibt es noch nichts zum Auswählen.');
      await c.tap('Bild ändern');
      c.screen('Titelbild');
      await c.tap('Foto aus dem Album');
      c.screen('Foto aus dem Album');
      await c.settle(max: const Duration(seconds: 3));
      await c.snap();

      c.step('Titelbild aus dem leeren Album: Zurück', 'Zurück.', 'Wieder die Album-Infos, ohne Titelbild.',
          kind: 'Abzweigung', explain: 'Nichts wurde geändert.');
      await c.back();
      c.screen('Album-Infos');
      await c.check('Kein Titelbild', () async => (await album('Sommerurlaub 2026'))['cover_path'] == null);
      await c.snap();

      c.step('Titelbild wählen', 'Auf das Bild tippen, Vorhandenes Bild wählen, dann Strand antippen.',
          'Der Strand steht sofort als Titelbild oben.',
          explain: 'Das Titelbild erscheint sofort und überall, wo das Album gezeigt wird.');
      await c.tap('Bild ändern');
      c.screen('Titelbild');
      await c.tap('Vorhandenes Bild');
      c.screen('Bildauswahl');
      await c.tap('Strand', seconds: 10);
      c.screen('Album-Infos');
      await c.gone('Testbilder', seconds: 10);
      await c.check('Titelbild gespeichert', () async {
        for (var i = 0; i < 40; i++) {
          if ((await album('Sommerurlaub 2026'))['cover_path'] != null) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Genau eine Bilddatei, keine Überbleibsel', () => filesSettle('avatars/channels/Sommerurlaub 2026', 1));
      await c.snap();

      c.step('Titelbild: automatisch', 'Auf das Bild tippen und Automatisch: neuestes Foto wählen.',
          'Das eigene Titelbild ist weg; weil das Album noch leer ist, steht dort wieder das Zeichen für ein Album.',
          kind: 'Abzweigung', explain: 'Automatisch heißt: das neueste Foto des Albums ist das Titelbild. Noch gibt es keins.');
      await c.tap('Bild ändern');
      c.screen('Titelbild');
      await c.tap('Automatisch', seconds: 3);
      c.screen('Album-Infos');
      await c.check('Strand sofort weg, Anfangsbuchstaben SO', () => c.waitFor('SO', seconds: 2));
      await c.check('Titelbild entfernt', () async {
        for (var i = 0; i < 20; i++) {
          if ((await album('Sommerurlaub 2026'))['cover_path'] == null) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Keine Bilddatei mehr', () => filesSettle('avatars/channels/Sommerurlaub 2026', 0));
      await c.snap();

      c.step('Titelbild aufnehmen', 'Auf das Bild tippen, Foto aufnehmen, dann Strand antippen.', 'Der Strand ist wieder das Titelbild.',
          explain: 'Normalerweise öffnet sich die Kamera. Die Test-App zeigt stattdessen ihre Testbilder.');
      await c.tap('Bild ändern');
      c.screen('Titelbild');
      await c.tap('Foto aufnehmen');
      c.screen('Bildauswahl');
      await c.tap('Strand', seconds: 10);
      c.screen('Album-Infos');
      await c.gone('Testbilder', seconds: 10);
      await c.check('Titelbild gespeichert', () async {
        for (var i = 0; i < 40; i++) {
          if ((await album('Sommerurlaub 2026'))['cover_path'] != null) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Genau eine Bilddatei, keine Überbleibsel', () => filesSettle('avatars/channels/Sommerurlaub 2026', 1));
      await c.snap();

      c.step('Titelbild von einer Internetadresse', 'Auf das Bild tippen, Von einer Internetadresse laden, die Adresse eines Bildes (Strand am Abend) eingeben und Laden antippen.',
          'Das Fenster lädt das Bild und schließt sich; das Titelbild ist jetzt der Strand am Abend.',
          explain: 'Derselbe Weg wie beim Bild des Space.');
      final coverBefore = (await album('Sommerurlaub 2026'))['cover_path'];
      await c.tap('Bild ändern');
      c.screen('Titelbild');
      await c.tap('Von einer Internetadresse');
      c.screen('Bild-URL');
      await c.typeInto('https://', beachUrl);
      await c.tap('Laden', last: true);
      c.screen('Album-Infos');
      await c.check('Fenster zu', () => c.gone('Bild-URL', seconds: 15));
      await c.check('Neues Titelbild gespeichert', () async {
        for (var i = 0; i < 40; i++) {
          final now = (await album('Sommerurlaub 2026'))['cover_path'];
          if (now != null && now != coverBefore) return true;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        return false;
      });
      await c.check('Genau eine Bilddatei, keine Überbleibsel', () => filesSettle('avatars/channels/Sommerurlaub 2026', 1));
      await c.hideKeyboard();
      await c.snap();

      c.step('Zurück ins Album', 'Zurück.', 'Wieder das leere Album, oben jetzt Sommerurlaub 2026 mit dem Strand.',
          explain: 'Name und Titelbild sind auch hier schon neu.');
      await c.back();
      c.screen('Album (leer)');
      await c.check('Neuer Name im Album', () => c.waitFor('Sommerurlaub 2026', seconds: 5));
      await c.snap();

      c.step('Zurück zum Space', 'Zurück.', 'Die Space-Seite: unter 2 Alben stehen Geburtstage und Sommerurlaub 2026 mit dem Strand.',
          explain: 'Auch hier gleich der neue Name und das Titelbild.');
      await c.back();
      c.screen('Space');
      await c.check('Neuer Name auf der Space-Seite', () => c.waitFor('Sommerurlaub 2026', seconds: 5));
      await c.snap();

      c.step('Zurück zur Startseite', 'Zurück.',
          'Die Startseite zeigt jetzt die Alben: Geburtstage und Sommerurlaub 2026, jeweils mit Noch keine Fotos.',
          explain: 'Sobald es Alben gibt, ist die Startseite die Liste der Alben, die neuesten oben (wie die Chats in WhatsApp).');
      await c.back();
      c.screen('Startseite');
      await c.check('Alben auf der Startseite', () async =>
          await c.waitFor('Sommerurlaub 2026', seconds: 10) && await c.waitFor('Geburtstage', seconds: 2));
      await c.snap();

      // ---------------------------------------------------------------- Neues Album über das Menü
      c.step('Menü der Startseite', 'Oben rechts auf die drei Punkte tippen.', 'Das Menü zeigt Neues Album, Code scannen und Einstellungen.',
          kind: 'Abzweigung', explain: 'Wer einen Space verwaltet, kann auch von der Startseite aus ein Album anlegen.');
      await c.tap('Weitere Optionen');
      c.screen('Menü');
      await c.check('Neues Album im Menü', () => c.waitFor('Neues Album', seconds: 3));
      await c.snap();

      c.step('Neues Album über das Menü', 'Neues Album antippen, Weihnachten eingeben und Anlegen antippen.',
          'Das Fenster zeigt unter dem Titel in Familie Berger. Nach Anlegen öffnet sich gleich das neue, leere Album Weihnachten.',
          explain: 'Mit nur einem Space fragt Smile nicht, wohin; es sagt es im Fenster. Das neue Album öffnet sich sofort, damit man gleich Fotos senden kann.');
      await c.tap('Neues Album');
      c.screen('Neues Album');
      await c.check('In Familie Berger', () => c.waitFor('in Familie Berger', seconds: 3));
      await c.typeInto('Name', 'Weihnachten');
      await c.tap('Anlegen', last: true);
      c.screen('Album (leer)');
      await c.check('Neues Album offen', () async =>
          await c.waitFor('Noch keine Fotos', seconds: 10) && await c.waitFor('Weihnachten', seconds: 2));
      await c.check('Drei Alben', () async => await rows('channels') == 3);
      await c.hideKeyboard();
      await c.snap();

      c.step('Zurück zur Startseite mit drei Alben', 'Zurück.', 'Die Startseite zeigt drei Alben, Weihnachten ganz oben.',
          explain: 'Das neueste Album steht oben.');
      await c.back();
      c.screen('Startseite');
      await c.check('Weihnachten auf der Startseite', () => c.waitFor('Weihnachten', seconds: 10));
      await c.snap();

      c.step('Album von der Startseite öffnen', 'Geburtstage antippen.', 'Das leere Album Geburtstage öffnet sich.',
          explain: 'Der übliche Weg in ein Album: von der Startseite.');
      await c.tap('Geburtstage');
      c.screen('Album (leer)');
      await c.check('Album Geburtstage offen', () async =>
          await c.waitFor('Noch keine Fotos', seconds: 10) && await c.waitFor('Geburtstage', seconds: 2));
      await c.snap();

      c.step('Zurück zur Startseite von Geburtstage', 'Zurück.', 'Wieder die Startseite mit den drei Alben.',
          explain: 'Nichts hat sich verändert.');
      await c.back();
      c.screen('Startseite');
      await c.check('Startseite', () => c.waitFor('Weihnachten', seconds: 5));
      await c.snap();

      // ---------------------------------------------------------------- Spaces
      c.step('Spaces', 'Unten auf Spaces tippen.',
          'Die Liste der Spaces: Familie Berger mit dem Haus, darunter Admin und 3 Alben · 0 Frames.',
          explain: 'Hier stehen alle Spaces, die man verwaltet. Ein Tipp öffnet die Space-Seite.');
      await tapExact('Spaces');
      c.screen('Spaces');
      await c.check('Familie Berger in der Liste', () => c.waitFor('Familie Berger', seconds: 10));
      await c.check('3 Alben', () => c.waitFor('~3 Alben', seconds: 5));
      await c.snap();

      c.step('Space aus der Liste öffnen', 'Familie Berger antippen.', 'Die Space-Seite mit drei Alben.',
          explain: 'Dieselbe Seite wie direkt nach dem Anlegen.');
      await c.tap('Familie Berger');
      c.screen('Space');
      await c.check('Seite des Space', () async =>
          await c.waitFor('Du bist Admin', seconds: 10) && await c.waitFor('~3 Alben', seconds: 3));
      await c.snap();

      c.step('Zurück zu den Spaces', 'Zurück, dann noch einmal unten auf Spaces tippen.', 'Wieder die Liste der Spaces; der zweite Tipp ändert nichts.',
          explain: 'Ein Tipp auf den Tab, auf dem man schon ist, bleibt einfach dort.');
      await c.back();
      c.screen('Spaces');
      await tapExact('Spaces');
      await c.check('Liste der Spaces', () => c.waitFor('Familie Berger', seconds: 5));
      await c.snap();

      c.step('Zurück zu den Alben', 'Unten auf Alben tippen, dann noch einmal auf Alben.', 'Wieder die Startseite mit den drei Alben.',
          explain: 'Fertig: Space und drei Alben stehen.');
      await tapExact('Alben');
      c.screen('Startseite');
      await tapExact('Alben');
      await c.check('Startseite mit Alben', () async =>
          await c.waitFor('Weihnachten', seconds: 5) && await c.waitFor('Sommerurlaub 2026', seconds: 2));
      await c.snap();

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
