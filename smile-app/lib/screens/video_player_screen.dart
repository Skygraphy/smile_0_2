import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:video_player/video_player.dart';

import '../services/offline.dart';
import '../services/video_cache.dart';

/// Full-screen playback of one video. Plays the copy on the phone if there
/// is one (VideoCache, 2026-10-10 -- also offline); otherwise it streams
/// from its signed display URL (a 720p H.264 MP4), so even an hour-long
/// video starts at once, and is downloaded meanwhile for next time.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.mediaId,
    required this.url,
    this.localPath,
    this.onShowOnFrame,
    this.onFavorite,
    this.favorite = false,
  });

  /// "Jetzt am Frame zeigen" (2026-10-14) -- only when the album runs on a
  /// Frame the caller manages.
  final VoidCallback? onShowOnFrame;

  /// "Lieblingsbild für den Frame" (2026-10-14), same condition: marks or
  /// takes back; returns whether it is a Lieblingsbild afterwards (null:
  /// nothing changed).
  final Future<bool?> Function()? onFavorite;

  /// A Lieblingsbild already: the heart is filled, in coral.
  final bool favorite;

  final String mediaId;
  final String? url;

  /// A video still on its way to the server (2026-10-12): from the phone.
  final String? localPath;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late bool _favorite = widget.favorite;
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ownFile = widget.localPath;
    final local = ownFile != null && File(ownFile).existsSync() ? File(ownFile) : await VideoCache.cached(widget.mediaId);
    final url = widget.url;
    if (local == null && url == null) {
      if (mounted) setState(() => _error = SmileTexts.of(context).videoNotOnPhone);
      return;
    }
    final controller = local != null
        ? VideoPlayerController.file(File(local.path))
        : VideoPlayerController.networkUrl(Uri.parse(url!));
    // Streaming now -- kept on the phone for next time (and offline).
    if (local == null) unawaited(VideoCache.download(widget.mediaId, url!));
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      await controller.play();
    } catch (e) {
      if (!mounted) return;
      final t = SmileTexts.of(context);
      setState(() => _error = Offline.isConnectionError(e) ? t.videoNotOnPhone : t.videoNotPlayable);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    // A block body: setState may not get the Future of play()/pause()
    // (Crashlytics 2026-10-15).
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else {
      unawaited(controller.play());
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (widget.onFavorite != null)
            IconButton(
              icon: Icon(
                _favorite ? SmileIcons.heartFilled : SmileIcons.heart,
                color: _favorite ? SmileTheme.primary : null,
              ),
              tooltip: SmileTexts.of(context).favoriteFor,
              onPressed: () async {
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
        ],
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              )
            : controller == null || value == null || !value.isInitialized
                ? const CircularProgressIndicator()
                : GestureDetector(
                    onTap: _togglePlay,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(controller)),
                        if (!value.isPlaying)
                          const Positioned.fill(
                            child: Center(child: Icon(SmileIcons.play, size: 72, color: Colors.white70)),
                          ),
                        VideoProgressIndicator(controller, allowScrubbing: true),
                      ],
                    ),
                  ),
      ),
    );
  }
}
