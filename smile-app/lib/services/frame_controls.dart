/// The Frame's control levels (decided 2026-10-14, migrations/0075): each
/// level is just a preset of the switches below. A switch changed one by one
/// that matches no level makes "Eigene Auswahl" (control_level null).
class FrameControlLevels {
  FrameControlLevels._();

  /// In the order the app lists them.
  static const keys = [
    'next', 'back', 'pause', 'newest', 'favorite', 'favorites', 'overview', 'album', 'duration', 'captions', 'playback', //
  ];

  static const _onFrom = {
    'next': 2,
    'pause': 2,
    'back': 3,
    'newest': 3,
    // Lieblingsbilder (migrations/0076).
    'favorite': 3,
    'favorites': 3,
    'overview': 4,
    'album': 4,
    'duration': 4,
    // The "Titel" button (migrations/0084).
    'captions': 4,
    'playback': 5,
  };

  static Map<String, bool> preset(int level) => {for (final key in keys) key: level >= _onFrom[key]!};

  /// The level these switches are exactly, or null ("Eigene Auswahl").
  static int? levelOf(Map<String, bool> controls) {
    for (var level = 1; level <= 5; level++) {
      final p = preset(level);
      if (keys.every((k) => (controls[k] ?? false) == p[k])) return level;
    }
    return null;
  }

  /// The row update for these switches: level, switches, and the older
  /// album-switch column kept in step.
  static Map<String, dynamic> update(Map<String, bool> controls) => {
        'controls': controls,
        'control_level': levelOf(controls),
        'channel_switch_enabled': controls['album'] ?? false,
      };
}
