import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Videos at most 2 minutes long (Ernst 2026-11-05): keeps the really big
/// files out -- the phone checks before anything is sent.
class VideoLimit {
  VideoLimit._();

  static const max = Duration(minutes: 2);
  static const _videoEndings = ['.mp4', '.mov', '.3gp', '.mkv', '.webm', '.m4v'];

  static bool _isVideo(XFile file) {
    final name = file.path.toLowerCase();
    return (file.mimeType?.startsWith('video/') ?? false) || _videoEndings.any(name.endsWith);
  }

  /// Longer than [max] (with a second's grace); false when it cannot tell.
  static Future<bool> tooLong(XFile file) async {
    if (!_isVideo(file)) return false;
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      return controller.value.duration > max + const Duration(seconds: 1);
    } catch (_) {
      return false;
    } finally {
      await controller.dispose();
    }
  }
}
