import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keystore-backed Frame credential storage (Android Keystore via
/// EncryptedSharedPreferences, wrapped by flutter_secure_storage).
class FrameCredentialsStore {
  FrameCredentialsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyFrameId = 'frame_id';
  static const _keySpaceId = 'space_id';
  static const _keyAccessToken = 'access_token';
  static const _keyAccessTokenExpiresAt = 'access_token_expires_at';
  static const _keyRefreshSecret = 'refresh_secret';
  // Personal Mode channel switcher: the last channel the person in front
  // of this Frame explicitly picked. Never set at all for an Assisted
  // Mode Frame -- sync() then just keeps taking the server's default,
  // exactly like before this existed.
  static const _keyPreferredChannelId = 'preferred_channel_id';

  Future<bool> isProvisioned() async {
    final frameId = await _storage.read(key: _keyFrameId);
    return frameId != null && frameId.isNotEmpty;
  }

  Future<void> saveCredentials({
    required String frameId,
    required String spaceId,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
    required String refreshSecret,
  }) async {
    await _storage.write(key: _keyFrameId, value: frameId);
    await _storage.write(key: _keySpaceId, value: spaceId);
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(
      key: _keyAccessTokenExpiresAt,
      value: accessTokenExpiresAt.toUtc().toIso8601String(),
    );
    await _storage.write(key: _keyRefreshSecret, value: refreshSecret);
  }

  /// Called after a successful refresh-frame-token call: only the access
  /// token and refresh secret rotate, Frame/Space identity stays put.
  Future<void> saveRefreshedTokens({
    required String accessToken,
    required DateTime accessTokenExpiresAt,
    required String refreshSecret,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(
      key: _keyAccessTokenExpiresAt,
      value: accessTokenExpiresAt.toUtc().toIso8601String(),
    );
    await _storage.write(key: _keyRefreshSecret, value: refreshSecret);
  }

  Future<String?> get frameId => _storage.read(key: _keyFrameId);
  Future<String?> get spaceId => _storage.read(key: _keySpaceId);
  Future<String?> get accessToken => _storage.read(key: _keyAccessToken);
  Future<String?> get refreshSecret => _storage.read(key: _keyRefreshSecret);

  Future<DateTime?> get accessTokenExpiresAt async {
    final raw = await _storage.read(key: _keyAccessTokenExpiresAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<String?> get preferredChannelId => _storage.read(key: _keyPreferredChannelId);

  Future<void> savePreferredChannelId(String channelId) =>
      _storage.write(key: _keyPreferredChannelId, value: channelId);

  /// Called when the previously chosen channel turns out to no longer be
  /// assigned to this Frame (get-media-batch's "frame_not_assigned_to_
  /// channel") -- falls back to the server default on the next sync.
  Future<void> clearPreferredChannelId() => _storage.delete(key: _keyPreferredChannelId);

  Future<void> clear() => _storage.deleteAll();
}
