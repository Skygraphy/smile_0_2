import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/backend_config.dart';
import 'device_credentials_store.dart';
import 'kiosk_lockdown.dart';
import 'kiosk_status_store.dart';

class RemoteCommand {
  RemoteCommand({required this.id, required this.commandType});

  final String id;
  final String commandType;

  factory RemoteCommand.fromJson(Map<String, dynamic> json) => RemoteCommand(
        id: json['id'] as String,
        commandType: json['command_type'] as String,
      );
}

/// ComplianceWorker-equivalent (concept doc sect. 27-28): submits telemetry
/// and picks up any pending remote_commands in the same round-trip. Kept
/// deliberately minimal on telemetry fields for now (compliance_state,
/// app_version, os_version) -- battery/network/storage are nullable columns
/// and can be added later without a schema change if actually needed.
class ComplianceService {
  ComplianceService({
    http.Client? httpClient,
    DeviceCredentialsStore? credentialsStore,
    KioskLockdown? kioskLockdown,
    KioskStatusStore? statusStore,
  })  : _httpClient = httpClient ?? http.Client(),
        _credentialsStore = credentialsStore ?? DeviceCredentialsStore(),
        _kioskLockdown = kioskLockdown ?? KioskLockdown(),
        _statusStore = statusStore ?? KioskStatusStore();

  final http.Client _httpClient;
  final DeviceCredentialsStore _credentialsStore;
  final KioskLockdown _kioskLockdown;
  final KioskStatusStore _statusStore;

  Future<List<RemoteCommand>> submitHeartbeat() async {
    final accessToken = await _credentialsStore.accessToken;
    if (accessToken == null) return const [];

    // A live answer (foreground, native handler reachable) is always
    // authoritative and gets cached; an indeterminate answer (background
    // isolate, no handler there) falls back to the last confirmed value
    // instead of being reported as "definitely not pinned".
    final liveStatus = await _kioskLockdown.checkStatus();
    final bool isPinned;
    if (liveStatus != null) {
      isPinned = liveStatus;
      await _statusStore.save(liveStatus);
    } else {
      isPinned = await _statusStore.read() ?? false;
    }
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Not available on this platform/build -- heartbeat still goes out.
    }

    http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(BackendConfig.functionUrl('submit-heartbeat')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'compliance_state': isPinned ? 'compliant' : 'drift_detected',
          'app_version': ?appVersion,
          'os_version': Platform.operatingSystemVersion,
        }),
      );
    } catch (_) {
      return const []; // offline -- try again next round
    }
    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ((data['commands'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(RemoteCommand.fromJson)
        .toList();
  }

  Future<void> reportCommandStatus({
    required String commandId,
    required String status,
    Map<String, dynamic>? resultDetail,
  }) async {
    final accessToken = await _credentialsStore.accessToken;
    if (accessToken == null) return;
    try {
      await _httpClient.post(
        Uri.parse(BackendConfig.functionUrl('update-command-status')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'command_id': commandId,
          'status': status,
          'result_detail': ?resultDetail,
        }),
      );
    } catch (_) {
      // Best-effort -- the command stays 'delivered' server-side and the
      // next heartbeat/admin view can reconcile it.
    }
  }
}
