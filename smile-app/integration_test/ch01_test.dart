// Kapitel 1: Erster Start (tools/testsuite). Anna Berger meldet sich zum
// ersten Mal an, wählt Namen, Profilbild und Smile-Namen, öffnet ihre Karte;
// jede Abzweigung auf diesen Seiten wird mit durchgespielt und, wo sie etwas
// ändert, wieder zurückgenommen. Läuft in der Test-App: tools/testsuite/run.sh ch01.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_app/main.dart' as app;
import 'package:smile_design_system/smile_design_system.dart';

import 'support/backend.dart';
import 'support/chapter.dart';

const anna = 'anna.berger@example.com';

/// Android's share sheet is not Smile: in the test, what Smile hands to it is caught.
class _CaughtShare extends SharePlatform {
  String? text;
  @override
  Future<ShareResult> share(ShareParams params) async {
    text = params.text;
    return const ShareResult('test', ShareResultStatus.success);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 1: Erster Start', (tester) async {
    // ---------------------------------------------------------------- Startzustand
    await TestBackend.reset();
    await TestBackend.person('paul.berger@example.com', 'Paul Berger', handle: 'paul.berger');
    final fixtures = '${(await getApplicationSupportDirectory()).path}/fixtures/profiles';
    final portraitUrl =
        await TestBackend.putPublic('testsuite/frau_alt.png', await File('$fixtures/frau_alt.png').readAsBytes(), 'image/png');
    final textUrl = await TestBackend.putPublic('testsuite/notiz.txt', utf8.encode('Das ist kein Bild.'), 'text/plain');
    final missingUrl = '${TestBackend.url}/storage/v1/object/public/avatars/testsuite/fehlt.png';
    final frauMittelSize = await File('$fixtures/frau_mittel.png').length();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('tips_enabled', false); // Tipps haben ein eigenes Kapitel.
    final share = _CaughtShare();
    SharePlatform.instance = share;
    final semantics = tester.ensureSemantics();

    Future<Map> profile() async {
      final id = await TestBackend.userId(anna);
      final rows = await TestBackend.select('profiles', 'select=display_name,handle,avatar_path&user_id=eq.$id');
      return rows.isEmpty ? {} : rows.first as Map;
    }

    Future<int> files() async => ((await TestBackend.state())['files'] as Map)['avatars/$anna'] as int? ?? 0;
    Future<int> rows(String table) async => ((await TestBackend.state())['rows'] as Map)[table] as int;

    final c = Chapter(tester, binding,
        id: 'ch01',
        title: 'Erster Start',
        intro: 'Anna installiert Smile, meldet sich mit ihrer E-Mail-Adresse an, gibt sich einen Namen und ein Profilbild, '
            'wählt ihren Smile-Namen und öffnet ihre Karte. Jede Abzweigung auf diesen Seiten wird mitgeprüft: falscher Code, '
            'andere Adresse, leerer Name, alle Wege zum Profilbild, Namen ändern, Smile-Namen entfernen, Videos senden, '
            'Abmelden, und was passiert, wenn man dasselbe zweimal tut.');

    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');
    unawaited(app.main());
    try {
    await c.start();
    final circle = find.byType(SmileAvatar);
    Future<void> openCircle() async {
      await c.hideKeyboard();
      c.logTap('Profilbild-Kreis');
      await tester.tap(circle.first);
      await c.settle();
      await c.waitFor('Vorhandenes Bild');
    }

    // ---------------------------------------------------------------- Anmeldung
    c.step('Smile öffnen', 'Smile zum ersten Mal öffnen.',
        'Die Anmeldung erscheint: Smile-Logo, Feld für die E-Mail-Adresse, Code anfordern und Dieses Gerät als Frame verwenden.',
        explain: 'Smile startet ohne Anmeldung. Weil noch niemand angemeldet ist, zeigt die App die Anmeldung. Gespeichert ist auf dem Handy noch nichts.');
    c.screen('Anmeldung');
    await c.check('Anmeldung sichtbar', () => c.waitFor('Code anfordern', seconds: 20));
    await c.snap();

    c.step('Code anfordern ohne Adresse', 'Code anfordern antippen, ohne etwas einzugeben.',
        'Unter dem Feld steht: Bitte gib deine E-Mail-Adresse ein.',
        kind: 'Abzweigung',
        explain: 'Die App prüft das Feld, bevor sie den Server fragt. Ist es leer, wird gar nichts verschickt, nur der Hinweis erscheint.');
    await c.tap('Code anfordern');
    await c.check('Meldung Bitte gib deine E-Mail-Adresse ein', () => c.waitFor('Bitte gib deine E-Mail-Adresse ein', seconds: 3));
    await c.check('Noch auf der Anmeldung', () => c.waitFor('Melde dich mit deiner E-Mail-Adresse an', seconds: 2));
    await c.snap();

    c.step('Falsch geschriebene Adresse', 'anna.berger@ eingeben und Code anfordern antippen.',
        'Unter dem Feld steht: Das ist keine gültige E-Mail-Adresse. Bitte prüfe sie.',
        kind: 'Abzweigung',
        explain: 'Die App prüft die Schreibweise (etwas@etwas.endung). Eine unvollständige Adresse wird gemeldet, bevor eine Mail verschickt wird. Ob ein Postfach wirklich existiert, kann nur die Mail selbst zeigen.');
    await c.typeInto('E-Mail-Adresse', 'anna.berger@');
    await c.tap('Code anfordern');
    await c.check('Meldung keine gültige E-Mail-Adresse', () => c.waitFor('~keine gültige E-Mail-Adresse', seconds: 3));
    await c.hideKeyboard();
    await c.snap();

    c.step('E-Mail-Adresse eingeben', 'Die Adresse zu anna.berger@example.com vervollständigen.',
        'Die Adresse steht im Feld, die Meldung ist verschwunden.',
        explain: 'Beim Weitertippen verschwindet der Hinweis von selbst. Noch ist nichts verschickt.');
    await c.typeInto('E-Mail-Adresse', anna);
    await c.check('Meldung verschwunden', () => c.gone('~keine gültige E-Mail-Adresse', seconds: 3));
    await c.hideKeyboard();
    await c.snap();

    c.step('Code anfordern', 'Auf Code anfordern tippen (hier absichtlich zweimal schnell).',
        'Smile meldet, dass ein Code an die Adresse gesendet wurde, und zeigt sechs Kästchen für den Code.',
        explain: 'Der Server erzeugt einen 6-stelligen Code und schickt ihn per Mail. Gibt es zu der Adresse noch kein Konto, wird es dabei angelegt. (Die Test-App verschickt keine Mail, den Code liefert die Testsuite.)');
    await c.tap('Code anfordern', twice: true);
    c.screen('Code-Eingabe');
    await c.check('Code-Eingabe sichtbar', () => c.waitFor('Wir haben einen Code', seconds: 10));
    await c.hideKeyboard();
    await c.snap();

    c.step('Code-Eingabe mit offener Tastatur', 'Die Tastatur offen lassen.',
        'Die Seite rückt nach oben: Code-Kästchen, Bestätigen und Andere E-Mail-Adresse verwenden bleiben über der Tastatur sichtbar, das große S ist ausgeblendet.',
        kind: 'Abzweigung',
        explain: 'Die Tastatur nimmt fast die halbe Höhe ein. Damit man ohne Wegwischen weiterkommt, bleibt der untere Teil sichtbar und das Logo wandert hinaus. (Die Testsuite legt eine Tastatur über 40 % des Bildschirms; auf dem Bild ist sie als leerer Bereich unten zu sehen.)');
    final screenH = tester.view.physicalSize.height;
    tester.view.viewInsets = FakeViewPadding(bottom: screenH * 0.4);
    await c.settle();
    final keyboardTop = (screenH * 0.6) / tester.view.devicePixelRatio;
    bool aboveKeyboard(String what) => c.find_(what).evaluate().isNotEmpty && tester.getRect(c.find_(what).first).bottom <= keyboardTop;
    await c.check('Bestätigen über der Tastatur', () => aboveKeyboard('Bestätigen'));
    await c.check('Andere E-Mail-Adresse über der Tastatur', () => aboveKeyboard('Andere E-Mail-Adresse'));
    await c.check('Großes S ausgeblendet', () => find.byType(SmileMark).evaluate().isEmpty);
    await c.snap();
    tester.view.resetViewInsets();
    await c.settle();

    c.step('Andere E-Mail-Adresse verwenden', 'Andere E-Mail-Adresse verwenden antippen.',
        'Zurück auf der Anmeldung, die Adresse steht noch im Feld und kann geändert werden.',
        kind: 'Abzweigung', explain: 'Zurück zur Adresse, falls man sich vertippt hat. Der schon verschickte Code verfällt einfach.');
    await c.tap('Andere E-Mail-Adresse');
    c.screen('Anmeldung');
    await c.check('Adresse noch im Feld', () => c.waitFor(anna, seconds: 3));
    await c.hideKeyboard();
    await c.snap();

    c.step('Code noch einmal anfordern', 'Code anfordern antippen.', 'Wieder die Code-Eingabe mit sechs Kästchen.',
        explain: 'Ein neuer Code wird erzeugt; der vorige gilt nicht mehr.');
    await c.tap('Code anfordern');
    c.screen('Code-Eingabe');
    await c.waitFor('Bestätigen');
    await c.hideKeyboard();
    await c.snap();

    c.step('Falscher Code', '000000 eingeben.', 'Eine Meldung erscheint: Der Code stimmt nicht oder ist abgelaufen.',
        kind: 'Abzweigung',
        explain: 'Nach der sechsten Ziffer prüft der Server den Code sofort. Er passt nicht, also bleibt man auf dieser Seite und sieht den Grund direkt unter den Kästchen.');
    await c.typeInto('', '000000', logAs: 'Code-Kästchen');
    await c.check('Meldung Code stimmt nicht sichtbar', () => c.waitFor('Der Code stimmt nicht', seconds: 8));
    await c.snap();

    c.step('Bestätigen antippen', 'Mit dem falschen Code noch einmal Bestätigen antippen.',
        'Wieder die Meldung: Der Code stimmt nicht oder ist abgelaufen.',
        kind: 'Abzweigung', explain: 'Bestätigen schickt denselben Code noch einmal zur Prüfung; das Ergebnis ist gleich.');
    await c.hideKeyboard();
    await c.tap('Bestätigen');
    await c.check('Meldung Code stimmt nicht sichtbar', () => c.waitFor('Der Code stimmt nicht', seconds: 8));
    await c.snap();

    c.step('Code eingeben', 'Die Kästchen leeren und den richtigen 6-stelligen Code aus der E-Mail eingeben.',
        'Smile fragt: Wie sollen wir dich nennen? Darunter ein Kreis mit Fragezeichen und das Namensfeld.',
        explain: 'Der richtige Code meldet Anna an. Weil es noch kein Profil gibt, fragt Smile zuerst nach dem Namen.');
    await c.typeInto('', await TestBackend.otp(anna), logAs: 'Code-Kästchen');
    c.screen('Begrüßung');
    await c.check('Begrüßung sichtbar', () => c.waitFor('Wie sollen wir dich nennen', seconds: 20));
    await c.hideKeyboard();
    await c.snap();

    // ---------------------------------------------------------------- Begrüßung
    c.step('Weiter ohne Namen', 'Gleich Weiter antippen, ohne einen Namen einzugeben.',
        'Eine Meldung erscheint: Bitte gib deinen Namen ein.',
        kind: 'Abzweigung', explain: 'Ohne Namen wird nichts gespeichert. Der Hinweis steht unter dem Feld.');
    await c.tap('Weiter');
    await c.check('Meldung Bitte gib deinen Namen ein', () => c.waitFor('Bitte gib deinen Namen ein', seconds: 3));
    await c.hideKeyboard();
    await c.snap();

    c.step('Namen eingeben', 'Anna Berger ins Namensfeld schreiben.',
        'Im Kreis erscheinen sofort die Anfangsbuchstaben AB, die Meldung von vorhin ist weg.',
        explain: 'Aus dem Namen entstehen sofort die Anfangsbuchstaben im Kreis. Gespeichert wird erst mit Weiter.');
    await c.typeInto('Name', 'Anna Berger');
    await c.check('Anfangsbuchstaben AB', () => c.waitFor('AB', seconds: 3));
    await c.check('Meldung ist beim Tippen verschwunden', () => c.gone('Bitte gib deinen Namen ein', seconds: 3));
    await c.hideKeyboard();
    await c.snap();

    c.step('Profilbild: Auswahl', 'Auf den Kreis mit dem Kamera-Symbol tippen.',
        'Drei Möglichkeiten: Foto aufnehmen, Vorhandenes Bild wählen, Von einer Internetadresse laden.',
        explain: 'Drei Wege zum Profilbild: Kamera, ein Bild vom Handy oder eines aus dem Internet.');
    await openCircle();
    c.screen('Profilbild-Auswahl');
    await c.check('Drei Möglichkeiten', () async => await c.waitFor('Foto aufnehmen', seconds: 1) && await c.waitFor('Von einer Internetadresse', seconds: 1));
    await c.snap();

    c.step('Foto aufnehmen', 'Foto aufnehmen antippen und ein Bild machen. (In der Test-App: statt der Kamera die Symbolbilder, hier Frau, jung.)',
        'Das Bild erscheint im Kreis.',
        kind: 'Abzweigung',
        explain: 'Das Bild wird hochgeladen und erscheint im Kreis. Ins Profil eingetragen wird es erst mit Weiter, weil das Profil noch nicht existiert.');
    await c.tap('Foto aufnehmen');
    c.screen('Bildauswahl');
    await c.tap('Frau, jung', seconds: 20);
    c.screen('Begrüßung');
    await c.gone('Testporträts', seconds: 10);
    await c.check('Zurück auf der Begrüßung', () => c.waitFor('Wie sollen wir dich nennen', seconds: 5));
    // Within a second, straight from the phone: no initials in between.
    await c.check('Bild sofort im Kreis (Frau, jung: türkis)', () => c.colorIn('SmileAvatar', '#8ec5c0', seconds: 1));
    await c.hideKeyboard();
    await c.snap();

    Future<void> openUrlDialog() async {
      await openCircle();
      c.screen('Profilbild-Auswahl');
      await c.tap('Von einer Internetadresse');
      c.screen('Bild-URL');
      await c.waitFor('Laden', seconds: 5);
    }

    c.step('Internetadresse: ungültig', 'Kreis antippen, Von einer Internetadresse laden, abc eingeben und Laden antippen.',
        'Der Dialog bleibt offen, unter dem Feld steht: Das ist keine gültige Internetadresse. abc steht noch im Feld.',
        kind: 'Abzweigung', explain: 'Die App erkennt, dass abc keine Internetadresse ist. Der Dialog bleibt offen, damit man korrigieren kann.');
    await openUrlDialog();
    await c.typeInto('https://', 'abc');
    await c.tap('Laden', last: true);
    await c.check('Meldung im Dialog', () => c.waitFor('~keine gültige Internetadresse', seconds: 5));
    await c.check('Dialog noch offen', () => c.waitFor('Abbrechen', seconds: 2));
    await c.snap();

    c.step('Internetadresse: Datei vom Gerät', 'Die Eingabe durch file:///sdcard/bild.jpg ersetzen und Laden antippen.',
        'Unter dem Feld steht: Das ist keine gültige Internetadresse. Dateien vom Gerät gehen hier nicht.',
        kind: 'Abzweigung', explain: 'file:// zeigt auf eine Datei im Handy, nicht ins Internet. Dafür gibt es Vorhandenes Bild wählen; hier wird es abgelehnt.');
    await c.typeInto('https://', 'file:///sdcard/bild.jpg');
    await c.tap('Laden', last: true);
    await c.check('Meldung im Dialog', () => c.waitFor('~keine gültige Internetadresse', seconds: 5));
    await c.snap();

    c.step('Internetadresse: kein Bild', 'Eine Adresse eingeben, unter der eine Textdatei liegt, und Laden antippen.',
        'Unter dem Feld steht: Die Adresse zeigt auf kein Bild.',
        kind: 'Abzweigung', explain: 'Die App lädt die Adresse, merkt aber, dass dort Text liegt statt eines Bildes.');
    await c.typeInto('https://', textUrl);
    await c.tap('Laden', last: true);
    await c.check('Meldung kein Bild', () => c.waitFor('~zeigt auf kein Bild', seconds: 10));
    await c.snap();

    c.step('Internetadresse: nichts da', 'Eine Adresse eingeben, unter der nichts liegt, und Laden antippen.',
        'Unter dem Feld steht: Das Bild konnte nicht geladen werden. Bitte prüfe die Adresse.',
        kind: 'Abzweigung', explain: 'Unter der Adresse liegt nichts. Die App meldet das, statt still zu scheitern.');
    await c.typeInto('https://', missingUrl);
    await c.tap('Laden', last: true);
    await c.check('Meldung konnte nicht geladen werden', () => c.waitFor('~konnte nicht geladen werden', seconds: 10));
    await c.snap();

    c.step('Internetadresse: Abbrechen', 'Abbrechen antippen.', 'Der Dialog schließt sich, das Bild bleibt wie es war.',
        kind: 'Abzweigung', explain: 'Der Dialog geht zu, nichts wird geladen oder geändert.');
    await c.tap('Abbrechen');
    c.screen('Begrüßung');
    await c.check('Dialog geschlossen', () => c.gone('Bild-URL', seconds: 3));
    await c.snap();

    c.step('Internetadresse: daneben tippen', 'Noch einmal Von einer Internetadresse laden wählen und oben neben den Dialog tippen.',
        'Der Dialog schließt sich, das Bild bleibt wie es war.',
        kind: 'Abzweigung', explain: 'Ein Tipp neben den Dialog wirkt wie Abbrechen.');
    await openUrlDialog();
    await c.tapAt(const Offset(200, 90), 'Schließen');
    c.screen('Begrüßung');
    await c.check('Dialog geschlossen', () => c.gone('Bild-URL', seconds: 3));
    await c.snap();

    c.step('Internetadresse: Bild laden', 'Von einer Internetadresse laden wählen, die Adresse eines Bildes eingeben und Laden antippen.',
        'Der Dialog zeigt kurz, dass geladen wird, und schließt sich. Das Bild von der Adresse steht im Kreis (hier Frau, älter).',
        kind: 'Abzweigung',
        explain: 'Die App lädt das Bild im Dialog herunter und prüft es. Erst wenn es wirklich ein Bild ist, schließt sich der Dialog und das Bild wird hochgeladen. Das zuvor gewählte Bild wird gleich wieder gelöscht, damit nichts übrig bleibt.');
    await openUrlDialog();
    await c.typeInto('https://', portraitUrl);
    await c.tap('Laden', last: true);
    c.screen('Begrüßung');
    await c.check('Dialog geschlossen', () => c.gone('Bild-URL', seconds: 15));
    await c.hideKeyboard();
    await c.look();
    await c.check('Bild im Kreis (Frau, älter: gelb)', () => c.colorIn('SmileAvatar', '#f1c98b'));
    await c.snap();

    c.step('Bildauswahl abbrechen', 'Kreis antippen, Vorhandenes Bild wählen und in der Bildauswahl Zurück antippen, ohne ein Bild zu wählen.',
        'Wieder die Begrüßung, das Bild bleibt wie es war.',
        kind: 'Abzweigung', explain: 'Wer die Auswahl ohne Bild verlässt, ändert nichts.');
    await openCircle();
    c.screen('Profilbild-Auswahl');
    await c.tap('Vorhandenes Bild');
    c.screen('Bildauswahl');
    await c.waitFor('Mann, älter', seconds: 20);
    await c.back();
    c.screen('Begrüßung');
    await c.check('Zurück auf der Begrüßung', () => c.waitFor('Wie sollen wir dich nennen', seconds: 5));
    await c.snap();

    c.step('Profilbild-Auswahl: daneben tippen', 'Kreis antippen und oben neben die Auswahl tippen.', 'Die Auswahl schließt sich.',
        kind: 'Abzweigung', explain: 'Ein Tipp neben die Auswahl schließt sie, so wie Abbrechen; nichts ändert sich.');
    await openCircle();
    c.screen('Profilbild-Auswahl');
    await c.tapAt(const Offset(200, 100), 'Schließen');
    c.screen('Begrüßung');
    await c.check('Auswahl geschlossen', () => c.gone('Foto aufnehmen', seconds: 3));
    await c.snap();

    c.step('Profilbild-Auswahl wegwischen', 'Kreis antippen und die Auswahl nach unten wegwischen.', 'Die Auswahl schließt sich.',
        kind: 'Abzweigung', explain: 'Die Auswahl lässt sich auch nach unten wegwischen; nichts ändert sich.');
    await openCircle();
    c.screen('Profilbild-Auswahl');
    await tester.fling(c.find_('Foto aufnehmen').first, const Offset(0, 500), 1500);
    await c.settle();
    c.screen('Begrüßung');
    await c.check('Auswahl geschlossen', () => c.gone('Foto aufnehmen', seconds: 3));
    await c.snap();

    c.step('Vorhandenes Bild wählen', 'Kreis antippen und Vorhandenes Bild wählen.',
        'Die Bildauswahl öffnet sich. (In der Test-App: sechs Symbolbilder statt der Galerie.)',
        explain: 'Normalerweise öffnet sich die Galerie des Handys. Die Test-App zeigt stattdessen ihre gezeichneten Testbilder.');
    await openCircle();
    c.screen('Profilbild-Auswahl');
    await c.tap('Vorhandenes Bild');
    c.screen('Bildauswahl');
    await c.waitFor('Mann, älter', seconds: 20);
    await c.snap();

    c.step('Bild aussuchen', 'Das Bild Frau, mittleres Alter antippen.', 'Das Bild erscheint im Kreis über dem Namen.',
        explain: 'Das gewählte Bild wird hochgeladen und ersetzt das vorige.');
    await c.tap('Frau, mittleres Alter');
    c.screen('Begrüßung');
    await c.gone('Testporträts', seconds: 10);
    await c.check('Bild sofort im Kreis, ohne Anfangsbuchstaben dazwischen (Frau, mittleres Alter: lila)',
        () => c.colorIn('SmileAvatar', '#c9b6e4', seconds: 1));
    await c.hideKeyboard();
    await c.snap();

    c.step('Dasselbe Bild noch einmal', 'Kreis antippen, Vorhandenes Bild wählen und noch einmal Frau, mittleres Alter antippen.',
        'Nichts ändert sich sichtbar, das Bild bleibt im Kreis.',
        kind: 'Abzweigung',
        explain: 'Nachsalzen: dasselbe Bild ein zweites Mal. Es wird zwar erneut hochgeladen, aber die vorige Datei gleich gelöscht; nach Weiter darf es genau eine Bilddatei geben.');
    await openCircle();
    c.screen('Profilbild-Auswahl');
    await c.tap('Vorhandenes Bild');
    c.screen('Bildauswahl');
    await c.tap('Frau, mittleres Alter', seconds: 20);
    c.screen('Begrüßung');
    await c.gone('Testporträts', seconds: 10);
    await c.hideKeyboard();
    await c.look();
    await c.check('Bild im Kreis (Frau, mittleres Alter: lila)', () => c.colorIn('SmileAvatar', '#c9b6e4'));
    await c.snap();

    c.step('Weiter', 'Auf Weiter tippen (hier absichtlich zweimal schnell hintereinander).',
        'Willkommen bei Smile: die leere Alben-Liste mit zwei Wegen, Ich wurde eingeladen und Ich richte Smile ein.',
        explain: 'Jetzt entsteht Annas Profil: Name und Bild werden zusammen gespeichert. Der doppelte Tipp darf nichts doppelt anlegen. Die Testsuite prüft in der Datenbank, dass es genau zwei Profile gibt (Anna und Paul), genau dieses Bild gespeichert ist und keine alten Bilddateien übrig sind.');
    await c.tap('Weiter', twice: true);
    c.screen('Startseite (leer)');
    await c.waitFor('Willkommen bei Smile', seconds: 20);
    await c.check('Genau zwei Profile (Anna und Paul), nichts doppelt', () async => await rows('profiles') == 2);
    await c.check('Name gespeichert: Anna Berger', () async => (await profile())['display_name'] == 'Anna Berger');
    await c.check('Profilbild gespeichert: Frau, mittleres Alter',
        () async => await TestBackend.avatarSize((await profile())['avatar_path'] as String) == frauMittelSize);
    await c.check('Nur eine Profilbild-Datei, keine Überbleibsel', () async => await files() == 1);
    await c.check('Kein Hinweis nur auf die E-Mail-Adresse', () => c.gone('~Eingeladen wirst du', seconds: 1));
    await c.snap();

    // ---------------------------------------------------------------- Menü
    c.step('Menü öffnen', 'Oben rechts auf die drei Punkte tippen.', 'Das Menü zeigt Code scannen und Einstellungen.',
        explain: 'Das Menü oben rechts gibt es auf jeder Hauptseite.');
    await c.tap('Weitere Optionen');
    c.screen('Menü');
    await c.waitFor('Einstellungen', seconds: 5);
    await c.snap();

    c.step('Menü schließen', 'Neben das Menü tippen.', 'Das Menü schließt sich.',
        kind: 'Abzweigung', explain: 'Ein Tipp daneben schließt das Menü ohne Aktion.');
    await c.tapAt(const Offset(100, 500), 'Menü schließen');
    c.screen('Startseite (leer)');
    await c.check('Menü zu', () => c.gone('Code scannen', seconds: 3));
    await c.snap();

    c.step('Einstellungen', 'Drei Punkte, dann Einstellungen antippen.',
        'Oben Annas Profilbild und ihr Name, darunter Smile-Name, Meine Karte, Videos senden, Tipps und Konto.',
        explain: 'Die Einstellungen laden Annas Profil vom Server. Die Testsuite prüft am Bildschirm, dass das zuletzt gewählte Bild zu sehen ist und kein altes.');
    await c.tap('Weitere Optionen');
    c.screen('Menü');
    await c.tap('Einstellungen');
    c.screen('Einstellungen');
    await c.waitFor('Smile-Namen wählen', seconds: 10);
    await tester.pump(const Duration(seconds: 2));
    await c.look();
    await c.check('Oben das zuletzt gewählte Bild (Frau, mittleres Alter, lila)', () => c.colorIn('SmileAvatar', '#c9b6e4'));
    await c.snap();

    // ---------------------------------------------------------------- Einstellungen: Profil
    c.step('Profilbild ansehen', 'Auf Annas Profilbild tippen.', 'Das Bild erscheint groß.',
        kind: 'Abzweigung', explain: 'Das Bild wird groß angezeigt, nur zum Ansehen.');
    await c.tap('Profilbild ansehen');
    c.screen('Profilbild groß');
    await c.snap();

    c.step('Profilbild schließen', 'Schließen antippen.', 'Wieder die Einstellungen.', kind: 'Abzweigung', explain: 'Zurück zu den Einstellungen.');
    await c.tap('Schließen');
    c.screen('Einstellungen');
    await c.waitFor('Smile-Namen wählen', seconds: 5);
    await c.snap();

    c.step('Profilbild ändern: abbrechen', 'Auf das Kamera-Symbol am Bild tippen und dann oben neben die Auswahl tippen.',
        'Die Auswahl schließt sich, das Bild bleibt.',
        kind: 'Abzweigung', explain: 'Die Auswahl für ein neues Bild öffnet sich und wird ohne Änderung geschlossen.');
    await c.tap('Profilbild ändern');
    c.screen('Profilbild-Auswahl');
    await c.waitFor('Vorhandenes Bild', seconds: 5);
    await c.tapAt(const Offset(200, 150), 'Gitter');
    c.screen('Einstellungen');
    await c.check('Auswahl geschlossen', () => c.gone('Foto aufnehmen', seconds: 3));
    await c.snap();

    c.step('Name ändern: abbrechen', 'Auf den Namen tippen und im Dialog Abbrechen wählen.', 'Der Dialog schließt sich, der Name bleibt Anna Berger.',
        kind: 'Abzweigung', explain: 'Der Dialog zum Umbenennen wird ohne Änderung geschlossen; die Testsuite prüft, dass der Name gleich bleibt.');
    await c.tap('Anna Berger');
    c.screen('Name ändern');
    await c.waitFor('Speichern', seconds: 5);
    await c.tap('Abbrechen');
    c.screen('Einstellungen');
    await c.check('Name unverändert', () async => (await profile())['display_name'] == 'Anna Berger');
    await c.snap();

    c.step('Name ändern', 'Auf den Namen tippen, Anna Maria Berger eingeben und Speichern antippen.', 'Oben steht jetzt Anna Maria Berger.',
        kind: 'Abzweigung', explain: 'Der neue Name wird sofort gespeichert und erscheint überall, wo Anna vorkommt.');
    await c.tap('Anna Berger');
    c.screen('Name ändern');
    await c.waitFor('Speichern', seconds: 5);
    await c.typeInto('Name', 'Anna Maria Berger');
    await c.tap('Speichern', last: true);
    c.screen('Einstellungen');
    await c.waitFor('Anna Maria Berger', seconds: 5);
    await c.check('Name geändert', () async => (await profile())['display_name'] == 'Anna Maria Berger');
    await c.snap();

    c.step('Name zurück ändern', 'Noch einmal auf den Namen tippen, Anna Berger eingeben, Speichern.', 'Oben steht wieder Anna Berger.',
        kind: 'Abzweigung', explain: 'Die Änderung wird zurückgenommen, damit die folgenden Schritte wieder vom gleichen Stand ausgehen.');
    await c.tap('Anna Maria Berger');
    c.screen('Name ändern');
    await c.waitFor('Speichern', seconds: 5);
    await c.typeInto('Name', 'Anna Berger');
    await c.tap('Speichern', last: true);
    c.screen('Einstellungen');
    await c.check('Name wieder Anna Berger', () async => (await profile())['display_name'] == 'Anna Berger');
    await c.snap();

    c.step('Namen unverändert speichern', 'Noch einmal auf den Namen tippen und ohne Änderung Speichern antippen.',
        'Oben steht weiter Anna Berger, nichts ändert sich.',
        kind: 'Abzweigung', explain: 'Nachsalzen: derselbe Name noch einmal. Es darf nichts doppelt oder kaputt gehen.');
    await c.tap('Anna Berger');
    c.screen('Name ändern');
    await c.waitFor('Speichern', seconds: 5);
    await c.tap('Speichern', last: true);
    c.screen('Einstellungen');
    await c.check('Name weiter Anna Berger', () async => (await profile())['display_name'] == 'Anna Berger');
    await c.check('Weiter genau zwei Profile', () async => await rows('profiles') == 2);
    await c.snap();

    // ---------------------------------------------------------------- Smile-Name
    c.step('Smile-Namen wählen', 'Smile-Namen wählen antippen.',
        'Ein Vorschlag aus dem Namen steht schon da: @anna.berger. Das Feld hat einen grünen Rahmen und ein Häkchen, darunter grün: @anna.berger ist frei.',
        explain: 'Smile schlägt einen Namen aus Annas Namen vor und fragt beim Server nach, ob er noch frei ist. Frei wird grün angezeigt.');
    await c.tap('Smile-Namen wählen');
    c.screen('Smile-Name');
    await c.check('Grün: ist frei', () => c.waitFor('~@anna.berger ist frei', seconds: 8));
    await c.hideKeyboard();
    await c.snap();

    c.step('Zu kurzer Name', 'Den Vorschlag löschen und nur ab eingeben.', 'Roter Rahmen, darunter rot: Noch zu kurz. Mindestens 3 Zeichen.',
        kind: 'Abzweigung', explain: 'Die Regeln prüft die App selbst, ohne den Server zu fragen, und sagt genau, was nicht passt.');
    await c.typeInto('', 'ab');
    await c.check('Rot: Noch zu kurz', () => c.waitFor('~Noch zu kurz', seconds: 5));
    await c.check('Regeln nicht doppelt in der Meldung', () => c.gone('~Mindestens 3 Zeichen: a', seconds: 1));
    await c.hideKeyboard();
    await c.snap();

    c.step('Name mit Punkt am Ende', 'anna. eingeben.', 'Roter Rahmen, darunter rot, was nicht erlaubt ist: kein Punkt am Ende.',
        kind: 'Abzweigung', explain: 'Auch Zeichen an der falschen Stelle werden mit dem genauen Grund gemeldet.');
    await c.typeInto('', 'anna.');
    await c.check('Rot: Kein Punkt am Ende', () => c.waitFor('Kein Punkt am Ende', seconds: 5));
    await c.check('Nur dieser eine Grund, nicht alle Regeln', () => c.gone('~keine zwei Punkte', seconds: 1));
    await c.hideKeyboard();
    await c.snap();

    for (final (name, input, kept, message, why) in [
      ('Name mit Leerzeichen', 'anna berger', 'annaberger', 'Leerzeichen gehen nicht. Nimm einen Punkt oder Unterstrich.',
          'Ein Leerzeichen kommt gar nicht erst ins Feld. Damit man nicht rätselt, wohin es verschwunden ist, sagt Smile kurz warum und was stattdessen geht.'),
      ('Name mit Sonderzeichen', 'anna!', 'anna', 'Das Zeichen ! geht nicht. Erlaubt sind a–z, 0–9, Punkt und Unterstrich.',
          'Andere Zeichen als a–z, 0–9, Punkt und Unterstrich kommen nicht ins Feld; der Hinweis nennt das Zeichen.'),
      ('Name mit Umlaut', 'jürgen', 'jrgen', 'Umlaute gehen nicht. Schreib ae, oe, ue oder ss.',
          'Umlaute gehen in Smile-Namen nicht (sie wären in Links schwer zu tippen); der Hinweis sagt, wie man sie schreibt.'),
    ]) {
      c.step(name, '$input eingeben.', 'Im Feld steht @$kept, darunter ein grauer Hinweis: $message',
          kind: 'Abzweigung', explain: why);
      await tester.tap(find.byType(TextField).last);
      await c.settle();
      await tester.enterText(find.byType(TextField).last, input);
      c.logTap('Eingabefeld');
      await c.settle();
      await c.check('Im Feld steht nur $kept', () => tester.widget<TextField>(find.byType(TextField).last).controller?.text == kept);
      await c.check('Hinweis: $message', () => c.waitFor(message, seconds: 3));
      await c.hideKeyboard();
      await c.snap();
    }

    for (final (name, input, message, why) in [
      ('Name beginnt mit Punkt', '.anna', 'Am Anfang muss ein Buchstabe oder eine Ziffer stehen', 'Punkt und Unterstrich sind erlaubt, nur nicht am Anfang.'),
      ('Name mit zwei Punkten', 'anna..berger', 'Keine zwei Punkte hintereinander', 'Zwei Punkte hintereinander sind nicht erlaubt.'),
    ]) {
      c.step(name, '$input eingeben.', 'Roter Rahmen, darunter rot: $message.', kind: 'Abzweigung', explain: why);
      await c.typeInto('', input);
      await c.check('Rot: $message', () => c.waitFor(message, seconds: 5));
      await c.hideKeyboard();
      await c.snap();
    }

    c.step('Vergebener Name', 'Stattdessen paul.berger eingeben (den hat Paul schon).',
        'Roter Rahmen, darunter rot: @paul.berger ist schon vergeben. Darunter drei freie Vorschläge, Speichern ist ausgegraut.',
        kind: 'Abzweigung', explain: 'Der Server meldet, dass paul.berger schon Paul gehört. Die App fragt gleich ein paar Abwandlungen nach und bietet die freien an.');
    await c.typeInto('', 'paul.berger');
    await c.check('Rot: schon vergeben', () => c.waitFor('~ist schon vergeben', seconds: 8));
    await c.check('Freie Vorschläge', () => c.waitFor('paul.berger1', seconds: 8));
    await c.hideKeyboard();
    await c.snap();

    c.step('Vorschlag antippen', 'Nacheinander alle drei Vorschläge antippen: paul_berger, paul.berger2 und zuletzt paul.berger1.',
        'Jeder Vorschlag steht nach dem Tippen im Feld und ist grün frei; am Ende paul.berger1.',
        kind: 'Abzweigung',
        explain: 'Ein Tipp übernimmt den Vorschlag ins Feld; gespeichert ist noch nichts. Alle drei Vorschläge werden geprüft, weil jeder ein eigener Knopf ist.');
    for (final s in ['paul_berger', 'paul.berger2']) {
      await c.tap(s);
      await c.check('Grün: @$s ist frei', () => c.waitFor('~@$s ist frei', seconds: 6));
      await c.typeInto('', 'paul.berger');
      await c.waitFor('paul.berger1', seconds: 8);
    }
    await c.tap('paul.berger1');
    await c.check('Grün: @paul.berger1 ist frei', () => c.waitFor('~@paul.berger1 ist frei', seconds: 6));
    await c.hideKeyboard();
    await c.snap();

    c.step('Smile-Name: Zurück ohne Speichern', 'Zurück antippen, ohne zu speichern.', 'Wieder die Einstellungen, dort steht weiter Smile-Namen wählen.',
        kind: 'Abzweigung', explain: 'Ohne Speichern bleibt alles, wie es war; die Testsuite prüft, dass kein Smile-Name gesetzt wurde.');
    await c.back();
    c.screen('Einstellungen');
    await c.waitFor('Smile-Namen wählen', seconds: 8);
    await c.check('Nichts gespeichert', () async => (await profile())['handle'] == null);
    await c.snap();

    c.step('Smile-Namen speichern', 'Smile-Namen wählen antippen, anna.berger eingeben und Speichern antippen.',
        'Zurück in den Einstellungen steht unter Smile-Name jetzt @anna.berger.',
        explain: 'Der Smile-Name wird gespeichert. Ab jetzt kann man Anna unter @anna.berger finden und einladen.');
    await c.tap('Smile-Namen wählen');
    c.screen('Smile-Name');
    await c.typeInto('', 'anna.berger');
    await c.waitFor('~ist frei', seconds: 8);
    await c.tap('Speichern');
    c.screen('Einstellungen');
    await c.waitFor('@anna.berger', seconds: 10);
    await c.check('Smile-Name gespeichert', () async => (await profile())['handle'] == 'anna.berger');
    await c.snap();

    c.step('Smile-Namen noch einmal öffnen', '@anna.berger antippen, nichts ändern.',
        '@anna.berger steht im Feld, Speichern ist ausgegraut, denn es gibt nichts zu speichern. Mit Zurück wieder in die Einstellungen.',
        kind: 'Abzweigung', explain: 'Nachsalzen: derselbe Smile-Name lässt sich nicht noch einmal speichern; Speichern wird erst aktiv, wenn sich etwas ändert.');
    await c.tap('@anna.berger');
    c.screen('Smile-Name');
    await c.waitFor('Speichern', seconds: 10);
    await c.check('Speichern ausgegraut',
        () => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Speichern')).onPressed == null);
    await c.hideKeyboard();
    await c.snap();
    await c.back();
    c.screen('Einstellungen');
    await c.waitFor('@anna.berger', seconds: 8);

    c.step('Meine Karte', 'Meine Karte antippen.',
        'Annas Karte: Bild, Name, @anna.berger, ein QR-Code und darunter smileapp.app/@anna.berger. Unten der Knopf Meine Karte teilen.',
        explain: 'Aus dem Smile-Namen entsteht ein Link (smileapp.app/@anna.berger) und daraus der QR-Code.');
    await c.tap('Meine Karte');
    c.screen('Meine Karte');
    await c.waitFor('Meine Karte teilen', seconds: 10);
    await c.check('Link auf der Karte', () => c.waitFor('smileapp.app/@anna.berger', seconds: 3));
    await c.snap();

    c.step('Meine Karte teilen', 'Meine Karte teilen antippen.',
        'Smile übergibt dem Teilen-Menü von Android den Text: Lade mich in Smile ein: https://smileapp.app/@anna.berger.',
        kind: 'Abzweigung',
        explain: 'Das Teilen-Menü gehört zu Android, nicht zu Smile. Die Testsuite fängt ab, was Smile ihm übergibt, und prüft den Text mit dem Link.');
    await c.tap('Meine Karte teilen');
    await c.check('Einladungstext mit Link', () => share.text == 'Lade mich in Smile ein: https://smileapp.app/@anna.berger');
    await c.snap();

    c.step('Smile-Namen entfernen', 'Zurück zu den Einstellungen, @anna.berger antippen und Smile-Namen entfernen wählen.',
        'In den Einstellungen steht wieder Smile-Namen wählen.',
        kind: 'Abzweigung', explain: 'Der Smile-Name wird gelöscht. Wer den alten Link hat, findet Anna nicht mehr.');
    await c.back();
    c.screen('Einstellungen');
    await c.tap('@anna.berger');
    c.screen('Smile-Name');
    await c.tap('Smile-Namen entfernen');
    c.screen('Einstellungen');
    await c.waitFor('Smile-Namen wählen', seconds: 10);
    await c.check('Smile-Name entfernt', () async => (await profile())['handle'] == null);
    await c.snap();

    c.step('Meine Karte ohne Smile-Namen', 'Meine Karte antippen.',
        'Die ganze Karte als Vorschau: Bild und Name, statt Smile-Name und QR-Code gestrichelte Platzhalter. Darunter @anna.berger übernehmen und Anderen Namen wählen.',
        kind: 'Abzweigung',
        explain: 'Ohne Smile-Namen gibt es keinen Link und keinen QR-Code. Die Karte zeigt Platzhalter, und Smile prüft, ob der Vorschlag @anna.berger frei ist.');
    await c.tap('Meine Karte');
    c.screen('Meine Karte (ohne Smile-Name)');
    await c.check('Platzhalter für den QR-Code', () => c.waitFor('Hier erscheint dein QR-Code', seconds: 10));
    await c.check('Vorschlag zum Übernehmen', () => c.waitFor('@anna.berger übernehmen', seconds: 8));
    await c.snap();

    c.step('Karte ohne Smile-Namen: Zurück', 'Zurück antippen und Meine Karte noch einmal öffnen.', 'Wieder die Karte mit Platzhaltern.',
        kind: 'Abzweigung', explain: 'Zurück und wieder hinein: die Karte sieht gleich aus.');
    await c.back();
    c.screen('Einstellungen');
    await c.tap('Meine Karte');
    c.screen('Meine Karte (ohne Smile-Name)');
    await c.waitFor('@anna.berger übernehmen', seconds: 10);
    await c.snap();

    c.step('Anderen Namen wählen', 'Anderen Namen wählen antippen und ohne Speichern mit Zurück wieder verlassen.',
        'Wieder die Karte mit Platzhaltern, nichts wurde gespeichert.',
        kind: 'Abzweigung', explain: 'Öffnet die Auswahl des Smile-Namens; ohne Speichern ändert sich nichts.');
    await c.tap('Anderen Namen wählen');
    c.screen('Smile-Name');
    await c.waitFor('Speichern', seconds: 10);
    await c.back();
    c.screen('Meine Karte (ohne Smile-Name)');
    await c.waitFor('@anna.berger übernehmen', seconds: 10);
    await c.check('Nichts gespeichert', () async => (await profile())['handle'] == null);
    await c.snap();

    c.step('Vorschlag übernehmen', '@anna.berger übernehmen antippen (hier absichtlich zweimal schnell).',
        'An derselben Stelle wird die Karte fertig: @anna.berger, der QR-Code und smileapp.app/@anna.berger. Keine Fehlermeldung.',
        kind: 'Abzweigung',
        explain: 'Ein Tipp speichert den freien Vorschlag. Die Karte wird an derselben Stelle fertig, mit Link und QR-Code. Der doppelte Tipp darf weder einen Fehler noch den Wechsel zur Namenswahl auslösen.');
    await c.tap('@anna.berger übernehmen', twice: true);
    c.screen('Meine Karte');
    await c.waitFor('Meine Karte teilen', seconds: 10);
    await c.check('Keine Namenswahl geöffnet', () => c.gone('Speichern', seconds: 3));
    await c.check('Smile-Name gespeichert', () async => (await profile())['handle'] == 'anna.berger');
    await c.check('QR-Code da', () => c.waitFor('smileapp.app/@anna.berger', seconds: 3));
    await c.snap();

    // ---------------------------------------------------------------- Videos senden
    c.step('Videos senden: Hoch', 'Zurück zu den Einstellungen und bei Videos senden Hoch antippen.',
        'Darunter steht: 720p, sehr scharf, rund 24 MB pro Minute Video.',
        kind: 'Abzweigung', explain: 'Bestimmt, wie stark Videos vor dem Senden verkleinert werden. Die Einstellung gilt nur für dieses Handy.');
    await c.back();
    c.screen('Einstellungen');
    await c.tap('Hoch');
    await c.check('Hinweis 720p', () => c.waitFor('~720p, sehr scharf', seconds: 3));
    await c.snap();

    c.step('Videos senden: Niedrig', 'Niedrig antippen.', 'Darunter steht: 360p, für kleine Bildschirme, rund 6 MB pro Minute.',
        kind: 'Abzweigung', explain: 'Kleinste Dateien, am schnellsten gesendet.');
    await c.tap('Niedrig');
    await c.check('Hinweis 360p', () => c.waitFor('~360p', seconds: 3));
    await c.snap();

    c.step('Videos senden: Mittel', 'Mittel antippen (so war es eingestellt).', 'Darunter steht wieder: Genau wie WhatsApp (480p).',
        kind: 'Abzweigung', explain: 'Zurück auf den Standard, damit die folgenden Kapitel vom gleichen Stand ausgehen.');
    await c.tap('Mittel');
    await c.check('Hinweis 480p', () => c.waitFor('~Genau wie WhatsApp', seconds: 3));
    await c.snap();

    // ---------------------------------------------------------------- Abmelden
    c.step('Abmelden: Frage', 'Nach unten wischen und Abmelden antippen.', 'Smile fragt: Möchtest du dich wirklich abmelden?',
        kind: 'Abzweigung', explain: 'Smile fragt vorher nach, damit man sich nicht aus Versehen abmeldet.');
    await tester.scrollUntilVisible(c.find_('Abmelden'), 300, scrollable: find.byType(Scrollable).first);
    await c.tap('Abmelden');
    c.screen('Abmelden-Frage');
    await c.waitFor('Möchtest du dich wirklich abmelden', seconds: 5);
    await c.snap();

    c.step('Abmelden: Abbrechen', 'Abbrechen antippen.', 'Die Frage verschwindet, Anna bleibt angemeldet.',
        kind: 'Abzweigung', explain: 'Nichts passiert, Anna bleibt angemeldet.');
    await c.tap('Abbrechen');
    c.screen('Einstellungen');
    await c.check('Noch in den Einstellungen', () => c.waitFor('Konto löschen', seconds: 3));
    await c.snap();

    c.step('Abmelden: daneben tippen', 'Noch einmal Abmelden antippen und dann neben die Frage tippen.',
        'Die Frage verschwindet, Anna bleibt angemeldet.', kind: 'Abzweigung', explain: 'Auch ein Tipp neben die Frage bricht ab.');
    await c.tap('Abmelden');
    c.screen('Abmelden-Frage');
    await c.waitFor('Möchtest du dich wirklich abmelden', seconds: 5);
    await c.tapAt(const Offset(200, 100), 'Schließen');
    c.screen('Einstellungen');
    await c.check('Noch in den Einstellungen', () => c.waitFor('Konto löschen', seconds: 3));
    await c.snap();

    c.step('Abmelden', 'Abmelden antippen und in der Frage Abmelden bestätigen.', 'Die Anmeldung erscheint wieder.',
        kind: 'Abzweigung', explain: 'Die Anmeldung auf diesem Handy wird beendet. Annas Konto, Profil und Smile-Name bleiben auf dem Server.');
    await c.tap('Abmelden');
    c.screen('Abmelden-Frage');
    await c.waitFor('Möchtest du dich wirklich abmelden', seconds: 5);
    await c.tap('Abmelden', last: true);
    c.screen('Anmeldung');
    await c.check('Anmeldung sichtbar', () => c.waitFor('Code anfordern', seconds: 10));
    await c.snap();

    c.step('Wieder anmelden', 'E-Mail-Adresse eingeben, Code anfordern und den Code eingeben.',
        'Smile öffnet direkt die Startseite. Name, Bild und Smile-Name sind noch da, die Begrüßung kommt nicht noch einmal.',
        kind: 'Abzweigung', explain: 'Mit neuem Code ist Anna wieder da. Weil ihr Profil schon existiert, kommt die Begrüßung nicht noch einmal.');
    await c.typeInto('E-Mail-Adresse', anna);
    await c.tap('Code anfordern');
    c.screen('Code-Eingabe');
    await c.waitFor('Bestätigen', seconds: 10);
    await c.typeInto('', await TestBackend.otp(anna));
    c.screen('Startseite (leer)');
    await c.check('Startseite ohne Begrüßung', () => c.waitFor('Willkommen bei Smile', seconds: 20));
    await c.check('Smile-Name noch da', () async => (await profile())['handle'] == 'anna.berger');
    await c.snap();

    c.step('Einstellungen verlassen', 'Drei Punkte, Einstellungen, dann oben links Zurück antippen.', 'Wieder die Startseite.',
        kind: 'Abzweigung', explain: 'Der Pfeil oben links führt zurück zur Startseite.');
    await c.tap('Weitere Optionen');
    c.screen('Menü');
    await c.tap('Einstellungen');
    c.screen('Einstellungen');
    await c.waitFor('Smile-Name', seconds: 10);
    await c.back();
    c.screen('Startseite (leer)');
    await c.check('Startseite', () => c.waitFor('Willkommen bei Smile', seconds: 10));
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
