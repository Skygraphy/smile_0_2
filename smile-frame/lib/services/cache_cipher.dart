import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts the cached photos at rest (architecture review 2026-09-29,
/// weakness 7). Before this, the Frame's photo files sat in plain JPEG in
/// the app's directory -- readable by anyone with ADB access to a debug
/// build (`run-as`), which the Frames' wireless debugging makes easy.
///
/// AES-GCM (authenticated: a tampered file fails to decrypt instead of
/// showing garbage), one random 256-bit key per install, kept in
/// flutter_secure_storage -- i.e. wrapped by the Android Keystore, never
/// on disk in the clear. File format: nonce (12) + ciphertext + MAC (16).
///
/// The key lives in the same secure storage as the Frame's credentials, so
/// un-pairing (FrameCredentialsStore.clear -> deleteAll) destroys it too:
/// any file left behind becomes unreadable.
class CacheCipher {
  CacheCipher({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'cache_key_v1';
  static final _algorithm = AesGcm.with256bits();

  final FlutterSecureStorage _storage;
  SecretKey? _key;

  Future<SecretKey> _secretKey() async {
    final cached = _key;
    if (cached != null) return cached;
    final stored = await _storage.read(key: _keyName);
    if (stored != null) {
      return _key = SecretKey(_decodeHex(stored));
    }
    final fresh = await _algorithm.newSecretKey();
    await _storage.write(key: _keyName, value: _encodeHex(await fresh.extractBytes()));
    return _key = fresh;
  }

  Future<Uint8List> encrypt(List<int> plain) async {
    final box = await _algorithm.encrypt(plain, secretKey: await _secretKey());
    return box.concatenation();
  }

  Future<Uint8List> decrypt(List<int> sealed) async {
    final box = SecretBox.fromConcatenation(
      sealed,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    return Uint8List.fromList(await _algorithm.decrypt(box, secretKey: await _secretKey()));
  }

  static String _encodeHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _decodeHex(String hex) =>
      [for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
}
