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

  test('a live pinned status is reported as-is and cached', () async {
    when(() => kioskLockdown.checkStatus()).thenAnswer((_) async => true);
    when(() => statusStore.save(any())).thenAnswer((_) async {});

    await service.submitHeartbeat();

    final captured = verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: captureAny(named: 'body')))
        .captured
        .single as String;
    expect(jsonDecode(captured)['compliance_state'], 'compliant');
    verify(() => statusStore.save(true)).called(1);
  });

  test('an indeterminate status (background isolate) falls back to the last known value', () async {
    when(() => kioskLockdown.checkStatus()).thenAnswer((_) async => null);
    when(() => statusStore.read()).thenAnswer((_) async => true);

    await service.submitHeartbeat();

    final captured = verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: captureAny(named: 'body')))
        .captured
        .single as String;
    expect(jsonDecode(captured)['compliance_state'], 'compliant');
    verifyNever(() => statusStore.save(any()));
  });

  test('an indeterminate status with no prior known value defaults to drift_detected', () async {
    when(() => kioskLockdown.checkStatus()).thenAnswer((_) async => null);
    when(() => statusStore.read()).thenAnswer((_) async => null);

    await service.submitHeartbeat();

    final captured = verify(() => httpClient.post(any(), headers: any(named: 'headers'), body: captureAny(named: 'body')))
        .captured
        .single as String;
    expect(jsonDecode(captured)['compliance_state'], 'drift_detected');
  });
}
