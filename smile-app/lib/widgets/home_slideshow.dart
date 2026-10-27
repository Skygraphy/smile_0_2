import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../screens/album_slideshow_screen.dart';
import '../services/channel_picker_service.dart';
import '../services/media_service.dart';
import 'local_display.dart';

/// "Diashow" on the start page (2026-10-25, Ernst: "Spiel die letzten
/// 20/50 Bilder ab usw. Genauso wie am Frame"): what plays -- the newest
/// photos and videos of all albums, all albums one after another, or one
/// album -- then the phone's slideshow. Its settings (duration, order,
/// videos, sound) stay where they are: the gear in the slideshow.
class HomeSlideshowButton extends StatelessWidget {
  const HomeSlideshowButton({super.key, required this.albums});

  /// The albums of the start page.
  final List<ChannelWithActivity> albums;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(SmileIcons.slideshow),
        tooltip: SmileTexts.of(context).playSlideshow,
        onPressed: albums.isEmpty ? null : () => _choose(context, albums),
      );
}

enum _What { recent, rotate, album }

const _modeKey = 'home_slideshow_mode';
const _countKey = 'home_slideshow_count';

Future<void> _choose(BuildContext context, List<ChannelWithActivity> albums) async {
  final prefs = await SharedPreferences.getInstance();
  var what = _What.values.asNameMap()[prefs.getString(_modeKey)] ?? _What.recent;
  var count = prefs.getInt(_countKey) ?? 20;
  if (!context.mounted) return;
  final start = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) {
        final t = SmileTexts.of(sheetContext);
        final scheme = Theme.of(sheetContext).colorScheme;
        Widget option(_What value, String title, String hint, {Widget? extra}) {
          final selected = what == value;
          return Material(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SmileRadius.l),
              side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(SmileRadius.l),
              onTap: () => setSheet(() => what = value),
              child: Padding(
                padding: const EdgeInsets.all(SmileSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(hint, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    ?extra,
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.playSlideshow, style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: SmileSpacing.m),
                Text(t.whatPlays.toUpperCase(),
                    style: TextStyle(fontSize: 12, letterSpacing: 0.7, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                const SizedBox(height: SmileSpacing.s),
                option(
                  _What.recent,
                  t.homeSlideshowRecent,
                  t.homeSlideshowRecentHint,
                  extra: Padding(
                    padding: const EdgeInsets.only(top: SmileSpacing.s),
                    child: Wrap(
                      spacing: SmileSpacing.s,
                      runSpacing: SmileSpacing.s,
                      children: [
                        for (final n in const [10, 20, 50, 100])
                          ChoiceChip(
                            label: Text('$n'),
                            selected: count == n,
                            onSelected: (_) => setSheet(() {
                              count = n;
                              what = _What.recent;
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SmileSpacing.s),
                option(_What.rotate, t.contentRotate, t.homeSlideshowRotateHint),
                const SizedBox(height: SmileSpacing.s),
                option(_What.album, t.homeSlideshowOneAlbum, t.homeSlideshowOneAlbumHint),
                const SizedBox(height: SmileSpacing.m),
                Text(t.homeSlideshowSettingsHint, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: SmileSpacing.m),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(t.homeSlideshowStart),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (start != true || !context.mounted) return;
  await prefs.setString(_modeKey, what.name);
  await prefs.setInt(_countKey, count);
  if (!context.mounted) return;
  final t = SmileTexts.of(context);

  var chosen = albums;
  if (what == _What.album) {
    final picked = await showDialog<ChannelWithActivity>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(t.homeSlideshowPickAlbum),
        children: [
          for (final a in albums)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(a),
              child: Text(albumNameOf(a.channelId, a.channelName)),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    chosen = [picked];
  }

  // The photos and videos of those albums (a moment for many albums).
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  ));
  final albumOf = <String, String>{};
  var items = <MediaItem>[];
  try {
    final lists = await Future.wait([
      for (final a in chosen)
        MediaService().fetchReadyMedia(a.channelId).catchError((Object _) => <MediaItem>[]),
    ]);
    for (final (i, list) in lists.indexed) {
      for (final item in list.where((m) => m.isReady)) {
        albumOf[item.id] = albumNameOf(chosen[i].channelId, chosen[i].channelName);
        items.add(item);
      }
    }
  } finally {
    navigator.pop();
  }
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (what == _What.recent) items = items.take(count).toList();
  if (items.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(t.homeSlideshowNothing)));
    return;
  }
  await navigator.push(MaterialPageRoute(
    builder: (_) => AlbumSlideshowScreen(
      albumName: what == _What.album ? albumNameOf(chosen.single.channelId, chosen.single.channelName) : '',
      items: items,
      albumOf: albumOf,
      headline: switch (what) {
        _What.recent => t.contentRecent,
        _What.rotate => t.contentRotate,
        _What.album => null,
      },
      albumByAlbum: what == _What.rotate,
    ),
  ));
}
