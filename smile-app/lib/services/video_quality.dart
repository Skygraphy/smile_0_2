import 'package:flutter/foundation.dart';

import 'offline.dart';

/// "Videos senden": how much a video is shrunk before it goes up (decided
/// 2026-10-12). Per phone, changeable any time on the Profil page; applies
/// to every video sent from this phone from then on.
enum VideoQuality {
  high(shortSide: 720, bitrate: 1800000),
  medium(shortSide: 720, bitrate: 1100000),
  low(shortSide: 480, bitrate: 600000);

  const VideoQuality({required this.shortSide, required this.bitrate});

  /// The video's shorter edge at most this many pixels.
  final int shortSide;

  /// Bits per second for the picture.
  final int bitrate;

  static const _key = 'video_quality';

  /// "Mittel" unless chosen otherwise -- about what WhatsApp sends.
  static const standard = VideoQuality.medium;

  static final current = ValueNotifier<VideoQuality>(standard);

  static Future<void> load() async {
    final stored = await Offline.read(_key);
    current.value = VideoQuality.values.where((q) => q.name == stored).firstOrNull ?? standard;
  }

  static Future<void> choose(VideoQuality quality) async {
    current.value = quality;
    await Offline.write(_key, quality.name);
  }
}
