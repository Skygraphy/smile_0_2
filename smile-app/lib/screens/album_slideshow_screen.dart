import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:video_player/video_player.dart';

import '../services/media_service.dart';
import '../services/video_cache.dart';

/// Any album as a slideshow on the phone, like on a Frame (decided
/// 2026-10-11) -- with the person's own sign-in, no Frame involved (and no
/// Frame code: app and Frame stay separate). Photos change every few
/// seconds, videos play to the end with sound; swipe to go on by hand, tap
/// for the name and closing.
class AlbumSlideshowScreen extends StatefulWidget {
  const AlbumSlideshowScreen({super.key, required this.albumName, required this.items});

  final String albumName;
  /// Ready photos and videos, in the order they are shown.
  final List<MediaItem> items;

  @override
  State<AlbumSlideshowScreen> createState() => _AlbumSlideshowScreenState();
}

class _AlbumSlideshowScreenState extends State<AlbumSlideshowScreen> {
  static const _photoDuration = Duration(seconds: 8);
  static const _screen = MethodChannel('smile/screen');

  final _pages = PageController();
  int _index = 0;
  Timer? _next;
  bool _chrome = false;
  Timer? _hideChrome;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_screen.invokeMethod<void>('keepOn', true).catchError((Object _) {}));
    _schedule();
  }

  @override
  void dispose() {
    _next?.cancel();
    _hideChrome?.cancel();
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    unawaited(_screen.invokeMethod<void>('keepOn', false).catchError((Object _) {}));
    super.dispose();
  }

  MediaItem get _current => widget.items[_index];

  /// Photos move on by time; a video moves on when it has ended.
  void _schedule() {
    _next?.cancel();
    if (widget.items.isEmpty || _current.isVideo) return;
    _next = Timer(_photoDuration, _advance);
  }

  void _advance() {
    if (!mounted || widget.items.length < 2) return;
    final next = (_index + 1) % widget.items.length;
    if (next == 0) {
      _pages.jumpToPage(0);
    } else {
      unawaited(_pages.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut));
    }
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    _hideChrome?.cancel();
    if (_chrome) _hideChrome = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _chrome = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleChrome,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _schedule();
              },
              itemBuilder: (context, i) {
                final item = items[i];
                if (item.isVideo) {
                  return _VideoSlide(
                    key: ValueKey(item.id),
                    item: item,
                    active: i == _index,
                    onEnded: () {
                      if (i == _index) _advance();
                    },
                  );
                }
                return CachedNetworkImage(
                  cacheKey: '${item.id}_display',
                  imageUrl: item.displayUrl ?? '',
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                  placeholder: (context, url) => item.thumbnailUrl == null
                      ? const SizedBox.shrink()
                      : CachedNetworkImage(cacheKey: '${item.id}_grid', imageUrl: item.thumbnailUrl!, fit: BoxFit.contain),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                );
              },
            ),
            AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_chrome,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(SmileSpacing.m),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton.filledTonal(
                            icon: const Icon(SmileIcons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        if (items.isNotEmpty)
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(SmileRadius.m),
                              ),
                              child: Text(
                                [widget.albumName, if (_current.senderDisplayName != null) _current.senderDisplayName!].join(' · '),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A video in the slideshow: from the phone if it is there, else streamed;
/// plays while its page is shown, with sound, and says when it has ended.
class _VideoSlide extends StatefulWidget {
  const _VideoSlide({super.key, required this.item, required this.active, required this.onEnded});

  final MediaItem item;
  final bool active;
  final VoidCallback onEnded;

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  VideoPlayerController? _controller;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final local = await VideoCache.cached(widget.item.id);
    final url = widget.item.displayUrl;
    if (local == null && url == null) {
      widget.onEnded();
      return;
    }
    final controller =
        local != null ? VideoPlayerController.file(File(local.path)) : VideoPlayerController.networkUrl(Uri.parse(url!));
    if (local == null) unawaited(VideoCache.download(widget.item.id, url!));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      // Can't be played right now: just go on with the next one.
      if (mounted && widget.active) widget.onEnded();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(() {
      final v = controller.value;
      if (!_ended && v.isInitialized && v.duration > Duration.zero && v.position >= v.duration) {
        _ended = true;
        widget.onEnded();
      }
    });
    setState(() => _controller = controller);
    if (widget.active) await controller.play();
  }

  @override
  void didUpdateWidget(covariant _VideoSlide old) {
    super.didUpdateWidget(old);
    final controller = _controller;
    if (controller == null || old.active == widget.active) return;
    if (widget.active) {
      _ended = false;
      unawaited(controller.seekTo(Duration.zero).then((_) => controller.play()));
    } else {
      unawaited(controller.pause());
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      final poster = widget.item.thumbnailUrl;
      return poster == null
          ? const Center(child: CircularProgressIndicator())
          : CachedNetworkImage(cacheKey: '${widget.item.id}_grid', imageUrl: poster, fit: BoxFit.contain);
    }
    return Center(
      child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
    );
  }
}
