import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the last CONFIRMED (not indeterminate) Screen Pinning status.
/// The FCM background handler runs in a headless engine with no
/// MainActivity/Activity, so it can't reach KioskLockdownPlugin's native
/// handler at all -- treating that as "definitely not pinned" mis-reported
/// compliance_state as drift_detected on every push-triggered heartbeat,
/// even while the app was genuinely pinned. Falling back to the last
/// value actually confirmed by a foreground check is far more accurate.
class KioskStatusStore {
  KioskStatusStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'last_known_pinned';

  Future<void> save(bool isPinned) => _storage.write(key: _key, value: isPinned.toString());

  Future<bool?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    return value == 'true';
  }
}
