import 'package:flutter/material.dart';

import '../theme/smile_tokens.dart';

/// Rounded square carrying an object icon (Space, Album, Frame). Square,
/// not round, so objects never look like a person's (round) avatar.
class SmileObjectIcon extends StatelessWidget {
  const SmileObjectIcon({super.key, required this.icon, this.size = 42, this.iconSize});

  final IconData icon;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize ?? size * 0.52, color: scheme.onSurfaceVariant),
    );
  }
}

/// The one list-row pattern for every object: leading icon or avatar,
/// name, one line of context (optionally led by a small role icon), and
/// an optional trailing widget (role badge, time, status dot, chevron).
class SmileObjectTile extends StatelessWidget {
  const SmileObjectTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final IconData? subtitleIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sub = subtitle;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l, vertical: 9),
        child: Row(
          children: [
            leading,
            const SizedBox(width: SmileSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          if (subtitleIcon != null) ...[
                            Icon(subtitleIcon, size: SmileIconSize.badge, color: muted),
                            const SizedBox(width: SmileSpacing.xs),
                          ],
                          Expanded(
                            child: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: SmileSpacing.s),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
