import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../icons/smile_icons.dart';

/// Lists show WHAT an object is, not just which kind it is (decided
/// 2026-10-07): an album shows its newest photo, a Space or Frame two
/// letters of its name -- instead of the same type icon on every row.
/// Objects stay rounded squares, people stay round (SmileAvatar), so the
/// kind is still recognisable; type icons remain in headers, the bottom
/// bar, empty states and -- as a small badge -- in mixed lists.

/// "Enkelkinder" -> "EN", "Urlaub 2026" -> "UR", "Live-Test" -> "LI".
String smileInitialsOf(String name) {
  final letters = name.replaceAll(RegExp(r'[^A-Za-zÄÖÜäöüß]'), '');
  if (letters.isEmpty) return name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
  return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
}

/// Rounded square with two letters -- same look as a person's initials
/// (neutral fill, coral letters), only the shape differs.
class SmileInitialsTile extends StatelessWidget {
  const SmileInitialsTile({super.key, required this.name, this.size = 42});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      alignment: Alignment.center,
      child: Text(
        smileInitialsOf(name),
        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: size * 0.36, letterSpacing: 0.3),
      ),
    );
  }
}

/// An album's cover: its newest photo, or two letters while it has none.
/// [cacheKey] should be stable per photo (the media id) -- the signed URL
/// changes on every load and would defeat the disk cache.
class SmileAlbumCover extends StatelessWidget {
  const SmileAlbumCover({super.key, required this.name, this.imageUrl, this.cacheKey, this.size = 42});

  final String name;
  final String? imageUrl;
  final String? cacheKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = SmileInitialsTile(name: name, size: size);
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.29),
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// Online/offline dot at the top right of a Frame's tile.
class SmileStatusDot extends StatelessWidget {
  const SmileStatusDot({super.key, required this.child, required this.online});

  final Widget child;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF7FC59A) : const Color(0xFF7A7273),
              shape: BoxShape.circle,
              border: Border.all(color: bg, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small type badge at the bottom right -- only in mixed lists
/// (Neuigkeiten), where albums, Frames, Spaces and people stand together.
class SmileTypeBadge extends StatelessWidget {
  const SmileTypeBadge({super.key, required this.child, required this.icon});

  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.surfaceContainer, width: 2),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 11, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// A picture with the coral camera badge (bottom right) -- the same "tap to
/// change" sign as on the profile picture. Without [onEdit] (people who may
/// not change it) the badge is not shown.
class SmileEditablePicture extends StatelessWidget {
  const SmileEditablePicture({super.key, required this.child, this.onEdit, this.busy = false, this.tooltip});

  final Widget child;
  final VoidCallback? onEdit;
  final bool busy;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (onEdit == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(onTap: busy ? null : onEdit, child: child),
        Positioned(
          right: -6,
          bottom: -6,
          child: Tooltip(
            message: tooltip ?? '',
            child: GestureDetector(
              onTap: busy ? null : onEdit,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                ),
                alignment: Alignment.center,
                child: busy
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(scheme.onPrimary)),
                      )
                    : Icon(SmileIcons.camera, size: 16, color: scheme.onPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
