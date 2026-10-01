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
  const VideoSlide({super.key, required this.entry, required this.cacheStore, required this.onFinished});

  final CachedMediaEntry entry;
  final MediaCacheStore cacheStore;
  final VoidCallback onFinished;

  @override
  State<VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<VideoSlide> {
  VideoPlayerController? _controller;
  File? _playbackFile;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
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
    await controller.play();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
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
