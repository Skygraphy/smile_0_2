import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A photo you can zoom (2026-11-15, Ernst), the same in the app's full
/// screen view and on the Frame: two fingers zoom at once (the page turning
/// around it waits meanwhile), pinching smaller than the screen gives way
/// with a black edge and springs back when the fingers let go. With
/// [doubleTap] a double tap glides in and out, and double tap and drag
/// zooms with one finger (down = in, up = out).
class SmileZoomView extends StatefulWidget {
  const SmileZoomView({
    super.key,
    required this.child,
    this.doubleTap = true,
    this.panUnzoomed = false,
    this.onHold,
    this.maxScale = 8,
    this.zoomOutWhen,
  });

  final Widget child;
  final bool doubleTap;

  /// One finger moves the photo even unzoomed -- off where a sideways
  /// swipe turns the page.
  final bool panUnzoomed;

  /// Zoomed in, or fingers on it zooming: whatever turns pages around it
  /// should wait.
  final ValueChanged<bool>? onHold;
  final double maxScale;

  /// Glides back to the whole photo whenever this fires.
  final Listenable? zoomOutWhen;

  @override
  State<SmileZoomView> createState() => SmileZoomViewState();
}

class SmileZoomViewState extends State<SmileZoomView> with TickerProviderStateMixin {
  final _zoom = TransformationController();
  bool _zoomed = false;

  late final AnimationController _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
    ..addListener(() => _zoom.value = _glideTween.transform(Curves.easeOutCubic.transform(_glide.value)));
  Matrix4Tween _glideTween = Matrix4Tween(begin: Matrix4.identity(), end: Matrix4.identity());
  late final AnimationController _spring = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))
    ..addListener(() => setState(() => _shrink = _springFrom + (1 - _springFrom) * Curves.easeOutCubic.transform(_spring.value)))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _report();
    });
  double _springFrom = 1;

  /// Below 1 while pinched smaller than the screen.
  double _shrink = 1;
  Size _size = Size.zero;

  final Map<int, Offset> _pointers = {};
  double? _pinchSpan;
  double _pinchScale = 1;
  bool _multi = false;
  Offset? _downPos;
  DateTime? _downAt;
  DateTime? _tapAt;
  Offset? _tapPos;
  bool _dragZoom = false;
  bool _dragMoved = false;
  Offset _dragStart = Offset.zero;
  Matrix4 _dragMatrix = Matrix4.identity();
  bool _reported = false;

  /// Zoomed in right now.
  bool get zoomed => _zoomed;

  bool get _holding => _zoomed || _pointers.length >= 2 || _dragZoom || _shrink < 1;

  void _report() {
    final now = _holding;
    if (now == _reported) return;
    _reported = now;
    widget.onHold?.call(now);
  }

  void _zoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    _report();
  }

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_zoomChanged);
    widget.zoomOutWhen?.addListener(zoomOut);
  }

  @override
  void didUpdateWidget(SmileZoomView old) {
    super.didUpdateWidget(old);
    if (old.zoomOutWhen != widget.zoomOutWhen) {
      old.zoomOutWhen?.removeListener(zoomOut);
      widget.zoomOutWhen?.addListener(zoomOut);
    }
  }

  @override
  void dispose() {
    widget.zoomOutWhen?.removeListener(zoomOut);
    _glide.dispose();
    _spring.dispose();
    _zoom.dispose();
    super.dispose();
  }

  /// Glides back to the whole photo.
  void zoomOut() {
    if (_zoomed) _glideTo(Matrix4.identity());
  }

  /// [m] scaled by [k] around [focal], kept inside the screen.
  Matrix4 _scaledAround(Matrix4 m, double k, Offset focal) {
    final next = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(m);
    final s = next.getMaxScaleOnAxis();
    final t = next.getTranslation();
    next.setTranslationRaw(
      t.x.clamp(_size.width - _size.width * s, 0.0),
      t.y.clamp(_size.height - _size.height * s, 0.0),
      0,
    );
    return next;
  }

  void _glideTo(Matrix4 target) {
    _glideTween = Matrix4Tween(begin: _zoom.value.clone(), end: target);
    _glide.forward(from: 0);
  }

  void _toggleZoom(Offset at) {
    _glideTo(_zoomed ? Matrix4.identity() : _scaledAround(Matrix4.identity(), 2.5, at));
  }

  double get _span {
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_glide.isAnimating) _glide.stop();
    if (_pointers.length == 1) {
      final now = DateTime.now();
      _multi = false;
      _downPos = e.localPosition;
      _downAt = now;
      // The second tap of a double tap: zoom by dragging, or glide on lift.
      if (widget.doubleTap &&
          _tapAt != null &&
          now.difference(_tapAt!) < const Duration(milliseconds: 300) &&
          (e.localPosition - _tapPos!).distance < 48) {
        _tapAt = null;
        _dragStart = e.localPosition;
        _dragMatrix = _zoom.value.clone();
        _dragMoved = false;
        setState(() => _dragZoom = true);
      }
    } else if (_pointers.length == 2) {
      _multi = true;
      _tapAt = null;
      if (_spring.isAnimating) _spring.stop();
      _pinchSpan = _span;
      _pinchScale = _zoom.value.getMaxScaleOnAxis() * _shrink;
      setState(() => _dragZoom = false);
    }
    _report();
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_dragZoom) {
      final dy = e.localPosition.dy - _dragStart.dy;
      if (dy.abs() > 6) _dragMoved = true;
      if (!_dragMoved) return;
      final s0 = _dragMatrix.getMaxScaleOnAxis();
      // Down zooms in, up zooms out.
      final target = (s0 * math.exp(dy / 180)).clamp(1.0, widget.maxScale);
      _zoom.value = _scaledAround(_dragMatrix, target / s0, _dragStart);
    } else if (_pointers.length >= 2 && _pinchSpan != null && _pinchSpan! > 0) {
      final wanted = _pinchScale * _span / _pinchSpan!;
      // Gives way, but less and less (rubber band).
      final shrink = wanted < 1 ? math.max(0.5, 1 - (1 - wanted) * 0.7) : 1.0;
      if (shrink != _shrink) setState(() => _shrink = shrink);
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_dragZoom && _pointers.isEmpty) {
      if (!_dragMoved) _toggleZoom(_dragStart);
      setState(() => _dragZoom = false);
    } else if (_pointers.isEmpty && !_multi && e is PointerUpEvent) {
      final quick = _downAt != null && DateTime.now().difference(_downAt!) < const Duration(milliseconds: 250);
      final still = _downPos != null && (e.localPosition - _downPos!).distance < 20;
      if (quick && still) {
        _tapAt = DateTime.now();
        _tapPos = e.localPosition;
      }
    }
    if (_pointers.length < 2) {
      _pinchSpan = null;
      if (_shrink < 1 && !_spring.isAnimating) {
        _springFrom = _shrink;
        _spring.forward(from: 0);
      }
    }
    _report();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: LayoutBuilder(builder: (context, box) {
          _size = box.biggest;
          return Transform.scale(
            scale: _shrink,
            child: InteractiveViewer(
              transformationController: _zoom,
              minScale: 1,
              maxScale: widget.maxScale,
              panEnabled: !_dragZoom && (_zoomed || widget.panUnzoomed),
              scaleEnabled: !_dragZoom,
              child: SizedBox.expand(child: widget.child),
            ),
          );
        }),
      );
}
