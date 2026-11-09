import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Photos and videos shared to Smile from another app (2026-11-09, like
/// WhatsApp): Android copies them into Smile's cache (ShareIn.kt), HomeShell
/// takes them as soon as someone is signed in and opens "Senden an …".
class ShareIn {
  ShareIn._();

  static const _channel = MethodChannel('smile/share_in');

  /// Shared and not yet sent anywhere.
  static final pending = ValueNotifier<List<XFile>?>(null);

  static bool _started = false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'available') await _take();
    });
    await _take();
  }

  static Future<void> _take() async {
    try {
      final paths = await _channel.invokeListMethod<String>('take');
      if (paths != null && paths.isNotEmpty) pending.value = [for (final p in paths) XFile(p)];
    } catch (_) {}
  }

  /// Taken: not offered again.
  static void clear() => pending.value = null;
}
