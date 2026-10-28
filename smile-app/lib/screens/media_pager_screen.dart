import 'package:flutter/material.dart';

import '../services/media_service.dart';

/// Full screen, swiping through the album like WhatsApp (2026-10-28): left
/// to the next newer photo or video, right to the older one. A zoomed photo
/// pans instead of turning the page; a video plays only while it is shown.
class MediaPagerScreen extends StatefulWidget {
  const MediaPagerScreen({super.key, required this.items, required this.initialIndex, required this.page});

  /// Oldest first, as in the album.
  final List<MediaItem> items;
  final int initialIndex;

  /// One page: the photo or video viewer for [item]; [active] while it is
  /// the one shown; [onZoom] tells whether a photo is zoomed in.
  final Widget Function(MediaItem item, bool active, ValueChanged<bool> onZoom) page;

  @override
  State<MediaPagerScreen> createState() => _MediaPagerScreenState();
}

class _MediaPagerScreenState extends State<MediaPagerScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
        controller: _controller,
        physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemBuilder: (context, i) => widget.page(
          widget.items[i],
          i == _index,
          (zoomed) {
            if (i == _index && zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
        ),
      );
}
