import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class PairingRequest {
  PairingRequest({
    required this.deviceId,
    required this.code,
    required this.expiresAt,
    required this.pollIntervalSeconds,
  });

  final String deviceId;
  final String code;
  final DateTime expiresAt;
  final int pollIntervalSeconds;

  factory PairingRequest.fromJson(Map<String, dynamic> json) => PairingRequest(
        deviceId: json['device_id'] as String,
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        pollIntervalSeconds: json['poll_interval_seconds'] as int,
      );
}

class DeviceCredentials {
  DeviceCredentials({
    required this.deviceId,
    required this.spaceId,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshSecret,
  });

  final String deviceId;
  final String spaceId;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshSecret;

  factory DeviceCredentials.fromJson(Map<String, dynamic> json) => DeviceCredentials(
        deviceId: json['device_id'] as String,
        spaceId: json['space_id'] as String,
        accessToken: json['access_token'] as String,
        accessTokenExpiresAt: DateTime.parse(json['access_token_expires_at'] as String),
        refreshSecret: json['refresh_secret'] as String,
      );
}

class RefreshedTokens {
  RefreshedTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshSecret,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshSecret;

  factory RefreshedTokens.fromJson(Map<String, dynamic> json) => RefreshedTokens(
        accessToken: json['access_token'] as String,
        accessTokenExpiresAt: DateTime.parse(json['access_token_expires_at'] as String),
        refreshSecret: json['refresh_secret'] as String,
      );
}

/// Thin client for the pairing/credential Edge Functions. See
/// supabase/functions/{request,poll}-device-pairing and
/// refresh-device-token for the server side of this exchange.
class PairingService {
  PairingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PairingRequest> requestPairing({String? deviceName, String? androidId, String? appVersion}) async {
    final response = await _client.post(
      Uri.parse(BackendConfig.functionUrl('request-device-pairing')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_name': ?deviceName,
        'android_id': ?androidId,
        'app_version': ?appVersion,
      }),
    );
    _throwIfError(response);
    return PairingRequest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Returns null while pairing is still pending; returns the device's own
  /// credentials the moment a Space Owner has claimed the code.
  Future<DeviceCredentials?> pollPairing({required String deviceId, required String code}) async {
    final response = await _client.post(
      Uri.parse(BackendConfig.functionUrl('poll-device-pairing')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_id': deviceId, 'code': code}),
    );
    _throwIfError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] == 'pending') return null;
    return DeviceCredentials.fromJson(json);
  }

  Future<RefreshedTokens> refreshToken({required String deviceId, required String refreshSecret}) async {
    final response = await _client.post(
      Uri.parse(BackendConfig.functionUrl('refresh-device-token')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_id': deviceId, 'refresh_secret': refreshSecret}),
    );
    _throwIfError(response);
    return RefreshedTokens.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // ignore -- fall through to the generic message below
    }
    throw PairingException(body?['error'] as String? ?? 'request_failed', response.statusCode);
  }
}

class PairingException implements Exception {
  PairingException(this.code, this.statusCode);

  final String code;
  final int statusCode;

  @override
  String toString() => 'PairingException($code, $statusCode)';
}
