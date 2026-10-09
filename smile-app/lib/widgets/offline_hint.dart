import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/offline.dart';

/// "Offline – zuletzt geladener Stand": a quiet line instead of an error
/// while the server can't be reached (2026-10-09). Disappears by itself
/// as soon as a request goes through again.
class OfflineHint extends StatelessWidget {
  const OfflineHint({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Offline.isOffline,
      builder: (context, offline, _) {
        if (!offline) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          color: scheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(SmileIcons.offline, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                SmileTexts.of(context).offlineHint,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}
