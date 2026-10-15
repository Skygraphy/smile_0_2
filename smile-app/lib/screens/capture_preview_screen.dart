import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:video_player/video_player.dart';

enum CaptureDecision { send, retake }

/// A photo or video just taken with the album's camera button (decided
/// 2026-10-08, WhatsApp-style): look at it once, then "Senden" or "Nochmal"
/// -- nothing is uploaded before that. Back closes without sending.
class CapturePreviewScreen extends StatefulWidget {
  const CapturePreviewScreen({super.key, required this.file, required this.isVideo, required this.albumName});

  final File file;
  final bool isVideo;
  final String albumName;

  @override
  State<CapturePreviewScreen> createState() => _CapturePreviewScreenState();
}

class _CapturePreviewScreenState extends State<CapturePreviewScreen> {
  VideoPlayerController? _video;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      final controller = VideoPlayerController.file(widget.file);
      _video = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        controller.play();
        setState(() {});
      });
    } else {
      widget.file.readAsBytes().then((bytes) {
        if (mounted) setState(() => _photo = bytes);
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Widget _media() {
    final video = _video;
    if (video != null) {
      if (!video.value.isInitialized) return const CircularProgressIndicator();
      return GestureDetector(
        onTap: () => setState(() => video.value.isPlaying ? video.pause() : video.play()),
        child: AspectRatio(aspectRatio: video.value.aspectRatio, child: VideoPlayer(video)),
      );
    }
    final photo = _photo;
    if (photo == null) return const CircularProgressIndicator();
    return InteractiveViewer(child: Image.memory(photo, fit: BoxFit.contain));
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(SmileIcons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(widget.albumName),
      ),
      body: Center(child: _media()),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(SmileIcons.restore),
                label: Text(t.captureRetake),
                onPressed: () => Navigator.of(context).pop(CaptureDecision.retake),
              ),
              const Spacer(),
              FloatingActionButton(
                heroTag: null,
                tooltip: t.captureSend,
                onPressed: () => Navigator.of(context).pop(CaptureDecision.send),
                child: const Icon(SmileIcons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
