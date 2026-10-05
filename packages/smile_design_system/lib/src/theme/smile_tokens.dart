/// Spacing, radius and icon-size tokens shared by both apps. Compact by
/// ground rule (WhatsApp density, not Material's roomier defaults).
class SmileSpacing {
  SmileSpacing._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}

class SmileRadius {
  SmileRadius._();

  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 22;
  static const double pill = 999;
}

class SmileIconSize {
  SmileIconSize._();

  /// Role badges and inline hints next to text.
  static const double badge = 14;
  static const double small = 18;

  /// Object icons inside list rows.
  static const double list = 22;
  static const double nav = 24;

  /// Big object icon at the top of an info page.
  static const double hero = 40;
}
