import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import 'app_texts.dart';
import 'offline.dart';

/// The app's language (2026-11-10): the phone's, unless chosen in
/// Einstellungen → Sprache. The server learns it (profiles.language) and
/// writes the person's notifications in it.
class AppLanguage {
  AppLanguage._();

  static const _key = 'app_language';

  /// The chosen language; null: like the phone.
  static final choice = ValueNotifier<String?>(null);

  static Future<void> load() async {
    final stored = await Offline.read(_key);
    choice.value = stored != null && SmileLanguages.codes.contains(stored) ? stored : null;
    AppTexts.locale = Locale(effective);
  }

  /// The phone's language, if Smile speaks it.
  static String get deviceLanguage => SmileLanguages.resolve(PlatformDispatcher.instance.locales);

  static String get effective => choice.value ?? deviceLanguage;

  static Future<void> choose(String? code) async {
    choice.value = code;
    AppTexts.locale = Locale(effective);
    await Offline.write(_key, code ?? '');
    await report();
  }

  static String? _reported;

  /// Tells the server, once per language and start (after sign-in too).
  static Future<void> report() async {
    final userId = supabase.auth.currentUser?.id;
    final language = effective;
    if (userId == null || _reported == '$userId/$language') return;
    try {
      await supabase.from('profiles').update({'language': language}).eq('user_id', userId);
      _reported = '$userId/$language';
    } catch (_) {
      // Next start, or the next change, tries again.
    }
  }
}
