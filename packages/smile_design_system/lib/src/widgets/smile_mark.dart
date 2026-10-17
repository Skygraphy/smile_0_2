import 'package:flutter/material.dart';

/// The Smile symbol (decided 2026-10-17): a bold Inter "S", the same shape
/// as the app icon (ic_launcher_foreground.xml, white on coral there) and
/// the start screen (splash_mark.xml). Drawn as a path, so it never waits
/// for a font. The wordmark next to it stays "Smile" with a coral m.
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
    // Outline of Inter ExtraBold "S" in a 100x100 box, 90 high, centred.
    final s = size.width / 100;
    final path = Path()
      ..moveTo(50.88 * s, 95 * s)
      ..lineTo(50.88 * s, 95 * s)
      ..quadraticBezierTo(39.94 * s, 95 * s, 31.82 * s, 91.71 * s)
      ..quadraticBezierTo(23.71 * s, 88.41 * s, 19.18 * s, 81.71 * s)
      ..quadraticBezierTo(14.65 * s, 75 * s, 14.47 * s, 64.88 * s)
      ..lineTo(14.47 * s, 64.88 * s)
      ..lineTo(34.41 * s, 64.88 * s)
      ..quadraticBezierTo(34.71 * s, 69.12 * s, 36.74 * s, 72 * s)
      ..quadraticBezierTo(38.76 * s, 74.88 * s, 42.32 * s, 76.32 * s)
      ..quadraticBezierTo(45.88 * s, 77.76 * s, 50.65 * s, 77.76 * s)
      ..lineTo(50.65 * s, 77.76 * s)
      ..quadraticBezierTo(54.94 * s, 77.76 * s, 58.06 * s, 76.59 * s)
      ..quadraticBezierTo(61.18 * s, 75.41 * s, 62.85 * s, 73.29 * s)
      ..quadraticBezierTo(64.53 * s, 71.18 * s, 64.53 * s, 68.35 * s)
      ..lineTo(64.53 * s, 68.35 * s)
      ..quadraticBezierTo(64.53 * s, 65.82 * s, 62.97 * s, 64.06 * s)
      ..quadraticBezierTo(61.41 * s, 62.29 * s, 58.29 * s, 60.94 * s)
      ..quadraticBezierTo(55.18 * s, 59.59 * s, 50.35 * s, 58.53 * s)
      ..lineTo(50.35 * s, 58.53 * s)
      ..lineTo(41.06 * s, 56.35 * s)
      ..quadraticBezierTo(29.71 * s, 53.76 * s, 23.24 * s, 47.88 * s)
      ..quadraticBezierTo(16.76 * s, 42 * s, 16.76 * s, 32.12 * s)
      ..lineTo(16.76 * s, 32.12 * s)
      ..quadraticBezierTo(16.76 * s, 24 * s, 21.18 * s, 17.88 * s)
      ..quadraticBezierTo(25.59 * s, 11.76 * s, 33.26 * s, 8.38 * s)
      ..quadraticBezierTo(40.94 * s, 5 * s, 50.88 * s, 5 * s)
      ..lineTo(50.88 * s, 5 * s)
      ..quadraticBezierTo(61.06 * s, 5 * s, 68.53 * s, 8.44 * s)
      ..quadraticBezierTo(76 * s, 11.88 * s, 80.12 * s, 18.03 * s)
      ..quadraticBezierTo(84.24 * s, 24.18 * s, 84.35 * s, 32.29 * s)
      ..lineTo(84.35 * s, 32.29 * s)
      ..lineTo(64.41 * s, 32.29 * s)
      ..quadraticBezierTo(64 * s, 27.53 * s, 60.53 * s, 24.88 * s)
      ..quadraticBezierTo(57.06 * s, 22.24 * s, 50.82 * s, 22.24 * s)
      ..lineTo(50.82 * s, 22.24 * s)
      ..quadraticBezierTo(46.71 * s, 22.24 * s, 43.88 * s, 23.32 * s)
      ..quadraticBezierTo(41.06 * s, 24.41 * s, 39.65 * s, 26.32 * s)
      ..quadraticBezierTo(38.24 * s, 28.24 * s, 38.24 * s, 30.71 * s)
      ..lineTo(38.24 * s, 30.71 * s)
      ..quadraticBezierTo(38.24 * s, 33.41 * s, 39.82 * s, 35.26 * s)
      ..quadraticBezierTo(41.41 * s, 37.12 * s, 44.35 * s, 38.35 * s)
      ..quadraticBezierTo(47.29 * s, 39.59 * s, 51.18 * s, 40.47 * s)
      ..lineTo(51.18 * s, 40.47 * s)
      ..lineTo(58.76 * s, 42.24 * s)
      ..quadraticBezierTo(65.12 * s, 43.59 * s, 70.09 * s, 45.91 * s)
      ..quadraticBezierTo(75.06 * s, 48.24 * s, 78.5 * s, 51.47 * s)
      ..quadraticBezierTo(81.94 * s, 54.71 * s, 83.74 * s, 58.94 * s)
      ..quadraticBezierTo(85.53 * s, 63.18 * s, 85.53 * s, 68.41 * s)
      ..lineTo(85.53 * s, 68.41 * s)
      ..quadraticBezierTo(85.53 * s, 76.71 * s, 81.38 * s, 82.68 * s)
      ..quadraticBezierTo(77.24 * s, 88.65 * s, 69.5 * s, 91.82 * s)
      ..quadraticBezierTo(61.76 * s, 95 * s, 50.88 * s, 95 * s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SmileMarkPainter oldDelegate) => oldDelegate.color != color;
}
