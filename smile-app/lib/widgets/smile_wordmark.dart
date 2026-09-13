import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "Smile" wordmark with the 'm' set in the brand's Living Coral
/// primary color -- the lockup the user approved alongside [SmileMark].
/// See project_ui-redesign-concepts memory.
class SmileWordmark extends StatelessWidget {
  const SmileWordmark({super.key, this.fontSize = 20, this.color, this.accentColor});

  final double fontSize;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? theme.colorScheme.onSurface,
      letterSpacing: -0.2,
    );
    final accent = base.copyWith(color: accentColor ?? theme.colorScheme.primary);
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'S'),
          TextSpan(text: 'm', style: accent),
          const TextSpan(text: 'ile'),
        ],
      ),
    );
  }
}
