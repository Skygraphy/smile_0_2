import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Every user and every group always shows *some* avatar: a real uploaded
/// photo when present, otherwise a generated initials circle -- never a
/// blank/anonymous placeholder (the user's explicit requirement: "Jeder
/// User und jede Gruppe benötigt zumindest einen Namen und ein
/// Profilbild"). Deliberately monochrome -- neutral fill, coral initials
/// -- not per-person hue variety, matching the single-primary-color
/// ground rule rather than a Slack/WhatsApp-style colorful-initials system.
class SmileAvatar extends StatelessWidget {
  const SmileAvatar({super.key, required this.name, this.avatarUrl, this.size = 40});

  final String name;
  final String? avatarUrl;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    final single = parts.first;
    return single.substring(0, single.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = avatarUrl;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, _) => _fallback(theme),
                errorWidget: (context, _, _) => _fallback(theme),
              )
            : _fallback(theme),
      ),
    );
  }

  Widget _fallback(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}
