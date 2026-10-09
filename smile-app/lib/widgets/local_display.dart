import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/local_changes.dart';

/// What screens show for a name or picture: an own change not yet confirmed
/// by the server (LocalChanges, 2026-10-09) wins over the server's data.

String albumNameOf(String id, String serverName) => LocalChanges.instance.text(LocalChanges.albumName(id)) ?? serverName;

String spaceNameOf(String id, String serverName) => LocalChanges.instance.text(LocalChanges.spaceName(id)) ?? serverName;

String frameNameOf(String id, String serverName) => LocalChanges.instance.text(LocalChanges.frameName(id)) ?? serverName;

String myNameOf(String serverName) => LocalChanges.instance.text(LocalChanges.profileName) ?? serverName;

/// A Space's or Frame's picture ([key]: LocalChanges.spacePicture/framePicture).
Widget objectPicture({
  required String key,
  required String name,
  String? serverUrl,
  double size = 42,
}) {
  final local = LocalChanges.instance.picture(key);
  if (local != null) {
    // Removed: no image -> initials.
    return SmileAlbumCover(name: name, image: local.image, size: size);
  }
  return SmileAlbumCover(name: name, imageUrl: serverUrl, size: size);
}

/// The caller's own avatar.
Widget myAvatar({required String name, String? serverUrl, double size = 40}) {
  final local = LocalChanges.instance.picture(LocalChanges.profileAvatar);
  if (local != null) return SmileAvatar(name: name, image: local.image, size: size);
  return SmileAvatar(name: name, avatarUrl: serverUrl, size: size);
}
