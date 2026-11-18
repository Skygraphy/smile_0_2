import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A quiet trace where a finger wipes over the Frame (Ernst 2026-11-18:
/// "dass sie auch weiß, dass sie gewischt hat" -- not kitschy): a few small,
/// half-transparent white grains fall softly out of the finger's path and
/// fade. Also when swiping does nothing on this level, so Oma still sees
/// the Frame noticed her. Lies over the slide, never takes touches.
class SwipeDust extends StatefulWidget {
  const SwipeDust({super.key});

  @override
  State<SwipeDust> createState() => SwipeDustState();
}

class _Grain {
  _Grain(this.x, this.y, this.vx, this.vy, this.r, this.decay);
  double x, y, vx, vy;
  final double r, decay;
  double life = 1;
}

class SwipeDustState extends State<SwipeDust> with SingleTickerProviderStateMixin {
  final _random = Random();
  final _grains = <_Grain>[];
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  Offset? _lastPoint;

  /// The finger touches down: the trace starts here.
  void start(Offset at) {
    _lastPoint = at;
    _emitAt(at);
  }

  /// The finger moved: grains along the way, evenly spaced.
  void moveTo(Offset at) {
    final from = _lastPoint ?? at;
    final distance = (at - from).distance;
    final steps = max(1, distance ~/ 8);
    for (var i = 1; i <= steps; i++) {
      _emitAt(Offset.lerp(from, at, i / steps)!);
    }
    _lastPoint = at;
  }

  void end() => _lastPoint = null;

  void _emitAt(Offset p) {
    if (_random.nextDouble() > 0.6) return;
    _grains.add(_Grain(
      p.dx + (_random.nextDouble() - 0.5) * 14,
      p.dy + (_random.nextDouble() - 0.5) * 14,
      (_random.nextDouble() - 0.5) * 0.3,
      _random.nextDouble() * 0.35 + 0.15,
      _random.nextDouble() * 1.6 + 1.0,
      0.008 + _random.nextDouble() * 0.006,
    ));
    // A long wipe on a big screen: keep it light.
    if (_grains.length > 400) _grains.removeRange(0, _grains.length - 400);
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    // Steps of one 60 Hz frame, whatever the screen runs at.
    final f = _last == Duration.zero ? 1.0 : ((elapsed - _last).inMicroseconds / 16667).clamp(0.2, 4.0);
    _last = elapsed;
    final height = context.size?.height ?? double.infinity;
    for (final g in _grains) {
      g.vy += 0.012 * f;
      g.x += g.vx * f;
      g.y += g.vy * f;
      g.life -= g.decay * f;
    }
    _grains.removeWhere((g) => g.life <= 0 || g.y > height + 10);
    if (_grains.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(child: CustomPaint(painter: _DustPainter(_grains), size: Size.infinite)),
      );
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.grains);
  final List<_Grain> grains;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in grains) {
      _paint.color = Colors.white.withValues(alpha: (g.life * 0.6).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(g.x, g.y), g.r, _paint);
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => true;
}
