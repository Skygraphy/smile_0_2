import 'package:flutter/foundation.dart';
import 'package:smile_design_system/smile_design_system.dart';

/// The Frame's language (2026-11-10): set in the app ("Sprache am Frame",
/// frames.language), else the tablet's.
class FrameLanguage {
  FrameLanguage._();

  static final code = ValueNotifier<String>(SmileLanguages.resolve(PlatformDispatcher.instance.locales));

  /// From the Frame's settings; null: like the tablet.
  static void apply(String? chosen) {
    final next = chosen != null && SmileLanguages.codes.contains(chosen)
        ? chosen
        : SmileLanguages.resolve(PlatformDispatcher.instance.locales);
    if (code.value != next) code.value = next;
  }
}
