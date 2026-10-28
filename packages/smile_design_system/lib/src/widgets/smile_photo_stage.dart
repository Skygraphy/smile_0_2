import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// How a photo meets the screen (decided with the user 2026-10-16).
enum SmileFillMode {
  /// Always the whole photo.
  fit,

  /// Fills the screen when at most [SmilePhotoStage.autoFillTolerance] of
  /// it would be cut off -- else the whole photo, on a blurred, darkened
  /// copy of itself instead of black bars.
  auto,

  /// Always fills the screen.
  fill;

  static SmileFillMode parse(String? value) => switch (value) {
        'fit' => SmileFillMode.fit,
        'fill' => SmileFillMode.fill,
        _ => SmileFillMode.auto,
      };
}

/// One photo, full screen, for the Frame and the phone's slideshow alike:
/// [fillMode] decides between filling the screen and showing it whole, and
/// [slowZoom] lets it grow a little over [duration] ("Ken Burns").
class SmilePhotoStage extends StatefulWidget {
  const SmilePhotoStage({
    super.key,
    required this.image,
    this.fillMode = SmileFillMode.auto,
    this.slowZoom = true,
    this.duration = const Duration(seconds: 10),
  });

  final ImageProvider image;
  final SmileFillMode fillMode;
  final bool slowZoom;

  /// How long the photo is shown. The zoom always moves at the same speed
  /// (2026-10-17, like the photo memories of Google/Apple Photos): [zoomPerSecond]
  /// up to at most [maxZoom]. A shorter photo just grows less; a longer one
  /// "breathes" -- [breathAfter] in, as long out, again and again -- so it
  /// never grows too big and never stands still.
  final Duration duration;

  // Very slow (Ernst 2026-10-29: "ganz langsam"; was 0.008 and 0.08 in 10 s).
  static const zoomPerSecond = 0.002;
  static const maxZoom = 0.06;
  static const breathAfter = Duration(seconds: 30); // maxZoom / zoomPerSecond

  /// At most this share of the photo may be cut off for "auto" to fill.
  static const autoFillTolerance = 0.15;

  @override
  State<SmilePhotoStage> createState() => _SmilePhotoStageState();
}

class _SmilePhotoStageState extends State<SmilePhotoStage> with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(vsync: this);
  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _aspect;

  @override
  void initState() {
    super.initState();
    if (widget.slowZoom) _startZoom();
  }

  /// How far it grows at most.
  double get _amount => SmilePhotoStage.maxZoom;

  /// One motion for every photo, whatever its display time (Ernst
  /// 2026-10-29): it grows at the same slow speed for as long as it shows,
  /// up to [SmilePhotoStage.maxZoom], then breathes back and in again. A
  /// short photo just gets less far; a stopped one simply carries on --
  /// before, a photo stopped after its time stood still or jumped.
  void _startZoom() {
    _zoom.duration = SmilePhotoStage.breathAfter;
    _zoom.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(SmilePhotoStage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _resolve();
    if (old.slowZoom != widget.slowZoom) {
      if (widget.slowZoom) {
        _startZoom();
      } else {
        _zoom.stop();
        _zoom.value = 0;
      }
    }
  }

  /// Its size -- to know whether it fits the screen's shape.
  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _unlisten();
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      final aspect = info.image.width / info.image.height;
      if (mounted && aspect != _aspect) setState(() => _aspect = aspect);
    });
    stream.addListener(_listener!);
  }

  void _unlisten() {
    if (_listener != null) _stream?.removeListener(_listener!);
  }

  @override
  void dispose() {
    _unlisten();
    _zoom.dispose();
    super.dispose();
  }

  bool _fills(double screenAspect) {
    final aspect = _aspect;
    if (aspect == null) return widget.fillMode == SmileFillMode.fill;
    return switch (widget.fillMode) {
      SmileFillMode.fill => true,
      SmileFillMode.fit => false,
      // The share of the photo a "cover" would cut off.
      SmileFillMode.auto =>
        1 - (aspect < screenAspect ? aspect / screenAspect : screenAspect / aspect) <= SmilePhotoStage.autoFillTolerance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final screenAspect = constraints.maxWidth / constraints.maxHeight;
      final fills = _fills(screenAspect);
      final photo = AnimatedBuilder(
        animation: _zoom,
        builder: (context, child) => Transform.scale(
          scale: 1 + _amount * Curves.easeInOut.transform(_zoom.value),
          child: child,
        ),
        child: Image(image: widget.image, fit: fills ? BoxFit.cover : BoxFit.contain, gaplessPlayback: true),
      );
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            // Not the screen's shape: the free space shows the photo itself,
            // blurred and darkened -- not black bars (2026-10-16).
            if (!fills && widget.fillMode == SmileFillMode.auto && _aspect != null) ...[
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40, tileMode: TileMode.clamp),
                child: Image(image: widget.image, fit: BoxFit.cover, gaplessPlayback: true),
              ),
              const ColoredBox(color: Color(0x8C000000)),
            ],
            photo,
          ],
        ),
      );
    });
  }
}
