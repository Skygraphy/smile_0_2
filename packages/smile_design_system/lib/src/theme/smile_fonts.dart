import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inter (google_fonts/, Inter 4.1) and Phosphor are bundled (2026-11-10):
/// no font is ever fetched from Google at run time -- nothing goes to Google
/// for it, and a Frame without network on its first start still shows Inter.
/// Both licences appear under "Open-Source-Lizenzen".
class SmileFonts {
  SmileFonts._();

  static bool _done = false;

  /// Once, right after WidgetsFlutterBinding.ensureInitialized().
  static void setUp() {
    if (_done) return;
    _done = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(
        const ['Inter'],
        await rootBundle.loadString('packages/smile_design_system/google_fonts/OFL.txt'),
      );
      yield LicenseEntryWithLineBreaks(
        const ['Phosphor Icons'],
        await rootBundle.loadString('packages/smile_design_system/fonts/PHOSPHOR_LICENSE'),
      );
    });
  }
}
