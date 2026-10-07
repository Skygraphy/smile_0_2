import 'package:flutter/material.dart';

import '../icons/smile_icons.dart';
import '../theme/smile_tokens.dart';
import 'smile_object_tile.dart';

/// Building blocks of the WhatsApp-group-info style page every object
/// (Album, Space) uses (decision 5, 2026-10-05): a big icon and name on
/// top, up to three quick actions, then rounded sections, and the
/// dangerous actions (leave/delete) last, in coral.

/// Big object icon, name and one context line. When [onRename] is set the
/// name is tappable (renaming = tapping the name, no pencil icon: the
/// pencil is already the Member badge).
class SmileInfoHeader extends StatelessWidget {
  const SmileInfoHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.onRename,
    this.renameTooltip,
    this.leading,
  });

  final IconData icon;

  /// Replaces the big type icon, e.g. a Space's initials (80 px).
  final Widget? leading;
  final String title;
  final String? subtitle;
  final IconData? subtitleIcon;
  final VoidCallback? onRename;
  final String? renameTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sub = subtitle;
    final name = Text(
      title,
      textAlign: TextAlign.center,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.s, SmileSpacing.l, SmileSpacing.l),
      child: Column(
        children: [
          leading ?? SmileObjectIcon(icon: icon, size: 80, iconSize: SmileIconSize.hero),
          const SizedBox(height: SmileSpacing.m),
          if (onRename == null)
            name
          else
            Tooltip(
              message: renameTooltip ?? '',
              child: InkWell(
                borderRadius: BorderRadius.circular(SmileRadius.s),
                onTap: onRename,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: name),
              ),
            ),
          if (sub != null) ...[
            const SizedBox(height: SmileSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitleIcon != null) ...[
                  Icon(subtitleIcon, size: SmileIconSize.badge, color: muted),
                  const SizedBox(width: SmileSpacing.xs),
                ],
                Flexible(
                  child: Text(sub, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SmileQuickAction {
  const SmileQuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Row of up to three equal-width quick-action buttons under the header.
class SmileQuickActions extends StatelessWidget {
  const SmileQuickActions({super.key, required this.actions});

  final List<SmileQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.m),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: SmileSpacing.s),
            Expanded(
              child: Material(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(SmileRadius.m),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SmileRadius.m),
                  onTap: actions[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: SmileSpacing.m),
                    child: Column(
                      children: [
                        Icon(actions[i].icon, color: scheme.primary, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          actions[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded block with an optional small heading.
class SmileInfoSection extends StatelessWidget {
  const SmileInfoSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SmileSpacing.m, SmileSpacing.m, SmileSpacing.m, 0),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(SmileRadius.l),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SmileSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (heading != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.s, SmileSpacing.l, SmileSpacing.xs),
                  child: Text(
                    heading,
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// One tappable action line inside a section ("Person einladen",
/// "Album löschen"). [destructive] actions are coral, like in the preview.
class SmileActionRow extends StatelessWidget {
  const SmileActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = scheme.primary;
    final textColor = destructive ? scheme.primary : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l, vertical: SmileSpacing.m),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: SmileSpacing.l),
            Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 15))),
          ],
        ),
      ),
    );
  }
}

/// Muted one-liner for an empty section ("Noch auf keinem Frame").
class SmileSectionHint extends StatelessWidget {
  const SmileSectionHint({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l, vertical: SmileSpacing.m),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: SmileIconSize.small, color: muted),
            const SizedBox(width: SmileSpacing.m),
          ],
          Expanded(child: Text(text, style: TextStyle(color: muted, fontSize: 13.5))),
        ],
      ),
    );
  }
}

/// A big, tappable choice block -- coral icon tile, title, one-line hint,
/// chevron. Used for the first-start "Zwei Wege" (decision 6).
class SmileChoiceCard extends StatelessWidget {
  const SmileChoiceCard({super.key, required this.icon, required this.title, this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = hint;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(SmileRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(SmileRadius.l),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SmileSpacing.l),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(SmileRadius.m),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: SmileSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (text != null) ...[
                      const SizedBox(height: 2),
                      Text(text, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              Icon(SmileIcons.chevron, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
