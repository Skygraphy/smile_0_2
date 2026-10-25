import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The TESTSUITE project with service rights, for the chapters
/// (tools/testsuite): reset, test persons, login codes, state. Refuses the
/// live project; the key only exists in test builds (--dart-define).
class TestBackend {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SMILE_TEST_SERVICE_KEY');

  static void _guard() {
    if (url.contains('wxuipqaozvgzthlgnbgz') || _key.isEmpty || url.isEmpty) {
      throw StateError('Nur gegen das Testprojekt (SMILE_TEST_SERVICE_KEY fehlt oder Live-Projekt).');
    }
  }

  static Map<String, String> get _h =>
      {'apikey': _key, 'Authorization': 'Bearer $_key', 'Content-Type': 'application/json'};

  static Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? headers}) async {
    _guard();
    final req = http.Request(method, Uri.parse('$url$path'))..headers.addAll({..._h, ...?headers});
    if (body != null) req.body = body is String ? body : jsonEncode(body);
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode >= 300) throw StateError('$method $path: ${res.statusCode} ${res.body}');
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  static Future<dynamic> rpc(String fn) => _send('POST', '/rest/v1/rpc/$fn', body: {});

  /// Back to zero: all files, rows and users.
  static Future<void> reset() async {
    final buckets = await _send('GET', '/storage/v1/bucket') as List;
    for (final b in buckets) {
      final id = b['id'] as String;
      final files = await _list(id, '');
      for (var i = 0; i < files.length; i += 500) {
        await _send('DELETE', '/storage/v1/object/$id', body: {'prefixes': files.sublist(i, (i + 500).clamp(0, files.length))});
      }
    }
    await rpc('testsuite_reset');
  }

  static Future<List<String>> _list(String bucket, String prefix) async {
    final out = <String>[];
    final entries = await _send('POST', '/storage/v1/object/list/$bucket', body: {'prefix': prefix, 'limit': 1000}) as List;
    for (final e in entries) {
      final path = prefix.isEmpty ? e['name'] as String : '$prefix/${e['name']}';
      if (e['id'] == null) {
        out.addAll(await _list(bucket, path));
      } else {
        out.add(path);
      }
    }
    return out;
  }

  static Future<String> userId(String email) async {
    final users = (await _send('GET', '/auth/v1/admin/users?per_page=1000'))['users'] as List;
    final found = users.where((u) => u['email'] == email).firstOrNull;
    if (found != null) return found['id'] as String;
    final created = await _send('POST', '/auth/v1/admin/users', body: {'email': email, 'email_confirm': true});
    return created['id'] as String;
  }

  /// A test person without a device: user, profile, optional Smile name.
  static Future<void> person(String email, String name, {String? handle}) async {
    final id = await userId(email);
    await _send('POST', '/rest/v1/profiles',
        headers: {'Prefer': 'resolution=merge-duplicates'},
        body: {'user_id': id, 'display_name': name, 'handle': ?handle});
  }

  /// A profile picture, stored as the app does (`users/<id>/<ms>`).
  static Future<void> setAvatar(String email, Uint8List bytes, String contentType) async {
    final id = await userId(email);
    final path = 'users/$id/${DateTime.now().millisecondsSinceEpoch}';
    await putPublic(path, bytes, contentType);
    await _send('PATCH', '/rest/v1/profiles?user_id=eq.$id', body: {'avatar_path': path});
  }

  /// The 6-digit code the mail would have brought.
  static Future<String> otp(String email) async {
    await userId(email);
    final link = await _send('POST', '/auth/v1/admin/generate_link', body: {'type': 'magiclink', 'email': email});
    return link['email_otp'] as String;
  }

  /// A file in the public avatars bucket (a picture on the internet for the tests).
  static Future<String> putPublic(String path, Uint8List bytes, String contentType) async {
    _guard();
    final res = await http.post(Uri.parse('$url/storage/v1/object/avatars/$path'),
        headers: {'Authorization': 'Bearer $_key', 'Content-Type': contentType, 'x-upsert': 'true'}, body: bytes);
    if (res.statusCode >= 300) throw StateError('upload $path: ${res.statusCode}');
    return '$url/storage/v1/object/public/avatars/$path';
  }

  /// Rows of a table (PostgREST query), e.g. select('profiles', 'select=handle&user_id=eq.x').
  static Future<List> select(String table, String query) async => await _send('GET', '/rest/v1/$table?$query') as List;

  /// Size of a file in the avatars bucket (null: no such file).
  static Future<int?> avatarSize(String path) async {
    final res = await http.get(Uri.parse('$url/storage/v1/object/public/avatars/$path'));
    return res.statusCode == 200 ? res.bodyBytes.length : null;
  }

  /// A signal between the two parts of a chapter on two devices (chapter
  /// 7 on, table testsuite_signals in state.sql): "I took my picture".
  static Future<void> signal(String name) => _send('POST', '/rest/v1/testsuite_signals',
      headers: {'Prefer': 'resolution=merge-duplicates'}, body: {'name': name});

  static Future<bool> hasSignal(String name) async =>
      (await select('testsuite_signals', 'select=name&name=eq.${Uri.encodeComponent(name)}')).isNotEmpty;

  /// Everything the server holds right now (testsuite_state(), state.sql).
  static Future<Map<String, dynamic>> state() async => (await rpc('testsuite_state') as Map).cast<String, dynamic>();
}

/// A test person without a device acting by themselves, as the app would
/// for them: signed in with a login code, only their own rights (RLS) and
/// the same Edge Functions (chapter 5 on: Paul and Lena answer Anna).
class TestUser {
  TestUser._(this.email, this.id, this._token);

  final String email;
  final String id;
  final String _token;

  static Future<TestUser> signIn(String email) async {
    final code = await TestBackend.otp(email);
    final session = await TestBackend._send('POST', '/auth/v1/verify', body: {'type': 'email', 'email': email, 'token': code});
    return TestUser._(email, (session['user'] as Map)['id'] as String, session['access_token'] as String);
  }

  Map<String, String> get _h =>
      {'apikey': TestBackend._key, 'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};

  /// An Edge Function; its answer, refusals included ({error: ...}).
  Future<Map<String, dynamic>> edge(String fn, Map<String, Object?> body) async {
    TestBackend._guard();
    final res = await http.post(Uri.parse('${TestBackend.url}/functions/v1/$fn'), headers: _h, body: jsonEncode(body));
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  /// PostgREST as this person: e.g. patch('channel_membership_requests', 'id=eq.x', {...}).
  Future<List> patch(String table, String query, Map<String, Object?> body) => _rest('PATCH', '$table?$query', body);
  Future<List> insert(String table, Map<String, Object?> body) => _rest('POST', table, body);
  Future<List> delete(String table, String query) => _rest('DELETE', '$table?$query', null);
  Future<List> select(String table, String query) => _rest('GET', '$table?$query', null);

  Future<List> _rest(String method, String path, Object? body) async {
    TestBackend._guard();
    final req = http.Request(method, Uri.parse('${TestBackend.url}/rest/v1/$path'))
      ..headers.addAll({..._h, 'Prefer': 'return=representation'});
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode >= 300) throw StateError('$method $path als $email: ${res.statusCode} ${res.body}');
    return res.body.isEmpty ? const [] : jsonDecode(res.body) as List;
  }
}
