import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/channel_picker_service.dart';
import '../services/local_changes.dart';

/// Every album the caller can see, by id -- for showing its cover (newest
/// photo) wherever albums are listed. Best-effort: on failure the lists
/// simply show initials.
Future<Map<String, ChannelWithActivity>> loadAlbumCovers([ChannelPickerService? service]) async {
  try {
    final albums = await (service ?? ChannelPickerService()).listMyChannelsWithActivity();
    return {for (final a in albums) a.channelId: a};
  } catch (_) {
    return const {};
  }
}

/// The cache key of an album photo's thumbnail -- shared by the album
/// itself, the cover picker and the cover.
String albumPhotoCacheKey(String mediaId) => '${mediaId}_grid';

/// An album's cover from [covers] (newest photo), or its initials.
Widget albumCover(String channelId, String name, Map<String, ChannelWithActivity> covers, {double size = 42}) {
  // A cover just chosen here shows at once (LocalChanges, 2026-10-09).
  final local = LocalChanges.instance.picture(LocalChanges.albumCover(channelId));
  if (local != null && !local.removed) return SmileAlbumCover(name: name, image: local.image, size: size);
  final album = covers[channelId];
  final mediaId = album?.coverMediaId;
  return SmileAlbumCover(
    name: name,
    imageUrl: album?.coverUrl,
    // An uploaded cover has a unique URL per upload, so the URL itself is a
    // safe cache key; photo covers use their media id (URLs are re-signed)
    // -- the same key as the photo in the album, so it's usually cached.
    cacheKey: mediaId == null ? album?.coverUrl : albumPhotoCacheKey(mediaId),
    size: size,
  );
}
