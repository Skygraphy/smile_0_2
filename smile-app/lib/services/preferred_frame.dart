import 'package:shared_preferences/shared_preferences.dart';

/// The Frame an album goes to with one tap on the Frame symbol in the album
/// (2026-10-18), kept on this phone. Null: ask each time (unless there is
/// only one Frame).
class PreferredFrame {
  PreferredFrame._();

  static const _key = 'preferred_frame_id';

  static Future<String?> get() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String? frameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (frameId == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, frameId);
      }
    } catch (_) {}
  }
}
