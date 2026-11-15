import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/media_service.dart';
import '../services/tips.dart';

/// The whole photo, full screen (decided 2026-10-10 with the album's fixed
/// bubble shapes, which crop): tap a photo in the album, zoom with two
/// fingers, double-tap to zoom in and out. The album's small picture shows
/// at once while the full one loads; offline it stays when the full one
/// was never loaded.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required MediaItem this.item,
    this.onShowOnFrame,
    this.onFavorite,
    this.favorite = false,
    this.onEditCaption,
    this.onZoom,
    this.bare = false,
    this.caption,
  })  : localBytes = null,
        localCaption = null;

  /// A photo still on its way to the server (2026-10-12): straight from
  /// the phone.
  const PhotoViewerScreen.local({super.key, required Uint8List this.localBytes, this.localCaption})
      : item = null,
        onShowOnFrame = null,
        onFavorite = null,
        onEditCaption = null,
        onZoom = null,
        bare = false,
        caption = null,
        favorite = false;

  /// "Jetzt am Frame zeigen" (2026-10-14) -- only when the album runs on a
  /// Frame the caller manages.
  final VoidCallback? onShowOnFrame;

  /// "Lieblingsbild für den Frame" (2026-10-14), same condition: marks or
  /// takes back; returns whether it is a Lieblingsbild afterwards (null:
  /// nothing changed).
  final Future<bool?> Function()? onFavorite;

  /// A Lieblingsbild already: the heart is filled, in coral.
  final bool favorite;

  /// "Titel bearbeiten" (2026-10-17), for the sender and the album's admins:
  /// returns the new title ('' = removed), null when nothing changed.
  final Future<String?> Function(String? current)? onEditCaption;

  final MediaItem? item;
  final Uint8List? localBytes;

  /// Zoomed in or not -- the swiping pager stops turning pages meanwhile.
  final ValueChanged<bool>? onZoom;

  /// Only the picture (and its title): the pager has the bar and buttons.
  final bool bare;

  /// The title to show when [bare] -- the pager keeps it up to date.
  final String? caption;

  /// The title of a photo still on its way (2026-10-17).
  final String? localCaption;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> with TickerProviderStateMixin {
  late bool _favorite = widget.favorite;
  late String? _caption = widget.item?.caption ?? widget.localCaption;
  final _zoom = TransformationController();
  final _captionKey = GlobalKey();
  final _heartKey = GlobalKey();
  bool _zoomed = false;

  // Zooming, more alive (2026-11-15, Ernst): a double tap glides in and
  // out; double tap and drag zooms with one finger; two fingers on the
  // photo stop the pager at once; pinching smaller than the screen gives
  // way with a black edge and springs back when the fingers let go.
  static const _maxScale = 8.0;
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

  /// The pager may not turn a page meanwhile.
  bool get _holding => _zoomed || _pointers.length >= 2 || _dragZoom || _shrink < 1;

  void _report() {
    final now = _holding;
    if (now == _reported) return;
    _reported = now;
    widget.onZoom?.call(now);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Tips.offerFirst(context, [
        if (widget.onEditCaption != null) (TipId.captionLater, _captionKey),
        if (widget.onFavorite != null) (TipId.favoriteHeart, _heartKey),
      ]);
    });
  }

  @override
  void dispose() {
    _glide.dispose();
    _spring.dispose();
    _zoom.dispose();
    super.dispose();
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
      if (_tapAt != null &&
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
      final target = (s0 * math.exp(dy / 180)).clamp(1.0, _maxScale);
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
  Widget build(BuildContext context) {
    final local = widget.localBytes;
    if (local != null) return _viewer(context, Image.memory(local, fit: BoxFit.contain));
    final item = widget.item!;
    final thumbnail = item.thumbnailUrl == null
        ? null
        : CachedNetworkImage(
            imageUrl: item.thumbnailUrl!,
            cacheKey: '${item.id}_grid',
            fit: BoxFit.contain,
            fadeInDuration: Duration.zero,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          );
    final full = item.displayUrl ?? item.thumbnailUrl;
    return _viewer(
      context,
      full == null
          ? (thumbnail ?? const SizedBox.shrink())
          : CachedNetworkImage(
              imageUrl: full,
              // Stable per photo -- the signed URL changes every time.
              cacheKey: '${item.id}_display',
              fit: BoxFit.contain,
              fadeInDuration: Duration.zero,
              placeholder: (_, _) => thumbnail ?? const Center(child: CircularProgressIndicator()),
              errorWidget: (_, _, _) => thumbnail ?? const SizedBox.shrink(),
            ),
    );
  }

  Widget _viewer(BuildContext context, Widget image) {
    if (widget.bare) return ColoredBox(color: Colors.black, child: _picture(image, widget.caption));
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: () => Navigator.of(context).pop()),
        actions: [
          if (widget.onFavorite != null)
            IconButton(
              key: _heartKey,
              icon: Icon(
                _favorite ? SmileIcons.heartFilled : SmileIcons.heart,
                color: _favorite ? SmileTheme.primary : null,
              ),
              tooltip: SmileTexts.of(context).favoriteFor,
              onPressed: () async {
                Tips.markUsed(TipId.favoriteHeart);
                final now = await widget.onFavorite!();
                if (now != null && mounted) setState(() => _favorite = now);
              },
            ),
          if (widget.onShowOnFrame != null)
            IconButton(
              icon: const Icon(SmileIcons.frame),
              tooltip: SmileTexts.of(context).showOnFrameNow,
              onPressed: widget.onShowOnFrame,
            ),
          if (widget.onEditCaption != null)
            IconButton(
              key: _captionKey,
              icon: const Icon(SmileIcons.caption),
              tooltip: SmileTexts.of(context).captionEdit,
              onPressed: () async {
                Tips.markUsed(TipId.captionLater);
                final now = await widget.onEditCaption!(_caption);
                if (now != null && mounted) setState(() => _caption = now.isEmpty ? null : now);
              },
            ),
        ],
      ),
      body: _picture(image, _caption),
    );
  }

  Widget _picture(Widget image, String? caption) => Stack(
        fit: StackFit.expand,
        children: [
          Listener(
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
                  maxScale: _maxScale,
                  // Unzoomed, a sideways swipe turns the page (MediaPagerScreen).
                  panEnabled: !_dragZoom && (_zoomed || widget.onZoom == null),
                  scaleEnabled: !_dragZoom,
                  child: SizedBox.expand(child: image),
                ),
              );
            }),
          ),
          if (caption != null) Positioned(left: 0, right: 0, bottom: 0, child: SmileViewerCaption(caption)),
        ],
      );
}

/// A photo's or video's title in full screen and in the phone's slideshow
/// (2026-10-17): the Frame's style -- a dark, see-through band across the
/// bottom of the picture, coral text, not too bold.
class SmileViewerCaption extends StatelessWidget {
  const SmileViewerCaption(this.caption, {super.key, this.maxLines = 4});

  final String caption;
  final int maxLines;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: double.infinity,
          color: Colors.black.withValues(alpha: 0.62),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.m, SmileSpacing.l, SmileSpacing.m),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SmileTheme.primary, fontSize: 18, fontWeight: FontWeight.w500, height: 1.35),
              ),
            ),
          ),
        ),
      );
}
