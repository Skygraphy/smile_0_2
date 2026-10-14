import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/media_service.dart';

/// The whole photo, full screen (decided 2026-10-10 with the album's fixed
/// bubble shapes, which crop): tap a photo in the album, zoom with two
/// fingers, double-tap to zoom in and out. The album's small picture shows
/// at once while the full one loads; offline it stays when the full one
/// was never loaded.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required MediaItem this.item, this.onShowOnFrame, this.onFavorite}) : localBytes = null;

  /// A photo still on its way to the server (2026-10-12): straight from
  /// the phone.
  const PhotoViewerScreen.local({super.key, required Uint8List this.localBytes})
      : item = null,
        onShowOnFrame = null,
        onFavorite = null;

  /// "Jetzt am Frame zeigen" (2026-10-14) -- only when the album runs on a
  /// Frame the caller manages.
  final VoidCallback? onShowOnFrame;

  /// "Lieblingsbild für den Frame" (2026-10-14), same condition.
  final VoidCallback? onFavorite;

  final MediaItem? item;
  final Uint8List? localBytes;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final _zoom = TransformationController();

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
              icon: const Icon(SmileIcons.heart),
              tooltip: SmileTexts.of(context).favoriteFor,
              onPressed: widget.onFavorite,
            ),
          if (widget.onShowOnFrame != null)
            IconButton(
              icon: const Icon(SmileIcons.frame),
              tooltip: SmileTexts.of(context).showOnFrameNow,
              onPressed: widget.onShowOnFrame,
            ),
        ],
      ),
      body: GestureDetector(
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
    );
  }
}
