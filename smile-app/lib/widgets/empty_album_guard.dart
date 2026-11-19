import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';

/// Before a Frame switches to an album (Ernst 2026-11-19: Küche showed the
/// empty "Winterurlaub"): an album without a single ready photo or video
/// asks first -- Oma should never sit in front of an empty picture.
/// True = go ahead. When the album can't be checked (offline, not
/// visible), it doesn't ask: never block the switch on a lookup.
Future<bool> confirmAlbumOnFrame(
  BuildContext context, {
  required String channelId,
  required String albumName,
  required String frameName,
}) async {
  try {
    final rows = await supabase
        .from('media_items')
        .select('id')
        .eq('channel_id', channelId)
        .eq('processing_status', 'ready')
        .limit(1);
    if ((rows as List).isNotEmpty) return true;
  } catch (_) {
    return true;
  }
  if (!context.mounted) return false;
  final t = SmileTexts.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.emptyAlbumTitle),
      content: SmileNamedText(t.emptyAlbumMessage(albumName, frameName), names: [albumName, frameName]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.emptyAlbumShowAnyway)),
        FilledButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.actionCancel)),
      ],
    ),
  );
  return go == true;
}
