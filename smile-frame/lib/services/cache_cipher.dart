import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts the cached photos and videos at rest (architecture review
/// 2026-09-29, weakness 7). Before this, the Frame's files sat in plain
/// JPEG in the app's directory -- readable by anyone with ADB access to a
/// debug build (`run-as`), which the Frames' wireless debugging makes easy.
///
/// AES-GCM (authenticated: a tampered file fails to decrypt instead of
/// showing garbage), one random 256-bit key per install, kept in
/// flutter_secure_storage -- i.e. wrapped by the Android Keystore, never on
/// disk in the clear.
///
/// Files are sealed in blocks of [blockSize] plaintext bytes, each block
/// its own nonce (12) + ciphertext + MAC (16), so a video of any length
/// (decision 2026-10-01) streams through in constant memory -- never the
/// whole file at once, neither when caching nor when playing.
///
/// The key lives in the same secure storage as the Frame's credentials, so
/// un-pairing (FrameCredentialsStore.clear -> deleteAll) destroys it too:
/// any file left behind becomes unreadable.
class CacheCipher {
  CacheCipher({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const blockSize = 1024 * 1024;
  static const _overhead = 12 + 16;
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

  Future<Uint8List> _seal(List<int> block) async {
    final box = await _algorithm.encrypt(block, secretKey: await _secretKey());
    return box.concatenation();
  }

  Future<List<int>> _open(List<int> sealed) async {
    final box = SecretBox.fromConcatenation(
      sealed,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    return _algorithm.decrypt(box, secretKey: await _secretKey());
  }

  /// Encrypts [plain] (e.g. a download) into [out] block by block; returns
  /// the number of plaintext bytes written.
  Future<int> encryptStreamToFile(Stream<List<int>> plain, File out) async {
    final sink = out.openWrite();
    final buffer = BytesBuilder(copy: false);
    var total = 0;
    try {
      await for (final data in plain) {
        buffer.add(data);
        total += data.length;
        while (buffer.length >= blockSize) {
          final all = buffer.takeBytes();
          sink.add(await _seal(Uint8List.sublistView(all, 0, blockSize)));
          if (all.length > blockSize) buffer.add(Uint8List.sublistView(all, blockSize));
        }
      }
      if (buffer.length > 0 || total == 0) sink.add(await _seal(buffer.takeBytes()));
    } finally {
      await sink.close();
    }
    return total;
  }

  Future<int> encryptBytesToFile(List<int> plain, File out) => encryptStreamToFile(Stream.value(plain), out);

  /// The plaintext of an encrypted file, block by block.
  Stream<List<int>> decryptFile(File sealed) async* {
    final raf = await sealed.open();
    try {
      final length = await raf.length();
      var position = 0;
      while (position < length) {
        final blockLength = min(blockSize + _overhead, length - position);
        yield await _open(await raf.read(blockLength));
        position += blockLength;
      }
    } finally {
      await raf.close();
    }
  }

  Future<Uint8List> decryptToBytes(File sealed) async {
    final builder = BytesBuilder(copy: false);
    await for (final block in decryptFile(sealed)) {
      builder.add(block);
    }
    return builder.takeBytes();
  }

  Future<void> decryptToFile(File sealed, File out) async {
    final sink = out.openWrite();
    try {
      await sink.addStream(decryptFile(sealed));
    } finally {
      await sink.close();
    }
  }

  static String _encodeHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _decodeHex(String hex) =>
      [for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
}
