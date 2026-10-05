import 'package:flutter/material.dart';

import '../theme/smile_tokens.dart';
import 'smile_object_tile.dart';

/// What an empty area shows: its object icon, one short title, an
/// optional sentence, and at most one action (decision 6, 2026-10-05).
class SmileEmptyState extends StatelessWidget {
  const SmileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = message;
    final label = actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SmileObjectIcon(icon: icon, size: 72, iconSize: 34),
            const SizedBox(height: SmileSpacing.m),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (msg != null) ...[
              const SizedBox(height: SmileSpacing.s),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (label != null && onAction != null) ...[
              const SizedBox(height: SmileSpacing.l),
              FilledButton.icon(
                onPressed: onAction,
                icon: actionIcon == null ? null : Icon(actionIcon, size: SmileIconSize.small),
                label: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
