// Kapitel 6: Frame verbinden, Teil am Tablet (X200). Läuft gleichzeitig mit
// ch06_test.dart am Handy und richtet sich nach dem Server: es fängt erst an,
// wenn Anna den Frame Wohnzimmer angelegt hat, und wartet dann auf ihr Album.
// Setzt nichts zurück (das macht der Teil am Handy).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/main.dart' as app;

import 'support/backend.dart';
import 'support/chapter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 6: Frame verbinden (Tablet)', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding, id: 'ch06f', title: 'Frame verbinden (Tablet)', intro: '', device: 'X200');
    const version = String.fromEnvironment('SMILE_APP_VERSION', defaultValue: '0.0.1');

    Future<bool> eventually(FutureOr<bool> Function() test, {double seconds = 10}) async {
      final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
      while (true) {
        try {
          if (await test()) return true;
        } catch (_) {}
        if (DateTime.now().isAfter(end)) return false;
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    Future<Map?> wohnzimmer() async =>
        (await TestBackend.select('frames', 'select=id,pairing_code,lifecycle_state&name=eq.Wohnzimmer')).cast<Map>().firstOrNull;

    unawaited(app.main());
    try {
      // Until the phone has reset the server (no Frames left from an
      // earlier run) and Anna has created Wohnzimmer and sees its code.
      if (!await eventually(() async => (await TestBackend.select('frames', 'select=id')).isEmpty, seconds: 180)) {
        throw TestFailure('Der Server wurde nicht zurückgesetzt');
      }
      if (!await eventually(() async => (await wohnzimmer())?['pairing_code'] != null, seconds: 600)) {
        throw TestFailure('Anna hat keinen Frame angelegt');
      }
      // The phone takes its picture of the code first.
      await c.letLoad(seconds: 8);
      final frame = (await wohnzimmer())!;
      final code = frame['pairing_code'] as String;
      c.screen('Anmeldung');
      await c.waitFor('Dieses Gerät als Frame verwenden', seconds: 20);
      await c.start();

      c.step('Am Tablet: Smile öffnen', 'Am Tablet Smile öffnen.',
          'Die Anmeldung, unten Dieses Gerät als Frame verwenden.',
          explain: 'Auf dem Tablet ist Smile installiert, aber noch niemand angemeldet.');
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: Dieses Gerät als Frame verwenden', 'Am Tablet Dieses Gerät als Frame verwenden antippen.',
          'Frame verbinden: Halte den QR-Code aus der Smile-App vor die Kamera, darunter das Kamerabild mit Rahmen und Code eintippen.',
          explain: 'Am Tablet hält man den QR-Code vom Handy vor die Kamera. In der Test-App bleibt die Kamera aus.');
      await c.tap('Dieses Gerät als Frame verwenden');
      c.screen('Frame: Verbinden');
      await c.check('Verbinden-Seite', () => c.waitFor('Halte den QR-Code', seconds: 8));
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: zurück zur Anmeldung', 'Am Tablet oben links zurück.', 'Wieder die Anmeldung.', kind: 'Abzweigung',
          explain: 'Wer sich vertippt hat, kommt hier zurück.');
      await c.back();
      c.screen('Anmeldung');
      await c.check('Anmeldung', () => c.waitFor('Dieses Gerät als Frame verwenden', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: Code eintippen', 'Am Tablet wieder Dieses Gerät als Frame verwenden, dann Code eintippen.',
          'Ein großes Feld für den Code, darunter Verbinden und QR-Code scannen.',
          explain: 'Ohne Kamera geht es auch mit dem Code, der am Handy unter dem QR-Code steht.');
      await c.tap('Dieses Gerät als Frame verwenden');
      c.screen('Frame: Verbinden');
      await c.tap('Code eintippen');
      await c.check('Feld', () => c.waitFor('Verbinden', seconds: 5));
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: doch scannen', 'Am Tablet QR-Code scannen antippen.', 'Wieder das Kamerabild mit Rahmen.', kind: 'Abzweigung',
          explain: 'Man kann zwischen Scannen und Eintippen wechseln.');
      await c.tap('QR-Code scannen');
      await c.check('Kamerabild', () => c.waitFor('QR-Code aus der Smile-App', seconds: 5));
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: falscher Code', 'Am Tablet Code eintippen, ABCD2345 eingeben und Verbinden.', 'Dieser Code ist ungültig.',
          kind: 'Abzweigung', explain: 'Mit einem falschen Code passiert nichts, das Tablet bleibt frei.');
      await c.tap('Code eintippen');
      await c.typeInto('', 'ABCD2345', logAs: 'Eingabefeld');
      await c.tap('Verbinden', last: true);
      await c.check('Ungültig', () => c.waitFor('Dieser Code ist ungültig', seconds: 15));
      await c.check('Frame noch nicht verbunden', () async => (await wohnzimmer())?['lifecycle_state'] != 'active');
      await c.hideKeyboard();
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: Code vom Handy', 'Am Tablet den Code eingeben, der am Handy steht, und Verbinden.',
          'Das Tablet ist jetzt der Frame Wohnzimmer. Es zeigt Noch keine Fotos, weil es noch kein Album hat.',
          explain: 'Ab jetzt läuft auf dem Tablet nur noch die Diashow. Am Handy erscheint gleichzeitig die Fernbedienung.');
      await c.typeInto('', code, logAs: 'Eingabefeld');
      await c.tap('Verbinden', last: true);
      c.screen('Frame: Diashow');
      await c.check('Frame aktiv', () => eventually(() async => (await wohnzimmer())?['lifecycle_state'] == 'active', seconds: 20));
      await c.check('Noch keine Fotos', () => c.waitFor('Noch keine Fotos', seconds: 20));
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: die Fotos kommen', 'Warten, bis Anna am Handy ein Album hinzufügt.',
          'Der Frame zeigt die Fotos und Videos aus Geburtstage, bildschirmfüllend und ohne Knöpfe.',
          explain: 'Was Anna am Handy einstellt, kommt von selbst auf den Frame.');
      await c.check('Album zugewiesen', () => eventually(() async =>
          (await TestBackend.select('frame_channels', 'select=channel_id&frame_id=eq.${frame['id']}')).isNotEmpty, seconds: 600));
      await c.check('Fotos da', () => c.gone('Noch keine Fotos', seconds: 60));
      await c.letLoad(seconds: 2);
      await c.snap();

      c.clearMessages();
      c.step('Am Tablet: antippen', 'Am Tablet auf den Bildschirm tippen.',
          'Es erscheinen keine Knöpfe, die Diashow läuft einfach weiter.',
          explain: 'Bei Nur zuschauen kann Oma Hilde nichts verstellen. Alles Weitere macht Anna in der App.');
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await c.tapAt(Offset(size.width / 2, size.height / 2), 'Bildschirm antippen');
      await c.letLoad(seconds: 1);
      await c.check('Kein Weiter-Knopf', () => c.gone('Weiter', seconds: 1));
      await c.check('Kein Pause-Knopf', () => c.gone('Pause', seconds: 1));
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
