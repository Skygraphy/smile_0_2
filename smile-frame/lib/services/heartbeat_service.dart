import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/backend_config.dart';
import 'frame_credentials_store.dart';

/// Lightweight operational telemetry -- last-seen/app-version/battery --
/// via submit-heartbeat. The architecture reset
/// (migrations/0031_architecture_reset.sql) removed every MDM/compliance
/// mechanism (remote_commands, policy enforcement, compliance-state
/// history) this used to also carry; what's left is purely informational,
/// shown to the Space owner in the Smile app's Frame settings.
class HeartbeatService {
  HeartbeatService({http.Client? httpClient, FrameCredentialsStore? credentialsStore})
      : _httpClient = httpClient ?? http.Client(),
        _credentialsStore = credentialsStore ?? FrameCredentialsStore();

  final http.Client _httpClient;
  final FrameCredentialsStore _credentialsStore;

  Future<void> submitHeartbeat({String? fcmToken}) async {
    final accessToken = await _credentialsStore.accessToken;
    if (accessToken == null) return;

    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Not available on this platform/build -- heartbeat still goes out.
    }

    try {
      await _httpClient.post(
        Uri.parse(BackendConfig.functionUrl('submit-heartbeat')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'app_version': ?appVersion,
          'fcm_token': ?fcmToken,
        }),
      );
    } catch (_) {
      // Offline -- try again next round; the periodic sync loop already
      // covers real connectivity, this is a best-effort side channel.
    }
  }
}
