import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'offline.dart';

/// Every screen works offline with what it showed last (decided 2026-10-09):
/// the one http client Supabase uses keeps the answer to every *reading*
/// request on the phone, and answers the same request from there while
/// there is no connection. Writes always go to the server (and fail
/// offline, which LocalChanges turns into "Änderung nicht gespeichert").
///
/// Reading = table reads (GET /rest/v1/...) and the list-*/get-* Edge
/// Functions. The cache is per signed-in person.
class OfflineCachingClient extends http.BaseClient {
  OfflineCachingClient({required this.currentUserId, http.Client? inner, Directory? directory})
      : _inner = inner ?? http.Client(),
        _dir = directory;

  final http.Client _inner;
  final String? Function() currentUserId;
  Directory? _dir;

  static bool isReading(http.BaseRequest request) {
    final path = request.url.path;
    if (request.method == 'GET' && path.contains('/rest/v1/')) return true;
    if (request.method == 'POST' && path.contains('/functions/v1/')) {
      final fn = path.split('/').last;
      return fn.startsWith('list-') || fn.startsWith('get-');
    }
    return false;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!isReading(request)) return _inner.send(request);
    final body = request is http.Request ? request.body : '';
    final key = _key('${currentUserId()}|${request.method}|${request.url}|$body');
    try {
      final response = await _inner.send(request);
      final bytes = await response.stream.toBytes();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        Offline.reachedServer();
        await _store(key, response.statusCode, response.headers, bytes);
      }
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: request,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (error) {
      if (!Offline.noteFailure(error)) rethrow;
      final cached = await _load(key);
      if (cached == null) rethrow;
      return http.StreamedResponse(
        Stream.value(cached.bytes),
        cached.status,
        contentLength: cached.bytes.length,
        request: request,
        headers: cached.headers,
      );
    }
  }

  Future<Directory> _cacheDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/offline_cache');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  Future<void> _store(String key, int status, Map<String, String> headers, Uint8List bytes) async {
    try {
      final file = File('${(await _cacheDir()).path}/$key.json');
      await file.writeAsString(jsonEncode({'status': status, 'headers': headers, 'body': base64Encode(bytes)}));
    } catch (_) {
      // Only a convenience for offline -- never the reason a request fails.
    }
  }

  Future<({int status, Map<String, String> headers, Uint8List bytes})?> _load(String key) async {
    try {
      final file = File('${(await _cacheDir()).path}/$key.json');
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (
        status: json['status'] as int,
        headers: (json['headers'] as Map).cast<String, String>(),
        bytes: base64Decode(json['body'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// A stable file name (FNV-1a, 64 bit) for a request.
  static String _key(String text) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(text)) {
      hash ^= unit;
      hash = hash * 0x100000001b3; // wraps at 64 bits
    }
    return hash.toUnsigned(64).toRadixString(16);
  }

  @override
  void close() => _inner.close();
}
