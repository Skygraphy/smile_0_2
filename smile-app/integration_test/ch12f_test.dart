// Kapitel 12: Aufräumen, Teil am Tablet (X200).
// Läuft gleichzeitig mit ch12_test.dart am Handy: verbindet sich selbst mit
// dem Frame Wohnzimmer (nicht Teil des Kapitels) und zeigt, was das Tablet
// tut, wenn Anna den Frame löscht.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smile_app/frame/frame.dart' as frame;
import 'package:smile_app/main.dart' as app;

import 'support/backend.dart';
import 'support/chapter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kapitel 12: Aufräumen (Tablet)', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = Chapter(tester, binding, id: 'ch12f', title: 'Aufräumen (Tablet)', intro: '', device: 'X200');
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

    unawaited(app.main());
    try {
      // Until the phone has reset the server and created Wohnzimmer; then
      // this tablet becomes that Frame (as in chapter 6, without the steps).
      if (!await eventually(() async => (await TestBackend.select('frames', 'select=id')).isEmpty, seconds: 180)) {
        throw TestFailure('Der Server wurde nicht zurückgesetzt');
      }
      String? code;
      await eventually(() async {
        final rows = await TestBackend.select('frames', 'select=pairing_code&name=eq.Wohnzimmer');
        code = rows.isEmpty ? null : (rows.first as Map)['pairing_code'] as String?;
        return code != null;
      }, seconds: 600);
      if (code == null) throw TestFailure('Anna hat keinen Frame angelegt');
      await c.waitFor('Dieses Gerät als Frame verwenden', seconds: 30);
      await frame.becomeFrame(code!);
      c.screen('Frame: Diashow');
      if (!await eventually(() => c.find_('~Geburtstage').evaluate().isNotEmpty, seconds: 120)) {
        throw TestFailure('Der Frame zeigt keine Fotos');
      }
      await c.letLoad(seconds: 3);
      await TestBackend.signal('f0');
      await c.start();

      c.clearMessages();
      c.step('Am Tablet: vor dem Löschen', 'Am Tablet hinschauen.', 'Die Diashow mit den Fotos von Geburtstage.',
          explain: 'So sieht Oma Hildes Frame aus, bevor Anna ihn löscht.');
      await c.check('Geburtstage', () => eventually(() => c.find_('~Geburtstage').evaluate().isNotEmpty, seconds: 10));
      await c.snap();

      await c.awaitSignal('p1', seconds: 900);
      c.clearMessages();
      c.step('Am Tablet: Frame gelöscht', 'Am Tablet hinschauen.',
          'Die Fotos sind weg; das Tablet zeigt wieder die Anmeldung von Smile mit Dieses Gerät als Frame verwenden.',
          explain: 'Das Tablet erfährt sofort, dass es kein Frame mehr ist, löscht die Fotos und wird wieder ein ganz normales Smile.');
      c.screen('Anmeldung');
      await c.check('Wieder die Anmeldung', () => eventually(() => c.find_('Dieses Gerät als Frame verwenden').evaluate().isNotEmpty, seconds: 120));
      await c.check('Kein Frame mehr', () => frame.FrameMode.active.value != true);
      await c.letLoad(seconds: 2);
      await c.snap();
      await TestBackend.signal('f1');

      await c.finish(appVersion: version);
    } catch (e) {
      await c.finish(appVersion: version, error: e);
      rethrow;
    } finally {
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 35)));
}
