import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class FrameCredentials {
  FrameCredentials({
    required this.frameId,
    required this.spaceId,
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshSecret,
  });

  final String frameId;
  final String spaceId;
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshSecret;

  factory FrameCredentials.fromJson(Map<String, dynamic> json) => FrameCredentials(
        frameId: json['frame_id'] as String,
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

/// Thin client for the pairing/credential Edge Functions. Reversed order
/// from the pre-reset schema (migrations/0031_architecture_reset.sql): a
/// Space owner creates the Frame record and its pairing code from the
/// Smile app first (create-frame); this Frame only ever has to claim that
/// already-existing code, typed in by whoever is standing in front of it
/// -- no more request/poll dance.
class PairingService {
  PairingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FrameCredentials> claimPairing(String code) async {
    final response = await _client.post(
      Uri.parse(BackendConfig.functionUrl('claim-frame-pairing')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    _throwIfError(response);
    return FrameCredentials.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RefreshedTokens> refreshToken({required String frameId, required String refreshSecret}) async {
    final response = await _client.post(
      Uri.parse(BackendConfig.functionUrl('refresh-frame-token')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'frame_id': frameId, 'refresh_secret': refreshSecret}),
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
