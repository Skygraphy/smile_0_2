import 'package:flutter/material.dart';

/// The "Blende & Lächeln" (aperture & smile) brand mark -- an aperture
/// ring above a smile arc, deliberately abstract rather than a literal
/// emoji face (see project_ui-redesign-concepts memory: an emoji smiley
/// would read as childish). Coordinates match the 48x48 concept the user
/// approved; also mirrored 1:1 as the Android adaptive launcher icon's
/// vector foreground (ic_launcher_foreground.xml), so keep them in sync
/// if this ever changes.
class SmileMark extends StatelessWidget {
  const SmileMark({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final markColor = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size.square(size),
      painter: _SmileMarkPainter(markColor),
    );
  }
}

class _SmileMarkPainter extends CustomPainter {
  _SmileMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(24 * scale, 19 * scale), 10.5 * scale, paint);

    final arc = Path()
      ..moveTo(13 * scale, 33.5 * scale)
      ..cubicTo(16.5 * scale, 37.5 * scale, 20 * scale, 39 * scale, 24 * scale, 39 * scale)
      ..cubicTo(28 * scale, 39 * scale, 31.5 * scale, 37.5 * scale, 35 * scale, 33.5 * scale);
    canvas.drawPath(arc, paint);
  }

  @override
  bool shouldRepaint(covariant _SmileMarkPainter oldDelegate) => oldDelegate.color != color;
}
