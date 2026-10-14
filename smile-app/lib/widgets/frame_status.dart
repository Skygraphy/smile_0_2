import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_service.dart';

/// "Online · Akku 87 % · Bergoma" / "Offline seit 2 Std. · Bergoma" -- one
/// line on the Frames tab and the remote control (2026-10-11).
String frameStatusLine(SmileTexts t, SmileFrame frame, {String? spaceName}) {
  final parts = <String>[];
  if (frame.isOnline) {
    parts.add(t.frameOnline);
    if (frame.batteryLevel != null) {
      parts.add(t.batteryShort(frame.batteryLevel!) + (frame.isCharging == true ? ' (${t.charging})' : ''));
    }
  } else if (frame.lastSeenAt == null) {
    parts.add(frame.isPending ? t.framePending : t.frameNeverOnline);
  } else {
    final away = DateTime.now().difference(frame.lastSeenAt!);
    final time = away.inHours < 1
        ? t.durationMinutes(away.inMinutes)
        : away.inDays < 1
            ? t.durationHours(away.inHours)
            : t.durationDays(away.inDays);
    parts.add(t.frameOfflineSince(time));
  }
  if (spaceName != null && spaceName.isNotEmpty) parts.add(spaceName);
  return parts.join(' · ');
}

/// What a Frame plays when that is not just one album (2026-10-14): a round
/// started on it ("Lieblingsbilder", "Neueste Fotos") or its playback
/// setting. Null: one album -- its name says it.
String? framePlaysLabel(SmileTexts t, {String? contentMode, String? playingRound}) => switch (playingRound) {
      'favorites' => t.favorites,
      'newest' => t.allowNewest,
      _ => switch (contentMode) {
          'favorites' => t.contentFavorites,
          'recent' => t.contentRecent,
          'rotate' => t.contentRotate,
          _ => null,
        },
    };
