import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_service.dart';
import '../services/local_changes.dart';
import '../services/media_service.dart';
import '../widgets/local_display.dart';
import 'photo_viewer_screen.dart';
import 'video_player_screen.dart';

/// "Hinzufügen" on a Frame's Lieblingsbilder (decided 2026-10-15): its
/// albums to choose from, the chosen album's photos with a heart each --
/// everything marked here is for this one Frame, like the overview on the
/// Frame itself.
class FrameFavoritesAddScreen extends StatefulWidget {
  const FrameFavoritesAddScreen({super.key, required this.frameId, required this.frameName, required this.frameService});

  final String frameId;
  final String frameName;
  final FrameService frameService;

  @override
  State<FrameFavoritesAddScreen> createState() => _FrameFavoritesAddScreenState();
}

class _FrameFavoritesAddScreenState extends State<FrameFavoritesAddScreen> {
  final _media = MediaService();
  List<FrameChannelAssignment>? _albums;
  String? _albumId;
  final Map<String, List<MediaItem>> _items = {};
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.frameService.listAssignedChannels(widget.frameId),
        widget.frameService.favoritesOf([widget.frameId]),
      ]);
      if (!mounted) return;
      final albums = results[0] as List<FrameChannelAssignment>;
      setState(() {
        _albums = albums;
        _favorites = (results[1] as Map<String, Set<String>>).keys.toSet();
      });
      if (albums.isNotEmpty) await _pick(albums.first.channelId);
    } catch (_) {
      if (mounted) setState(() => _albums ??= const []);
    }
  }

  Future<void> _pick(String albumId) async {
    setState(() => _albumId = albumId);
    if (_items.containsKey(albumId)) return;
    try {
      final items = await _media.fetchReadyMedia(albumId);
      if (mounted) setState(() => _items[albumId] = items.where((i) => i.isReady).toList());
    } catch (_) {
      if (mounted) setState(() => _items[albumId] = const []);
    }
  }

  /// Shown at once; back again if the server says no.
  Future<void> _toggle(MediaItem item) async {
    final on = !_favorites.contains(item.id);
    unawaited(HapticFeedback.selectionClick());
    setState(() => on ? _favorites.add(item.id) : _favorites.remove(item.id));
    final saved = await LocalChanges.instance.run(
      overrides: const {},
      commit: () => on
          ? widget.frameService.addFavorite(frameId: widget.frameId, mediaItemId: item.id)
          : widget.frameService.removeFavorites(frameId: widget.frameId, mediaItemIds: [item.id]),
      affects: tablesChanged({'frame_favorites'}),
    );
    if (!saved && mounted) setState(() => on ? _favorites.remove(item.id) : _favorites.add(item.id));
  }

  Future<void> _open(MediaItem item) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => item.isVideo
              ? VideoPlayerScreen(mediaId: item.id, url: item.displayUrl)
              : PhotoViewerScreen(item: item),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final albums = _albums;
    final items = _albumId == null ? null : _items[_albumId];
    return Scaffold(
      appBar: AppBar(title: Text(t.favoritesAddTitle(widget.frameName))),
      body: albums == null
          ? const Center(child: CircularProgressIndicator())
          : albums.isEmpty
              ? SmileEmptyState(icon: SmileIcons.album, title: t.noAlbumAssigned)
              : Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.m, vertical: SmileSpacing.s),
                        itemCount: albums.length,
                        separatorBuilder: (_, _) => const SizedBox(width: SmileSpacing.s),
                        itemBuilder: (context, i) {
                          final album = albums[i];
                          return ChoiceChip(
                            label: Text(albumNameOf(album.channelId, album.channelName)),
                            selected: album.channelId == _albumId,
                            onSelected: (_) => _pick(album.channelId),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: items == null
                          ? const Center(child: CircularProgressIndicator())
                          : items.isEmpty
                              ? SmileEmptyState(icon: SmileIcons.album, title: t.noPostsYet)
                              : GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    SmileSpacing.m,
                                    SmileSpacing.s,
                                    SmileSpacing.m,
                                    SmileSpacing.m + MediaQuery.paddingOf(context).bottom,
                                  ),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: SmileSpacing.s,
                                    mainAxisSpacing: SmileSpacing.s,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (context, i) {
                                    final item = items[i];
                                    final favorite = _favorites.contains(item.id);
                                    final url = item.thumbnailUrl ?? (item.isVideo ? null : item.displayUrl);
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(SmileRadius.m),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _open(item),
                                            child: url == null
                                                ? ColoredBox(color: scheme.surfaceContainerHighest)
                                                : CachedNetworkImage(
                                                    imageUrl: url,
                                                    cacheKey: '${item.id}_grid',
                                                    fit: BoxFit.cover,
                                                    fadeInDuration: Duration.zero,
                                                    errorWidget: (_, _, _) =>
                                                        ColoredBox(color: scheme.surfaceContainerHighest),
                                                  ),
                                          ),
                                          if (item.isVideo)
                                            const IgnorePointer(
                                              child: Center(child: Icon(SmileIcons.play, color: Colors.white70, size: 30)),
                                            ),
                                          // Big tap area, like on the Frame.
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _toggle(item),
                                              child: Padding(
                                                padding: const EdgeInsets.all(4),
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.45),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    favorite ? SmileIcons.heartFilled : SmileIcons.heart,
                                                    color: favorite ? SmileTheme.primary : Colors.white,
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
    );
  }
}
