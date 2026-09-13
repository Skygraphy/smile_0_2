import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../widgets/smile_avatar.dart';

/// Full-screen view opened by tapping the avatar image itself (not the
/// camera badge) on SettingsScreen -- matches WhatsApp's own "tap your
/// profile photo to see it large" behavior. Falls back to a big
/// SmileAvatar (initials) when there's no real photo, so this never
/// shows a blank screen.
class AvatarViewerScreen extends StatelessWidget {
  const AvatarViewerScreen({super.key, required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: url != null && url.isNotEmpty
            ? InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  errorWidget: (context, _, _) => SmileAvatar(name: name, size: 220),
                ),
              )
            : SmileAvatar(name: name, size: 220),
      ),
    );
  }
}
