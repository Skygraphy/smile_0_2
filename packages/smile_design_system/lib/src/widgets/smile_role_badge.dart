import 'package:flutter/material.dart';

import '../icons/smile_icons.dart';
import '../l10n/smile_texts.dart';
import '../theme/smile_tokens.dart';

/// The four user-facing roles. Space roles: [admin] (the one main admin,
/// DB `spaces.owner_id`) and [coAdmin] (`space_co_owners`). Album roles:
/// [member] (may post, `channel_members`) and [viewer] (sees the album
/// through a share with their Space, `channel_shares`).
enum SmileRole {
  admin(SmileIcons.admin),
  coAdmin(SmileIcons.coAdmin),
  member(SmileIcons.member),
  viewer(SmileIcons.viewer);

  const SmileRole(this.icon);

  final IconData icon;

  String label(SmileTexts t) => switch (this) {
        SmileRole.admin => t.roleAdmin,
        SmileRole.coAdmin => t.roleCoAdmin,
        SmileRole.member => t.roleMember,
        SmileRole.viewer => t.roleViewer,
      };
}

/// Small pill with the role's icon and name, shown to the right of a
/// person or object in lists. The Admin badge is the only coral one so
/// the main admin stands out; every other role stays neutral.
class SmileRoleBadge extends StatelessWidget {
  const SmileRoleBadge({super.key, required this.role, this.showLabel = true});

  final SmileRole role;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = role == SmileRole.admin;
    final fg = highlight ? scheme.primary : scheme.onSurfaceVariant;
    final label = role.label(SmileTexts.of(context));
    final icon = Icon(role.icon, size: SmileIconSize.badge, color: fg);
    if (!showLabel) return Semantics(label: label, child: icon);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(SmileRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: fg)),
        ],
      ),
    );
  }
}
