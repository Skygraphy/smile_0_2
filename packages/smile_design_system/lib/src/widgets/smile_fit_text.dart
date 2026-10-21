import 'package:flutter/material.dart';

/// One line of text that gets smaller before it gets cut (decided
/// 2026-10-21, test suite): a long name first shrinks, step by step, down to
/// [minScale] of its size; only if it still doesn't fit does it end in "…".
class SmileFitText extends StatelessWidget {
  const SmileFitText(this.text, {super.key, this.style, this.minScale = 0.75, this.textAlign});

  final String text;
  final TextStyle? style;

  /// The smallest size, as a share of the normal one (never below 12).
  final double minScale;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final size = base.fontSize ?? 14;
    final smallest = (size * minScale).clamp(12.0, size);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, box) {
      var fontSize = size;
      if (box.maxWidth.isFinite) {
        bool fits(double s) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: base.copyWith(fontSize: s)),
            maxLines: 1,
            textDirection: direction,
            textScaler: scaler,
          )..layout();
          final ok = painter.width <= box.maxWidth;
          painter.dispose();
          return ok;
        }

        while (fontSize > smallest && !fits(fontSize)) {
          fontSize = (fontSize - 0.5).clamp(smallest, size);
        }
      }
      return Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: base.copyWith(fontSize: fontSize),
      );
    });
  }
}
