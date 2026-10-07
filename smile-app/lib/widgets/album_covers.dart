import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/channel_picker_service.dart';

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

/// An album's cover from [covers] (newest photo), or its initials.
Widget albumCover(String channelId, String name, Map<String, ChannelWithActivity> covers, {double size = 42}) {
  final album = covers[channelId];
  final mediaId = album?.coverMediaId;
  return SmileAlbumCover(
    name: name,
    imageUrl: album?.coverUrl,
    cacheKey: mediaId == null ? null : 'cover_$mediaId',
    size: size,
  );
}
