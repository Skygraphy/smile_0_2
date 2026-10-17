import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'photo_viewer_screen.dart' show SmileViewerCaption;
import 'package:video_player/video_player.dart';

import '../services/media_service.dart';
import '../services/video_cache.dart';

/// How the phone's slideshow plays (decided 2026-10-16: the same settings
/// as a Frame on its highest level, kept on this phone only).
class SlideshowPrefs {
  const SlideshowPrefs({
    this.seconds = 10,
    this.order = 'oldest',
    this.orientation = 'auto',
    this.videoLength = 'full',
    this.fillMode = 'auto',
    this.slowZoom = true,
    this.sound = true,
    this.captions = true,
  });

  final int seconds;

  /// 'newest' | 'oldest' | 'shuffle'
  final String order;

  /// 'auto' | 'portrait' | 'landscape' -- only while the slideshow plays.
  final String orientation;

  /// 'full' | 'photo' | 'none' (no videos)
  final String videoLength;

  /// 'fit' | 'auto' | 'fill'
  final String fillMode;
  final bool slowZoom;
  final bool sound;

  /// Show a photo's title at the bottom (2026-10-17).
  final bool captions;

  static const _key = 'phone_slideshow';

  static Future<SlideshowPrefs> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return const SlideshowPrefs();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return SlideshowPrefs(
        seconds: j['seconds'] as int? ?? 10,
        order: j['order'] as String? ?? 'oldest',
        orientation: j['orientation'] as String? ?? 'auto',
        videoLength: j['video_length'] as String? ?? 'full',
        fillMode: j['fill_mode'] as String? ?? 'auto',
        slowZoom: j['slow_zoom'] as bool? ?? true,
        sound: j['sound'] as bool? ?? true,
        captions: j['captions'] as bool? ?? true,
      );
    } catch (_) {
      return const SlideshowPrefs();
    }
  }

  Future<void> save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode({
          'seconds': seconds,
          'order': order,
          'orientation': orientation,
          'video_length': videoLength,
          'fill_mode': fillMode,
          'slow_zoom': slowZoom,
          'sound': sound,
          'captions': captions,
        }),
      );
    } catch (_) {}
  }

  SlideshowPrefs copyWith({
    int? seconds,
    String? order,
    String? orientation,
    String? videoLength,
    String? fillMode,
    bool? slowZoom,
    bool? sound,
    bool? captions,
  }) =>
      SlideshowPrefs(
        seconds: seconds ?? this.seconds,
        order: order ?? this.order,
        orientation: orientation ?? this.orientation,
        videoLength: videoLength ?? this.videoLength,
        fillMode: fillMode ?? this.fillMode,
        slowZoom: slowZoom ?? this.slowZoom,
        sound: sound ?? this.sound,
        captions: captions ?? this.captions,
      );

  /// For Android (MainActivity.setOrientation): "Automatisch" turns with
  /// the phone even when its auto-rotate is off (2026-10-17).
  String get androidOrientation => switch (orientation) {
        'portrait' => 'portrait',
        'landscape' => 'landscape',
        _ => 'sensor',
      };
}

/// Any album as a slideshow on the phone, like on a Frame (decided
/// 2026-10-11) -- with the person's own sign-in, no Frame involved (and no
/// Frame code: app and Frame stay separate). Photos change by the set
/// time, videos play to the end (or as long as a photo), swipe to go on by
/// hand, tap for the name, the settings and closing.
class AlbumSlideshowScreen extends StatefulWidget {
  const AlbumSlideshowScreen({super.key, required this.albumName, required this.items});

  final String albumName;

  /// Ready photos and videos, newest first.
  final List<MediaItem> items;

  @override
  State<AlbumSlideshowScreen> createState() => _AlbumSlideshowScreenState();
}

class _AlbumSlideshowScreenState extends State<AlbumSlideshowScreen> {
  static const _screen = MethodChannel('smile/screen');

  final _pages = PageController();
  int _index = 0;
  Timer? _next;
  bool _chrome = false;
  Timer? _hideChrome;
  SlideshowPrefs _prefs = const SlideshowPrefs();
  List<MediaItem> _items = const [];
  int _shuffleSeed = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _items = _ordered(widget.items);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(_screen.invokeMethod<void>('keepOn', true).catchError((Object _) {}));
    unawaited(SlideshowPrefs.load().then((prefs) {
      if (!mounted) return;
      _applyPrefs(prefs);
    }));
    _schedule();
  }

  @override
  void dispose() {
    _next?.cancel();
    _hideChrome?.cancel();
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // The rest of the app follows the system's rotation again.
    unawaited(_screen.invokeMethod<void>('orientation', 'system').catchError((Object _) {}));
    unawaited(_screen.invokeMethod<void>('keepOn', false).catchError((Object _) {}));
    super.dispose();
  }

  void _applyPrefs(SlideshowPrefs prefs) {
    final reorder = prefs.order != _prefs.order || (prefs.videoLength == 'none') != (_prefs.videoLength == 'none');
    setState(() {
      _prefs = prefs;
      if (reorder) _items = _ordered(widget.items);
    });
    unawaited(_screen.invokeMethod<void>('orientation', prefs.androidOrientation).catchError((Object _) {}));
    _schedule();
  }

  List<MediaItem> _ordered(List<MediaItem> items) {
    // "Keine Videos" (2026-10-18): photos only.
    final list = [for (final i in items) if (_prefs.videoLength != 'none' || !i.isVideo) i];
    switch (_prefs.order) {
      case 'newest':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'shuffle':
        list
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt))
          ..shuffle(Random(_shuffleSeed));
      default:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return list;
  }

  /// Endless: page [_index] shows item _index % length -- from the last
  /// one it simply goes on to the first, as softly as everywhere else
  /// (2026-10-12: the jump back to the start was abrupt).
  MediaItem get _current => _items[_index % _items.length];

  /// Photos move on by time; a video when it has ended -- or by time too,
  /// when videos may only last as long as a photo.
  void _schedule() {
    _next?.cancel();
    if (_items.isEmpty) return;
    if (_current.isVideo && _prefs.videoLength != 'photo') return;
    _next = Timer(Duration(seconds: _prefs.seconds), _advance);
  }

  void _advance() {
    if (!mounted || _items.length < 2) return;
    unawaited(_pages.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut));
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    _keepChrome();
  }

  void _keepChrome() {
    _hideChrome?.cancel();
    if (_chrome) _hideChrome = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _chrome = false) : null);
  }

  Future<void> _openSettings() async {
    _hideChrome?.cancel();
    final t = SmileTexts.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (context) => StatefulBuilder(builder: (context, setSheet) {
        final scheme = Theme.of(context).colorScheme;
        void set(SlideshowPrefs prefs) {
          setSheet(() {});
          _applyPrefs(prefs);
          unawaited(prefs.save());
        }

        Widget label(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.m, SmileSpacing.l, SmileSpacing.s),
              child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
            );
        Widget chips<T>(List<(T, String)> options, T selected, SlideshowPrefs Function(T) change) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l),
              child: Wrap(
                spacing: SmileSpacing.s,
                runSpacing: SmileSpacing.s,
                children: [
                  for (final (value, name) in options)
                    ChoiceChip(
                      label: Text(name),
                      selected: value == selected,
                      onSelected: value == selected ? null : (_) => set(change(value)),
                    ),
                ],
              ),
            );
        final p = _prefs;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: SmileSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l),
                  child: Text(t.slideshowSettings, style: Theme.of(context).textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 4, SmileSpacing.l, 0),
                  child: Text(t.slideshowSettingsHint, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ),
                label(t.displayTime),
                chips([for (final s in const [5, 10, 20, 60]) (s, s == 60 ? t.oneMinute : t.secondsValue(s))], p.seconds,
                    (v) => p.copyWith(seconds: v)),
                label(t.playOrder),
                chips([('newest', t.orderNewest), ('oldest', t.orderOldest), ('shuffle', t.orderShuffle)], p.order,
                    (v) => p.copyWith(order: v)),
                label(t.orientationLabel),
                chips([('auto', t.orientAuto), ('portrait', t.orientPortrait), ('landscape', t.orientLandscape)],
                    p.orientation, (v) => p.copyWith(orientation: v)),
                label(t.videoLengthLabel),
                chips([('full', t.videoFull), ('photo', t.videoAsPhoto(p.seconds)), ('none', t.videoNone)], p.videoLength,
                    (v) => p.copyWith(videoLength: v)),
                label(t.fillLabel),
                chips([('fit', t.fillNever), ('auto', t.fillAuto), ('fill', t.fillAlways)], p.fillMode,
                    (v) => p.copyWith(fillMode: v)),
                const SizedBox(height: SmileSpacing.s),
                SwitchListTile(
                  title: Text(t.slowZoom),
                  subtitle: Text(t.slowZoomHint),
                  value: p.slowZoom,
                  onChanged: (v) => set(p.copyWith(slowZoom: v)),
                ),
                SwitchListTile(
                  title: Text(t.videoSound),
                  value: p.sound,
                  onChanged: (v) => set(p.copyWith(sound: v)),
                ),
                SwitchListTile(
                  title: Text(t.showCaptions),
                  subtitle: Text(t.showCaptionsHint),
                  value: p.captions,
                  onChanged: (v) => set(p.copyWith(captions: v)),
                ),
              ],
            ),
          ),
        );
      }),
    );
    _keepChrome();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final t = SmileTexts.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleChrome,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              // No itemCount: endless (see _current).
              onPageChanged: (i) {
                setState(() => _index = i);
                if (i > 0 && i % max(items.length, 1) == 0 && _prefs.order == 'shuffle') {
                  // A new round, a new shuffle.
                  _shuffleSeed++;
                  _items = _ordered(widget.items);
                }
                _schedule();
              },
              itemBuilder: (context, i) {
                if (items.isEmpty) return const SizedBox.shrink();
                final item = items[i % items.length];
                if (item.isVideo) {
                  return _VideoSlide(
                    key: ValueKey('${item.id}#$i'),
                    item: item,
                    active: i == _index,
                    withSound: _prefs.sound,
                    onEnded: () {
                      if (i == _index) _advance();
                    },
                  );
                }
                final url = item.displayUrl ?? item.thumbnailUrl;
                if (url == null) return const SizedBox.shrink();
                return SmilePhotoStage(
                  key: ValueKey('${item.id}#$i'),
                  image: CachedNetworkImageProvider(
                    url,
                    cacheKey: item.displayUrl != null ? '${item.id}_display' : '${item.id}_grid',
                  ),
                  fillMode: SmileFillMode.parse(_prefs.fillMode),
                  slowZoom: _prefs.slowZoom && i == _index,
                  duration: Duration(seconds: _prefs.seconds),
                );
              },
            ),
            // The photo's title (2026-10-17), while the controls are hidden.
            if (_prefs.captions && !_chrome && items.isNotEmpty && (_current.caption?.trim().isNotEmpty ?? false))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                // The Frame's style (2026-10-17).
                child: SmileViewerCaption(_current.caption!.trim(), maxLines: 3),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                icon: const Icon(SmileIcons.settings),
                                tooltip: t.slideshowSettings,
                                onPressed: _openSettings,
                              ),
                              const SizedBox(width: SmileSpacing.s),
                              IconButton.filledTonal(
                                icon: const Icon(SmileIcons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
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
/// plays while its page is shown, and says when it has ended.
class _VideoSlide extends StatefulWidget {
  const _VideoSlide({super.key, required this.item, required this.active, required this.onEnded, this.withSound = true});

  final MediaItem item;
  final bool active;
  final VoidCallback onEnded;
  final bool withSound;

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
    await controller.setVolume(widget.withSound ? 1 : 0);
    setState(() => _controller = controller);
    if (widget.active) await controller.play();
  }

  @override
  void didUpdateWidget(covariant _VideoSlide old) {
    super.didUpdateWidget(old);
    final controller = _controller;
    if (controller == null) return;
    if (old.withSound != widget.withSound) unawaited(controller.setVolume(widget.withSound ? 1 : 0));
    if (old.active == widget.active) return;
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
