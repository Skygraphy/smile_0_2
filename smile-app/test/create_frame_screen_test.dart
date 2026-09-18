import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smile_app/screens/create_frame_screen.dart';
import 'package:smile_app/services/frame_service.dart';

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
      home: CreateFrameScreen(spaceId: 'space-1', frameService: service),
    ));

    await tester.enterText(find.byType(TextField), 'Küche');
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    verify(() => service.createFrame(spaceId: 'space-1', name: 'Küche')).called(1);
    expect(find.text('ABCD1234'), findsOneWidget);
    expect(find.text('"Küche" wurde angelegt.'), findsOneWidget);
  });

  testWidgets('shows an error message on failure', (tester) async {
    final service = MockFrameService();
    when(() => service.createFrame(spaceId: any(named: 'spaceId'), name: any(named: 'name')))
        .thenThrow(FrameServiceException('unknown_error'));

    await tester.pumpWidget(MaterialApp(
      home: CreateFrameScreen(spaceId: 'space-1', frameService: service),
    ));

    await tester.enterText(find.byType(TextField), 'Küche');
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Frame konnte nicht erstellt werden'), findsOneWidget);
  });
}
