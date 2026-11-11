import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';

/// How long a video may be (2026-11-05: 2 minutes; 2026-11-11: per Space's
/// Frame plan -- 2, 5, 10 or 15 minutes, migrations/0102). The phone checks
/// before anything is sent; the server checks as well.
class VideoLimit {
  VideoLimit._();

  /// Without a plan, and whenever the album's limit can't be asked.
  static const fallback = Duration(minutes: 2);
  static const _videoEndings = ['.mp4', '.mov', '.3gp', '.mkv', '.webm', '.m4v'];

  /// Asked once per album and session; offline the last answer (or 2 min).
  static final Map<String, Duration> _known = {};

  static bool _isVideo(XFile file) {
    final name = file.path.toLowerCase();
    return (file.mimeType?.startsWith('video/') ?? false) || _videoEndings.any(name.endsWith);
  }

  /// How long videos sent into [channelId] may be.
  static Future<Duration> forAlbum(String channelId) async {
    try {
      final seconds = await supabase.rpc('album_video_seconds', params: {'p_channel': channelId});
      if (seconds is num && seconds > 0) return _known[channelId] = Duration(seconds: seconds.toInt());
    } catch (_) {}
    return _known[channelId] ?? fallback;
  }

  /// Longer than [max] (with a second's grace); false when it cannot tell.
  static Future<bool> tooLong(XFile file, Duration max) async {
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
