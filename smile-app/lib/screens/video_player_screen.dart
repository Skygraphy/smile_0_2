import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen playback of one video, streamed straight from its signed
/// display URL (a 720p H.264 MP4 produced by the media worker) -- nothing
/// is downloaded first, so even an hour-long video starts at once.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.url});

  final String url;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _controller.play();
    }).catchError((Object e) {
      if (mounted) setState(() => _error = 'Video konnte nicht abgespielt werden: $e');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play());
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              )
            : !value.isInitialized
                ? const CircularProgressIndicator()
                : GestureDetector(
                    onTap: _togglePlay,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(_controller)),
                        if (!value.isPlaying)
                          const Positioned.fill(
                            child: Center(child: Icon(Icons.play_circle_fill, size: 72, color: Colors.white70)),
                          ),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                      ],
                    ),
                  ),
      ),
    );
  }
}
