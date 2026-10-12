import 'package:flutter/foundation.dart';

import 'offline.dart';

/// "Videos senden": how much a video is shrunk before it goes up (decided
/// 2026-10-12). Per phone, changeable any time on the Profil page; applies
/// to every video sent from this phone from then on.
///
/// "Mittel" is exactly what WhatsApp sends (measured 2026-10-12 on four
/// videos sent with WhatsApp from the S26): 480p short side, H.264 about
/// 1.4 Mbit/s, AAC 256 kbit/s, frame rate as recorded. "Hoch" is clearly
/// more (720p with enough bits for its pixels), "Niedrig" clearly less.
enum VideoQuality {
  high(shortSide: 720, bitrate: 3000000, audioBitrate: 256000),
  medium(shortSide: 480, bitrate: 1400000, audioBitrate: 256000),
  low(shortSide: 360, bitrate: 700000, audioBitrate: 96000);

  const VideoQuality({required this.shortSide, required this.bitrate, required this.audioBitrate});

  /// Bits per second for the sound.
  final int audioBitrate;

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
