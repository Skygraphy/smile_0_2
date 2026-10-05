import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's single design-token source (ground rule: one primary color,
/// everything else derived from it -- see project_ui-redesign-concepts
/// memory). Deliberately NOT built via `ColorScheme.fromSeed`: Material 3's
/// seed algorithm tints every neutral surface with the seed's hue (its
/// "surface tint" mechanism), which is exactly the reddish cast the user
/// noticed in the dark backgrounds and explicitly doesn't want -- only
/// the primary/accent roles below use the brand color, every surface/
/// text/outline role is a true neutral gray or black.
class SmileTheme {
  SmileTheme._();

  /// PANTONE 16-1546 TCX "Living Coral" -- the app's one seed color.
  static const primary = Color(0xFFFF6F61);
  static const onPrimary = Color(0xFF3A1410);
  static const primaryContainer = Color(0xFF4A241D);
  static const onPrimaryContainer = Color(0xFFFFDAD3);

  /// True neutral grays/black -- no hue, so they never pick up a coral
  /// (or any other) tint. Also the source for the Android adaptive
  /// launcher icon's background (`ic_launcher_background` in both apps'
  /// colors.xml) -- keep those in sync with `surface` if this changes.
  static const surface = Color(0xFF121212);
  static const surfaceContainerLowest = Color(0xFF0A0A0A);
  static const surfaceContainerLow = Color(0xFF161616);
  static const surfaceContainer = Color(0xFF1C1C1C);
  static const surfaceContainerHigh = Color(0xFF262626);
  static const surfaceContainerHighest = Color(0xFF303030);
  static const onSurface = Color(0xFFECECEC);
  static const onSurfaceVariant = Color(0xFFB3B3B3);
  static const outline = Color(0xFF5C5C5C);
  static const outlineVariant = Color(0xFF3A3A3A);

  static ColorScheme get colorScheme => const ColorScheme.dark().copyWith(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        // Single-primary-color ground rule: no separate secondary/
        // tertiary brand hue, so any default Material widget that reads
        // these roles stays on-brand instead of falling back to
        // Flutter's default blue.
        secondary: primary,
        onSecondary: onPrimary,
        secondaryContainer: primaryContainer,
        onSecondaryContainer: onPrimaryContainer,
        tertiary: primary,
        onTertiary: onPrimary,
        tertiaryContainer: primaryContainer,
        onTertiaryContainer: onPrimaryContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        surfaceContainerLowest: surfaceContainerLowest,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        outline: outline,
        outlineVariant: outlineVariant,
        // Prevents M3's elevation-based tint overlay (Card/AppBar/Dialog
        // etc. normally blend `primary` into elevated surfaces) from
        // reintroducing the same unwanted coral cast a different way.
        surfaceTint: Colors.transparent,
      );

  static ThemeData get themeData {
    final scheme = colorScheme;
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        // Compact fields ground rule: less vertical padding than
        // Material's default, not a smaller font size.
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
