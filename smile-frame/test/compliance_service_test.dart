import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:smile_frame/services/compliance_service.dart';
import 'package:smile_frame/services/device_credentials_store.dart';
import 'package:smile_frame/services/kiosk_lockdown.dart';
import 'package:smile_frame/services/kiosk_status_store.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockDeviceCredentialsStore extends Mock implements DeviceCredentialsStore {}

class MockKioskLockdown extends Mock implements KioskLockdown {}

class MockKioskStatusStore extends Mock implements KioskStatusStore {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  late MockHttpClient httpClient;
  late MockDeviceCredentialsStore credentialsStore;
  late MockKioskLockdown kioskLockdown;
  late MockKioskStatusStore statusStore;
  late ComplianceService service;

  setUp(() {
    httpClient = MockHttpClient();
    credentialsStore = MockDeviceCredentialsStore();
    kioskLockdown = MockKioskLockdown();
    statusStore = MockKioskStatusStore();
    service = ComplianceService(
      httpClient: httpClient,
      credentialsStore: credentialsStore,
      kioskLockdown: kioskLockdown,
      statusStore: statusStore,
    );
    when(() => credentialsStore.accessToken).thenAnswer((_) async => 'test-token');
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response(jsonEncode({'commands': []}), 200));
  });

  // Pinning is a manual, admin-triggered action now (Android's own
  // Recent-Apps "Pin" gesture -- no in-app trigger, no Home-role
  // auto-recovery), so an unpinned Frame is the expected normal state, not
  // a compliance violation. The live pin status is still recorded (for
  // device_settings_screen.dart's display) but never affects
  // compliance_state, which is always reported as 'compliant'.
  test('compliance_state is always compliant regardless of pin status', () async {
    when(() => kioskLockdown.checkStatus()).thenAnswer((_) async => false);
    when(() => statusStore.save(any())).thenAnswer((_) async {});

    await service.submitHeartbeat();

    final captured = verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: captureAny(named: 'body')))
        .captured
        .single as String;
    expect(jsonDecode(captured)['compliance_state'], 'compliant');
  });

  test('a live status is cached for display, whatever its value', () async {
    when(() => kioskLockdown.checkStatus()).thenAnswer((_) async => true);
    when(() => statusStore.save(any())).thenAnswer((_) async {});

    await service.submitHeartbeat();

    verify(() => statusStore.save(true)).called(1);
  });

  test('an indeterminate status (background isolate, no native handler) is not cached', () async {
    when(() => kioskLockdown.checkStatus()).thenAnswer((_) async => null);

    await service.submitHeartbeat();

    verifyNever(() => statusStore.save(any()));
  });
}
