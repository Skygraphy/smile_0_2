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
  })  : localBytes = null,
        localCaption = null;

  /// A photo still on its way to the server (2026-10-12): straight from
  /// the phone.
  const PhotoViewerScreen.local({super.key, required Uint8List this.localBytes, this.localCaption})
      : item = null,
        onShowOnFrame = null,
        onFavorite = null,
        onEditCaption = null,
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

  /// The title of a photo still on its way (2026-10-17).
  final String? localCaption;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late bool _favorite = widget.favorite;
  late String? _caption = widget.item?.caption ?? widget.localCaption;
  final _zoom = TransformationController();
  final _captionKey = GlobalKey();
  final _heartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
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
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _zoom.value = Matrix4.identity();
    } else {
      // 2.5x around the tapped point.
      const scale = 2.5;
      final p = details.localPosition;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
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

  TapDownDetails? _lastTap;

  Widget _viewer(BuildContext context, Widget image) {
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: (d) => _lastTap = d,
            onDoubleTap: () {
              if (_lastTap != null) _toggleZoom(_lastTap!);
            },
            child: InteractiveViewer(
              transformationController: _zoom,
              minScale: 1,
              maxScale: 5,
              child: SizedBox.expand(child: image),
            ),
          ),
          if (_caption != null) Positioned(left: 0, right: 0, bottom: 0, child: SmileViewerCaption(_caption!)),
        ],
      ),
    );
  }
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
