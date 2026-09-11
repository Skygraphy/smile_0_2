import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smile_app/screens/pair_frame_screen.dart';
import 'package:smile_app/services/device_service.dart';
import 'package:smile_app/services/pairing_service.dart';

class MockPairingService extends Mock implements PairingService {}

class MockDeviceService extends Mock implements DeviceService {}

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  testWidgets('shows success state after a valid code is submitted', (tester) async {
    final service = MockPairingService();
    final deviceService = MockDeviceService();
    when(() => service.claimDevicePairing(code: any(named: 'code'), spaceId: any(named: 'spaceId')))
        .thenAnswer((_) async {});
    when(() => deviceService.listDevices(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(MaterialApp(
      home: PairFrameScreen(spaceId: 'space-1', pairingService: service, deviceService: deviceService),
    ));

    await tester.enterText(find.byType(TextField), 'ABCD1234');
    await tester.tap(find.text('Koppeln'));
    await tester.pumpAndSettle();

    verify(() => service.claimDevicePairing(code: 'ABCD1234', spaceId: 'space-1')).called(1);
    expect(find.text('Frame gekoppelt. Es aktiviert sich in Kürze von selbst.'), findsOneWidget);
  });

  testWidgets('shows a translated error message on failure', (tester) async {
    final service = MockPairingService();
    final deviceService = MockDeviceService();
    when(() => service.claimDevicePairing(code: any(named: 'code'), spaceId: any(named: 'spaceId')))
        .thenThrow(PairingClaimException('code_expired'));
    when(() => deviceService.listDevices(any())).thenAnswer((_) async => []);

    await tester.pumpWidget(MaterialApp(
      home: PairFrameScreen(spaceId: 'space-1', pairingService: service, deviceService: deviceService),
    ));

    await tester.enterText(find.byType(TextField), 'EXPIRED1');
    await tester.tap(find.text('Koppeln'));
    await tester.pumpAndSettle();

    expect(find.text('Der Code ist abgelaufen.'), findsOneWidget);
  });
}
