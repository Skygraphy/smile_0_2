import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
  final Battery _battery = Battery();
  // The device model never changes for the life of the install -- reading
  // it via a platform channel on every single heartbeat would be wasted
  // work, so it's resolved once and cached.
  String? _deviceModel;

  Future<String?> _resolveDeviceModel() async {
    if (_deviceModel != null) return _deviceModel;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // "manufacturer model" (e.g. "samsung SM-P610") -- manufacturer alone
      // is ambiguous across a household's devices, model alone is too
      // cryptic for a Space owner who has never seen the box it came in.
      _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
    } catch (_) {
      // Not available on this platform/build -- heartbeat still goes out.
    }
    return _deviceModel;
  }

  Future<void> submitHeartbeat({String? fcmToken}) async {
    final accessToken = await _credentialsStore.accessToken;
    if (accessToken == null) return;

    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Not available on this platform/build -- heartbeat still goes out.
    }

    int? batteryLevel;
    bool? isCharging;
    try {
      batteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      // A Frame is meant to sit plugged in permanently -- "isCharging" here
      // really means "plugged in", so a topped-up battery sitting at
      // `full`/`connectedNotCharging` still counts, not just the brief
      // window while the percentage is actively climbing.
      isCharging = state == BatteryState.charging ||
          state == BatteryState.full ||
          state == BatteryState.connectedNotCharging;
    } catch (_) {
      // Not available on this platform/build -- heartbeat still goes out.
    }

    final deviceModel = await _resolveDeviceModel();

    try {
      await _httpClient.post(
        Uri.parse(BackendConfig.functionUrl('submit-heartbeat')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'access_token': accessToken,
          'app_version': ?appVersion,
          'fcm_token': ?fcmToken,
          'battery_level': ?batteryLevel,
          'is_charging': ?isCharging,
          'device_model': ?deviceModel,
        }),
      );
    } catch (_) {
      // Offline -- try again next round; the periodic sync loop already
      // covers real connectivity, this is a best-effort side channel.
    }
  }
}
