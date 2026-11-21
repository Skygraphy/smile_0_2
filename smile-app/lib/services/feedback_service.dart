import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import 'app_language.dart';
import 'edge_functions.dart';

/// "Hilfe & Feedback" (migrations/0113, 2026-11-20): a problem, an idea or
/// a question goes to the Verwaltung on smileapp.app (Edge Function
/// `feedback`, migrations/0114). The app only sends; reading and answering
/// happens on the website.
enum FeedbackKind { problem, idea, question }

class FeedbackService {
  FeedbackService._();
  static final instance = FeedbackService._();

  /// What the phone says about itself -- shown in the form before sending.
  Future<Map<String, String>> deviceInfo() async {
    final info = <String, String>{'language': AppLanguage.effective};
    try {
      final p = await PackageInfo.fromPlatform();
      info['app_version'] = '${p.version}+${p.buildNumber}';
    } catch (_) {}
    try {
      if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        info['device'] = '${a.manufacturer} ${a.model}';
        info['os'] = 'Android ${a.version.release}';
      }
    } catch (_) {}
    return info;
  }

  /// Puts the report into the outbox and tries to send it. True = arrived;
  /// false = no network right now, it goes out later by itself.
  Future<bool> send({
    required FeedbackKind kind,
    required String message,
    String? frameId,
    List<Uint8List> images = const [],
  }) async {
    final report = {
      'action': 'send',
      'client_id': '${DateTime.now().microsecondsSinceEpoch}-${message.hashCode}',
      'kind': kind.name,
      'message': message,
      'frame_id': frameId,
      'device_info': await deviceInfo(),
      'images': [for (final i in images) base64Encode(i)],
    };
    final file = await _outboxFile(report['client_id'] as String);
    await file.writeAsString(jsonEncode(report));
    return _trySend(file);
  }

  /// Sends whatever is still waiting (app start, back in the foreground).
  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      if (supabase.auth.currentSession == null) return;
      final dir = await _outboxDir();
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
      for (final f in files) {
        if (!await _trySend(f)) break;
      }
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }

  bool _flushing = false;

  Future<bool> _trySend(File file) async {
    try {
      final body = jsonDecode(await file.readAsString());
      final res = await invokeEdge('feedback', body: body);
      final data = res.data;
      if (data is Map && data['status'] == 'ok') {
        await file.delete();
        return true;
      }
      // Refused for good (invalid): never retried forever.
      if (data is Map && data['error'] is String && data['error'] != 'insert_failed' && data['error'] != 'image_upload_failed') {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Feedback: not sent yet: $e');
      return false;
    }
  }

  Future<Directory> _outboxDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/feedback_outbox');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _outboxFile(String clientId) async => File('${(await _outboxDir()).path}/$clientId.json');
}
