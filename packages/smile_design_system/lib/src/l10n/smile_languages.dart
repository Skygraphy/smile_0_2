import 'package:flutter/widgets.dart';

import 'smile_texts.dart';

/// The languages Smile speaks (2026-11-10), each named in itself -- the way
/// language pickers show them, so everyone finds their own.
class SmileLanguages {
  SmileLanguages._();

  static const _names = {
    'de': 'Deutsch',
    'en': 'English',
    'fr': 'Français',
    'it': 'Italiano',
    'es': 'Español',
  };

  /// Every language with a language file, e.g. ['de'].
  static List<String> get codes => [for (final l in SmileTexts.supportedLocales) l.languageCode];

  static String nameOf(String code) => _names[code] ?? code;

  /// The first of [wanted] (e.g. the device's languages) Smile speaks;
  /// German otherwise.
  static String resolve(Iterable<Locale> wanted) {
    for (final locale in wanted) {
      if (codes.contains(locale.languageCode)) return locale.languageCode;
    }
    return 'de';
  }
}
