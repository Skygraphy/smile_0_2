import 'package:flutter/widgets.dart';
import 'package:smile_design_system/smile_design_system.dart';

/// The texts in the app's current language for code without a BuildContext
/// -- the services' exceptions, the notification channel (2026-11-10: every
/// text in the language files). [locale] follows the app's language.
class AppTexts {
  AppTexts._();

  static Locale locale = const Locale('de');

  static SmileTexts get current => lookupSmileTexts(locale);
}
