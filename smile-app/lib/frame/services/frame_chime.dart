import 'dart:async';

import 'package:flutter/services.dart';

/// The Frame's chime for new photos (FrameChime.kt, migrations/0093).
class FrameChime {
  FrameChime._();

  static const _channel = MethodChannel('smile/frame_chime');

  static void play() => unawaited(_channel.invokeMethod<void>('play').catchError((Object _) {}));
}
