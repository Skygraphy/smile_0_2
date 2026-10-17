import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/media_cache_store.dart';
import '../services/media_cache_sync.dart';

/// One video in the slideshow, played in full (decision 2026-10-01: no
/// length limit, the Frame shows the whole video). The cached file is
/// encrypted, so it is decrypted into a temporary playback file first and
/// that file is deleted again as soon as this slide goes away.
///
/// [onFinished] fires once when the video has played to its end -- the
/// slideshow moves on then, instead of on its usual timer -- or right away
/// if the video can't be played, so a broken file never stalls the Frame.
class VideoSlide extends StatefulWidget {
  const VideoSlide({
    super.key,
    required this.entry,
    required this.cacheStore,
    required this.onFinished,
    this.withSound = true,
    this.paused = false,
  });

  final CachedMediaEntry entry;
  final MediaCacheStore cacheStore;
  final VoidCallback onFinished;

  /// The Frame's video-sound setting; false plays muted.
  final bool withSound;

  /// Pause on the Frame or from the app's remote control (2026-10-14).
  final bool paused;

  @override
  State<VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<VideoSlide> {
  VideoPlayerController? _controller;
  File? _playbackFile;
  bool _finished = false;
  Timer? _fade;
  double _volume = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(VideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The setting can change while a video plays (pushed via sync).
    if (oldWidget.withSound != widget.withSound) _fadeTo(widget.withSound ? 1 : 0);
    if (oldWidget.paused != widget.paused) {
      if (widget.paused) {
        _controller?.pause();
      } else {
        _controller?.play();
      }
    }
  }

  Future<void> _start() async {
    final file = await widget.cacheStore.decryptVideoForPlayback(widget.entry.fileName);
    if (!mounted) {
      await file?.delete().catchError((_) => file);
      return;
    }
    if (file == null) return _finish();
    _playbackFile = file;
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      return _finish();
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(() {
      final value = controller.value;
      if (value.isInitialized && !value.isPlaying && value.duration > Duration.zero && value.position >= value.duration) {
        _finish();
      }
      if (value.hasError) _finish();
    });
    setState(() => _controller = controller);
    _volume = widget.withSound ? 1 : 0;
    await controller.setVolume(_volume);
    if (!widget.paused) await controller.play();
  }

  /// Sound swells in or fades out over about a second (2026-10-17)
  /// instead of switching abruptly.
  void _fadeTo(double target) {
    _fade?.cancel();
    final controller = _controller;
    if (controller == null) return;
    const steps = 20;
    final start = _volume;
    var step = 0;
    _fade = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      step++;
      final t = step / steps;
      // Ease in and out, so it starts and ends softly.
      final eased = t * t * (3 - 2 * t);
      _volume = start + (target - start) * eased;
      unawaited(controller.setVolume(_volume.clamp(0.0, 1.0)));
      if (step >= steps) timer.cancel();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _fade?.cancel();
    final controller = _controller;
    final file = _playbackFile;
    unawaited(() async {
      await controller?.dispose();
      if (file != null && await file.exists()) await file.delete();
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white24));
    }
    return Center(
      child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
    );
  }
}
