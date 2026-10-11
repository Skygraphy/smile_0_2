import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smile_app/screens/create_frame_screen.dart';
import 'package:smile_app/services/frame_service.dart';
import 'package:smile_design_system/smile_design_system.dart';

class MockFrameService extends Mock implements FrameService {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  testWidgets('shows the pairing code after a successful create', (tester) async {
    final service = MockFrameService();
    when(() => service.createFrame(spaceId: any(named: 'spaceId'), name: any(named: 'name'))).thenAnswer(
      (_) async => SmileFrame(
        id: 'frame-1',
        name: 'Küche',
        lifecycleState: 'pending',
        channelSwitchEnabled: false,
        pairingCode: 'ABCD1234',
        pairingCodeExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: CreateFrameScreen(spaceId: 'space-1', frameService: service),
    ));

    await tester.enterText(find.byType(TextField), 'Küche');
    await tester.pump();
    // "Ein anderes Gerät": the code to scan or type (2026-10-11).
    await tester.tap(find.text('Ein anderes Gerät'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => service.createFrame(spaceId: 'space-1', name: 'Küche')).called(1);
    expect(find.text('ABCD 1234'), findsOneWidget);
    expect(find.text('„Küche“ verbinden'), findsOneWidget);
  });

  testWidgets('shows an error message on failure', (tester) async {
    final service = MockFrameService();
    when(() => service.createFrame(spaceId: any(named: 'spaceId'), name: any(named: 'name')))
        .thenThrow(FrameServiceException('unknown_error'));

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: SmileTexts.localizationsDelegates,
      supportedLocales: SmileTexts.supportedLocales,
      home: CreateFrameScreen(spaceId: 'space-1', frameService: service),
    ));

    await tester.enterText(find.byType(TextField), 'Küche');
    await tester.pump();
    // "Ein anderes Gerät": the code to scan or type (2026-10-11).
    await tester.tap(find.text('Ein anderes Gerät'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Das hat leider nicht geklappt'), findsOneWidget);
  });
}
