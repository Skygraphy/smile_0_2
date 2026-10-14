import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_service.dart';
import '../services/local_changes.dart';
import '../services/sync_bus.dart';
import 'photo_viewer_screen.dart';
import 'video_player_screen.dart';

/// A Frame's Lieblingsbilder (decided 2026-10-14): newest marked first, each
/// with who marked it -- on the Frame or a name -- and when. Long press
/// selects (WhatsApp-like), "Entfernen" takes them off; "Alle entfernen" in
/// the ⋮ menu. The photos themselves stay in their albums.
class FrameFavoritesScreen extends StatefulWidget {
  const FrameFavoritesScreen({super.key, required this.frameId, required this.frameName, required this.frameService});

  final String frameId;
  final String frameName;
  final FrameService frameService;

  @override
  State<FrameFavoritesScreen> createState() => _FrameFavoritesScreenState();
}

class _FrameFavoritesScreenState extends State<FrameFavoritesScreen> with SyncReload {
  List<FrameFavorite>? _favorites;
  final Set<String> _selected = {};

  /// Taken off here, before the server has confirmed it.
  final Set<String> _removed = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  bool isSyncRelevant(SyncEvent event) => event.tables.contains('frame_favorites') || event.tables.contains('media_items');

  @override
  Future<void> onSync() => _load();

  Future<void> _load() async {
    try {
      final favorites = await widget.frameService.listFavorites(widget.frameId);
      if (mounted) setState(() => _favorites = favorites);
    } catch (_) {
      // Offline or the like: what was shown stays.
      if (mounted) setState(() => _favorites ??= const []);
    }
  }

  List<FrameFavorite> get _shown =>
      (_favorites ?? const <FrameFavorite>[]).where((f) => !_removed.contains(f.item.id)).toList();

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(String id) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  }

  /// Gone at once; back again if the server says no.
  Future<void> _remove(List<String>? ids) async {
    final gone = ids ?? _shown.map((f) => f.item.id).toList();
    setState(() {
      _removed.addAll(gone);
      _selected.clear();
    });
    final saved = await LocalChanges.instance.run(
      overrides: const {},
      commit: () => widget.frameService.removeFavorites(frameId: widget.frameId, mediaItemIds: ids),
      affects: tablesChanged({'frame_favorites'}),
    );
    if (!mounted) return;
    if (!saved) setState(() => _removed.removeAll(gone));
    await _load();
  }

  /// Asked first (2026-10-14), like "Alle entfernen".
  Future<void> _removeSelected() async {
    final t = SmileTexts.of(context);
    final ids = _selected.toList();
    final ok = await showSmileConfirmDialog(
      context,
      title: t.favoritesRemoveSelectedQuestion(ids.length, widget.frameName),
      message: t.favoritesRemoveHint,
      confirmLabel: t.favoritesRemove,
      destructive: true,
    );
    if (ok) await _remove(ids);
  }

  Future<void> _removeAll() async {
    final t = SmileTexts.of(context);
    final ok = await showSmileConfirmDialog(
      context,
      title: t.favoritesRemoveAllQuestion(widget.frameName),
      message: t.favoritesRemoveHint,
      confirmLabel: t.favoritesRemoveAll,
      destructive: true,
    );
    if (ok) await _remove(null);
  }

  Future<void> _open(FrameFavorite favorite) async {
    final item = favorite.item;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => item.isVideo
            ? VideoPlayerScreen(mediaId: item.id, url: item.displayUrl)
            : PhotoViewerScreen(item: item),
      ),
    );
  }

  static const _months = ['Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.'];

  /// "Am Frame · heute 9:41", "Ernst · 10. Okt."
  String _caption(SmileTexts t, FrameFavorite favorite) {
    final who = favorite.onFrame ? t.favoriteOnFrame : (favorite.markedByName ?? t.someone);
    final at = favorite.markedAt.toLocal();
    final now = DateTime.now();
    final time = '${at.hour}:${at.minute.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final when = sameDay(at, now)
        ? t.favoriteToday(time)
        : sameDay(at, yesterday)
            ? t.favoriteYesterday(time)
            : '${at.day}. ${_months[at.month - 1]}${at.year == now.year ? '' : ' ${at.year}'}';
    return '$who · $when';
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final shown = _shown;
    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(icon: const Icon(SmileIcons.close), onPressed: () => setState(_selected.clear)),
              title: Text(t.favoritesSelected(_selected.length)),
              actions: [
                IconButton(
                  icon: const Icon(SmileIcons.selectAll),
                  tooltip: t.selectAll,
                  onPressed: () => setState(() => _selected.addAll(shown.map((f) => f.item.id))),
                ),
                IconButton(
                  icon: const Icon(SmileIcons.delete),
                  tooltip: t.favoritesRemove,
                  onPressed: _removeSelected,
                ),
              ],
            )
          : AppBar(
              title: Text(t.favorites),
              actions: [
                if (shown.isNotEmpty)
                  PopupMenuButton<VoidCallback>(
                    icon: const Icon(SmileIcons.more),
                    tooltip: t.moreOptions,
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _removeAll,
                        child: Row(
                          children: [
                            const Icon(SmileIcons.delete, size: 20),
                            const SizedBox(width: SmileSpacing.m),
                            Text(t.favoritesRemoveAll),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
      body: _favorites == null
          ? const Center(child: CircularProgressIndicator())
          : shown.isEmpty
              ? SmileEmptyState(icon: SmileIcons.heart, title: t.favoritesEmpty, message: t.favoritesEmptyHint)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      SmileSpacing.m,
                      SmileSpacing.m,
                      SmileSpacing.m,
                      SmileSpacing.m + MediaQuery.paddingOf(context).bottom,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: SmileSpacing.s,
                      mainAxisSpacing: SmileSpacing.m,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final favorite = shown[i];
                      final item = favorite.item;
                      final selected = _selected.contains(item.id);
                      final url = item.thumbnailUrl ?? (item.isVideo ? null : item.displayUrl);
                      return GestureDetector(
                        onTap: _selecting ? () => _toggle(item.id) : () => _open(favorite),
                        onLongPress: () => _toggle(item.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(SmileRadius.m),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    url == null
                                        ? ColoredBox(color: scheme.surfaceContainerHighest)
                                        : CachedNetworkImage(
                                            imageUrl: url,
                                            cacheKey: '${item.id}_grid',
                                            fit: BoxFit.cover,
                                            fadeInDuration: Duration.zero,
                                            errorWidget: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
                                          ),
                                    if (item.isVideo)
                                      const Center(child: Icon(SmileIcons.play, color: Colors.white70, size: 32)),
                                    if (selected) ...[
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: scheme.primary, width: 3),
                                          borderRadius: BorderRadius.circular(SmileRadius.m),
                                          color: Colors.black26,
                                        ),
                                      ),
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Icon(SmileIcons.selected, color: scheme.primary, size: 22),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _caption(t, favorite),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, height: 1.25),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
