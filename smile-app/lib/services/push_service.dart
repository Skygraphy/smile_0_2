import 'package:firebase_messaging/firebase_messaging.dart';

import '../main.dart';

/// Human-facing push notifications (join requests, approvals, new photos --
/// see the three server-side triggers this pairs with:
/// claim-channel-invite, decide-channel-join-request, _shared/media-fanout.ts).
/// Unlike smile-frame's PushService, these are real notification payloads
/// (title/body) the OS shows automatically whenever the app isn't in the
/// foreground -- no background-isolate handling needed here.
class PushService {
  Future<void> requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      // Best-effort -- a denied/unavailable permission just means no
      // notifications are shown, never a reason to block the rest of the app.
    }
  }

  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Idempotent -- safe to call on every app start/auth-state change for
  /// the current session; `unique(user_id, fcm_token)` just refreshes
  /// `updated_at` if already registered.
  Future<void> registerCurrentToken() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final token = await getToken();
    if (token == null) return;
    try {
      await supabase.from('user_push_tokens').upsert(
        {'user_id': userId, 'fcm_token': token, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        onConflict: 'user_id,fcm_token',
      );
    } catch (_) {
      // Best-effort -- the next app start/foreground retries.
    }
  }
}
