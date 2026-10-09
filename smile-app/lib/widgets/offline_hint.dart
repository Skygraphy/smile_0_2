import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/offline.dart';

/// "Offline – zuletzt geladener Stand": a small floating pill at the bottom
/// of every screen while the server can't be reached (2026-10-09) -- every
/// screen then shows what it showed last (OfflineCachingClient). It never
/// takes taps and goes away by itself once a request goes through again.
class OfflineHintOverlay extends StatelessWidget {
  const OfflineHintOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: Offline.isOffline,
          builder: (context, offline, _) {
            if (!offline) return const SizedBox.shrink();
            final scheme = Theme.of(context).colorScheme;
            return Positioned(
              left: 0,
              right: 0,
              // Above the bottom navigation and the album's buttons' row.
              bottom: bottom + 92,
              child: IgnorePointer(
                child: Center(
                  child: Material(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(SmileIcons.offline, size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            SmileTexts.of(context).offlineHint,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
