import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/media_service.dart';
import '../services/tips.dart';
import 'photo_viewer_screen.dart';
import 'video_player_screen.dart';

/// Full screen, swiping through the album like WhatsApp (2026-10-28): left
/// to the next newer photo or video, right to the older one. Only the
/// picture moves -- the bar with its buttons stays and acts on the one
/// shown (Ernst). A zoomed photo pans instead of turning the page; a video
/// plays only while it is shown.
class MediaPagerScreen extends StatefulWidget {
  const MediaPagerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.isFavorite,
    this.onFavorite,
    this.onShowOnFrame,
    required this.canEditCaption,
    required this.onEditCaption,
  });

  /// Oldest first, as in the album.
  final List<MediaItem> items;
  final int initialIndex;

  /// A Lieblingsbild of a Frame already (the heart filled).
  final bool Function(MediaItem item) isFavorite;

  /// Marks or takes back; whether it is one afterwards (null: unchanged).
  /// Null when the album runs on no Frame of the caller.
  final Future<bool?> Function(MediaItem item)? onFavorite;
  final void Function(MediaItem item)? onShowOnFrame;
  final bool Function(MediaItem item) canEditCaption;

  /// The new title ('' = removed), null when nothing changed.
  final Future<String?> Function(MediaItem item, String? current) onEditCaption;

  @override
  State<MediaPagerScreen> createState() => _MediaPagerScreenState();
}

class _MediaPagerScreenState extends State<MediaPagerScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  /// Changed here meanwhile: hearts and titles, by media id.
  final Map<String, bool> _favorites = {};
  final Map<String, String?> _captions = {};

  MediaItem get _current => widget.items[_index];

  bool _favoriteOf(MediaItem item) => _favorites[item.id] ?? widget.isFavorite(item);

  String? _captionOf(MediaItem item) => _captions.containsKey(item.id) ? _captions[item.id] : item.caption;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final item = _current;
    final favorite = _favoriteOf(item);
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
              icon: Icon(favorite ? SmileIcons.heartFilled : SmileIcons.heart, color: favorite ? SmileTheme.primary : null),
              tooltip: t.favoriteFor,
              onPressed: () async {
                Tips.markUsed(TipId.favoriteHeart);
                final now = await widget.onFavorite!(item);
                if (now != null && mounted) setState(() => _favorites[item.id] = now);
              },
            ),
          if (widget.onShowOnFrame != null)
            IconButton(
              icon: const Icon(SmileIcons.frame),
              tooltip: t.showOnFrameNow,
              onPressed: () => widget.onShowOnFrame!(item),
            ),
          if (widget.canEditCaption(item))
            IconButton(
              icon: const Icon(SmileIcons.caption),
              tooltip: t.captionEdit,
              onPressed: () async {
                Tips.markUsed(TipId.captionLater);
                final now = await widget.onEditCaption(item, _captionOf(item));
                if (now != null && mounted) setState(() => _captions[item.id] = now.isEmpty ? null : now);
              },
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemBuilder: (context, i) {
          final page = widget.items[i];
          return page.isVideo
              ? VideoPlayerScreen(
                  key: ValueKey(page.id),
                  mediaId: page.id,
                  url: page.displayUrl,
                  caption: _captionOf(page),
                  active: i == _index,
                  bare: true,
                )
              : PhotoViewerScreen(
                  key: ValueKey(page.id),
                  item: page,
                  caption: _captionOf(page),
                  bare: true,
                  onZoom: (zoomed) {
                    if (i == _index && zoomed != _zoomed) setState(() => _zoomed = zoomed);
                  },
                );
        },
      ),
    );
  }
}
