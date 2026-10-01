import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';

/// Resumable (TUS) upload into Supabase Storage, for videos of any length
/// (decision 2026-10-01: no length limit). Authorised by the same single-use
/// signed upload token create-upload hands out for photos -- passed as
/// `x-signature` -- so the app still never holds storage write rights.
///
/// Reads the file in 6 MB chunks straight from disk (Supabase requires
/// exactly 6 MB per chunk except the last), never the whole file in memory.
/// A dropped connection doesn't restart anything: it asks the server how
/// far it got (HEAD -> Upload-Offset) and carries on from there.
class ResumableUpload {
  ResumableUpload({http.Client? client}) : _client = client ?? http.Client();

  static const chunkSize = 6 * 1024 * 1024;
  static const _maxConsecutiveFailures = 8;

  final http.Client _client;

  Map<String, String> _headers(String token) => {
        'apikey': SupabaseConfig.publishableKey,
        'x-signature': token,
        'Tus-Resumable': '1.0.0',
      };

  Future<void> upload({
    required File file,
    required String bucket,
    required String objectName,
    required String token,
    required String contentType,
    void Function(int sentBytes, int totalBytes)? onProgress,
    void Function(int attempt, int maxAttempts)? onRetrying,
  }) async {
    final total = await file.length();
    final location = await _create(bucket, objectName, token, contentType, total);
    final raf = await file.open();
    try {
      var offset = 0;
      var failures = 0;
      while (offset < total) {
        try {
          await raf.setPosition(offset);
          final chunk = await raf.read(min(chunkSize, total - offset));
          final response = await _client.patch(
            Uri.parse(location),
            headers: {
              ..._headers(token),
              'Upload-Offset': '$offset',
              'Content-Type': 'application/offset+octet-stream',
            },
            body: chunk,
          );
          if (response.statusCode != 204) {
            throw HttpException('chunk at $offset: ${response.statusCode} ${response.body}');
          }
          offset = int.parse(response.headers['upload-offset'] ?? '${offset + chunk.length}');
          failures = 0;
          onProgress?.call(offset, total);
        } on SocketException catch (_) {
          offset = await _recover(location, token, offset, ++failures, onRetrying);
        } on HttpException catch (_) {
          offset = await _recover(location, token, offset, ++failures, onRetrying);
        } on http.ClientException catch (_) {
          offset = await _recover(location, token, offset, ++failures, onRetrying);
        }
      }
    } finally {
      await raf.close();
    }
  }

  Future<String> _create(String bucket, String objectName, String token, String contentType, int total) async {
    String b64(String v) => base64.encode(utf8.encode(v));
    final response = await _client.post(
      Uri.parse('${SupabaseConfig.url}/storage/v1/upload/resumable/sign'),
      headers: {
        ..._headers(token),
        'Upload-Length': '$total',
        'Upload-Metadata':
            'bucketName ${b64(bucket)},objectName ${b64(objectName)},contentType ${b64(contentType)}',
      },
    );
    final location = response.headers['location'];
    if (response.statusCode != 201 || location == null) {
      throw HttpException('resumable upload refused: ${response.statusCode} ${response.body}');
    }
    return location;
  }

  /// After a failed chunk: wait (growing), then ask the server where to
  /// continue. Gives up after [_maxConsecutiveFailures] in a row.
  Future<int> _recover(
    String location,
    String token,
    int offset,
    int failures,
    void Function(int attempt, int maxAttempts)? onRetrying,
  ) async {
    if (failures > _maxConsecutiveFailures) {
      throw HttpException('upload gave up after $_maxConsecutiveFailures failed attempts');
    }
    onRetrying?.call(failures, _maxConsecutiveFailures);
    await Future<void>.delayed(Duration(seconds: min(2 * failures, 30)));
    try {
      final head = await _client.head(Uri.parse(location), headers: _headers(token));
      final serverOffset = int.tryParse(head.headers['upload-offset'] ?? '');
      return serverOffset ?? offset;
    } catch (_) {
      return offset; // still offline -- the next attempt will tell
    }
  }
}
