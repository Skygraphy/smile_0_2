import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../services/offline_http_client.dart';

import '../services/avatar_upload.dart';
import '../services/channel_picker_service.dart';
import '../services/frame_controls.dart';
import '../services/frame_service.dart';
import '../services/local_changes.dart';
import '../services/sync_bus.dart';
import '../widgets/album_covers.dart';
import '../widgets/frame_status.dart';
import '../widgets/friendly_error.dart';
import '../widgets/local_display.dart';
import 'frame_controls_screen.dart';
import 'frame_favorites_screen.dart';
import 'frame_playback_screen.dart';
import 'frame_settings_screen.dart';

/// A Frame's remote control (decided 2026-10-11): what it shows, every
/// album of it one tap away, and the everyday settings as big tiles --
/// new functions are added here as further tiles. The rarer things (name,
/// picture, device, albums, delete) stay on FrameSettingsScreen
/// ("Einstellungen & Gerät").
class FrameRemoteScreen extends StatefulWidget {
  const FrameRemoteScreen({super.key, required this.frameId, this.frame, this.spaceId, this.spaceName});

  final String frameId;
  /// What the caller already knows -- shown at once, then refreshed.
  final SmileFrame? frame;
  final String? spaceId;
  final String? spaceName;

  @override
  State<FrameRemoteScreen> createState() => _FrameRemoteScreenState();
}

class _FrameRemoteScreenState extends State<FrameRemoteScreen> with SyncReload {
  final _service = FrameService();
  late SmileFrame? _frame = widget.frame;
  late String? _spaceId = widget.spaceId;
  late String? _spaceName = widget.spaceName;
  List<FrameChannelAssignment>? _assignments;
  Map<String, ChannelWithActivity> _covers = const {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFromPhoneThenServer());
  }

  @override
  bool isSyncRelevant(SyncEvent event) =>
      event.tables.contains('frames') ||
      event.tables.contains('frame_channels') ||
      event.tables.contains('channels') ||
      event.tables.contains('frame_favorites');

  @override
  Future<void> onSync() async {
    if (await closeIfGone(context, table: 'frames', id: widget.frameId)) return;
    await _load();
  }

  /// What it showed last, at once from the phone -- then from the server
  /// (2026-10-12: every info page opened with a spinner first).
  Future<void> _loadFromPhoneThenServer() async {
    await OfflineCachingClient.fromPhone(_load);
    await _load();
  }

  Future<void> _load() async {
    unawaited(loadAlbumCovers().then((c) {
      if (mounted) setState(() => _covers = c);
    }));
    // Best effort: without it the section just doesn't show yet.
    unawaited(_service.listFavorites(widget.frameId).then((f) {
      if (mounted) setState(() => _favorites = f);
    }).catchError((Object _) {}));
    try {
      final results = await Future.wait<dynamic>([
        _service.getFrameWithSpace(widget.frameId),
        _service.listAssignedChannels(widget.frameId),
      ]);
      if (!mounted) return;
      final found = results[0] as ({SmileFrame frame, String spaceId, String spaceName});
      setState(() {
        _frame = found.frame;
        _spaceId = found.spaceId;
        _spaceName = found.spaceName;
        _assignments = results[1] as List<FrameChannelAssignment>;
        _errorMessage = null;
      });
    } catch (e) {
      if (CacheMissException.isIn(e)) return;
      if (!mounted) return;
      setState(() {
        _assignments ??= const [];
        _errorMessage = SmileTexts.of(context).frameInfoLoadError(errorReason(context, e));
      });
    }
  }

  String get _shownName => frameNameOf(widget.frameId, _frame?.name ?? '');

  List<FrameChannelAssignment> get _albums => (_assignments ?? const <FrameChannelAssignment>[])
      .where((a) => !LocalChanges.instance.flag(LocalChanges.frameAlbumRemoved(widget.frameId, a.channelId)))
      .toList();

  /// What it shows right now -- an own switch included; before its first
  /// sync, its first album.
  String? get _shownChannelId {
    final albums = _albums;
    final current = LocalChanges.instance.text(LocalChanges.frameAlbum(widget.frameId)) ?? _frame?.currentChannelId;
    if (current != null && albums.any((a) => a.channelId == current)) return current;
    return albums.isEmpty ? null : albums.first.channelId;
  }

  Future<void> _showNow(FrameChannelAssignment album) async {
    if (album.channelId == _shownChannelId) return;
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.frameAlbum(widget.frameId): album.channelId},
      commit: () => _service.showChannelNow(frameId: widget.frameId, channelId: album.channelId),
      affects: tablesChanged({'frames'}, spaceIds: {?_spaceId}),
    );
    if (saved && mounted) await _load();
  }

  /// Optimistic: the tile flips at once; a failure says why and reloads.
  Future<void> _setVideoSound(bool value) async {
    final frame = _frame;
    if (frame == null) return;
    setState(() => _frame = frame.copyWith(videoSound: value));
    await _save(() => _service.setVideoSound(frameId: widget.frameId, enabled: value));
  }

  /// The Frame's Lieblingsbilder (newest marked first); null until loaded.
  List<FrameFavorite>? _favorites;

  Future<void> _openFavorites() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrameFavoritesScreen(frameId: widget.frameId, frameName: _shownName, frameService: _service),
      ),
    );
    if (mounted) await _load();
  }

  /// The album strip always shows the running album (2026-10-14): it
  /// scrolls there when the page opens and whenever another one runs.
  static const _albumTileWidth = 72.0;
  final _albumStrip = ScrollController();
  String? _scrolledTo;

  void _keepShownVisible(List<FrameChannelAssignment> albums, String? shownId) {
    if (shownId == null || shownId == _scrolledTo) return;
    final index = albums.indexWhere((a) => a.channelId == shownId);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_albumStrip.hasClients) return;
      final position = _albumStrip.position;
      const step = _albumTileWidth + SmileSpacing.m;
      final left = index * step;
      // Already fully in view: leave it where it is.
      if (left >= position.pixels && left + _albumTileWidth <= position.pixels + position.viewportDimension) {
        _scrolledTo = shownId;
        return;
      }
      // Otherwise centred, as far as the strip goes.
      final target = (left - (position.viewportDimension - _albumTileWidth) / 2).clamp(0.0, position.maxScrollExtent);
      _scrolledTo = shownId;
      unawaited(_albumStrip.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut));
    });
  }

  @override
  void dispose() {
    _albumStrip.dispose();
    super.dispose();
  }

  /// "+" in the album strip: another album of the Space (or shared with
  /// it) onto this Frame -- it runs right away.
  Future<void> _addAlbum() async {
    final t = SmileTexts.of(context);
    final spaceId = _spaceId;
    if (spaceId == null) return;
    final List<AssignableChannel> choices;
    try {
      choices = await _service.listUnassignedChannelsInSpace(spaceId: spaceId, frameId: widget.frameId);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    if (choices.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.addAlbumToFrame),
          content: Text(t.noMoreAlbums),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.close))],
        ),
      );
      return;
    }
    final picked = await showDialog<AssignableChannel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t.addAlbumToFrame),
        children: [
          for (final album in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(album),
              child: Row(
                children: [
                  albumCover(album.channelId, album.channelName, _covers, size: 32),
                  const SizedBox(width: SmileSpacing.m),
                  Expanded(child: Text(album.channelName)),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.frameAlbum(widget.frameId): picked.channelId},
      commit: () async {
        await _service.assignChannel(frameId: widget.frameId, channelId: picked.channelId);
        await _service.showChannelNow(frameId: widget.frameId, channelId: picked.channelId);
      },
      affects: tablesChanged({'frames', 'frame_channels'}, spaceIds: {spaceId}),
    );
    if (saved && mounted) await _load();
  }

  /// The remote control (2026-10-14): carried out by the Frame at once,
  /// whatever its control level. Fire and forget -- a Frame that is
  /// offline simply doesn't move.
  bool _remotePaused = false;

  Future<void> _command(String command) async {
    unawaited(HapticFeedback.selectionClick());
    if (command == 'pause' || command == 'play') setState(() => _remotePaused = command == 'pause');
    try {
      await _service.sendCommand(frameId: widget.frameId, command: command);
    } catch (_) {}
  }

  Future<void> _openPage(Widget Function(SmileFrame frame, String? spaceId) page) async {
    final frame = _frame;
    if (frame == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page(frame, _spaceId)));
    if (mounted) await _load();
  }

  String _levelName(SmileTexts t, SmileFrame frame) =>
      switch (frame.controlLevel ?? FrameControlLevels.levelOf(frame.controls)) {
        1 => t.level1,
        2 => t.level2,
        3 => t.level3,
        4 => t.level4,
        5 => t.level5,
        _ => t.levelCustom,
      };

  String _playbackSummary(SmileTexts t, SmileFrame frame) => [
        switch (frame.contentMode) {
          'rotate' => t.contentRotate,
          'recent' => t.recentLast(frame.recentCount),
          'favorites' => t.contentFavorites,
          _ => t.contentAlbum,
        },
        switch (frame.playOrder) {
          'newest' => t.orderNewest,
          'shuffle' => t.orderShuffle,
          _ => t.orderOldest,
        },
        frame.intervalSeconds == 60 ? t.oneMinute : t.secondsValue(frame.intervalSeconds),
      ].join(' · ');

  Future<void> _save(Future<void> Function() save) async {
    final saved = await LocalChanges.instance.run(
      overrides: const {},
      commit: save,
      affects: tablesChanged({'frames'}, spaceIds: {?_spaceId}),
    );
    if (!saved && mounted) await _load();
  }

  Future<void> _openSettings() async {
    final frame = _frame;
    final spaceId = _spaceId;
    if (frame == null || spaceId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrameSettingsScreen(frame: frame, spaceId: spaceId, spaceName: _spaceName, frameService: _service),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final frame = _frame;
    final albums = _albums;
    final shownId = _shownChannelId;
    _keepShownVisible(albums, shownId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_shownName),
        actions: [
          IconButton(icon: const Icon(SmileIcons.settings), tooltip: t.settingsAndDevice, onPressed: _openSettings),
        ],
      ),
      body: frame == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(SmileSpacing.m, SmileSpacing.m, SmileSpacing.m, SmileSpacing.m + MediaQuery.paddingOf(context).bottom),
                children: [
                  Center(
                    child: SmileStatusDot(
                      online: frame.isOnline,
                      child: objectPicture(
                        key: LocalChanges.framePicture(widget.frameId),
                        name: _shownName,
                        serverUrl: avatarPathToUrl(frame.avatarPath),
                        size: 72,
                      ),
                    ),
                  ),
                  const SizedBox(height: SmileSpacing.s),
                  Text(
                    frameStatusLine(t, frame, spaceName: _spaceName),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: SmileSpacing.s),
                      child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
                    ),
                  const SizedBox(height: SmileSpacing.l),

                  // --- Its albums: the one running marked, a tap runs another,
                  // "+" adds one (2026-10-14: "Läuft gerade" and "Album
                  // wechseln" showed the same thing twice).
                  _Card(
                    children: [
                      // A round or not one album: said here, and no album is
                      // marked "läuft gerade" (2026-10-14).
                      _Label(
                        framePlaysLabel(t, contentMode: frame.contentMode, playingRound: frame.playingRound) == null
                            ? t.albums
                            : [
                                t.albums,
                                [t.nowRunning, framePlaysLabel(t, contentMode: frame.contentMode, playingRound: frame.playingRound)!].join(': '),
                              ].join(' · '),
                      ),
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          controller: _albumStrip,
                          scrollDirection: Axis.horizontal,
                          itemCount: albums.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: SmileSpacing.m),
                          itemBuilder: (context, i) {
                            if (i == albums.length) {
                              return InkWell(
                                borderRadius: BorderRadius.circular(SmileRadius.m),
                                onTap: _addAlbum,
                                child: SizedBox(
                                  width: _albumTileWidth,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 58,
                                        height: 58,
                                        margin: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(SmileRadius.m),
                                          border: Border.all(color: scheme.outlineVariant, width: 1.5),
                                        ),
                                        child: Icon(SmileIcons.add, color: scheme.primary, size: 28),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(t.addShort, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final album = albums[i];
                            final current = album.channelId == shownId &&
                                framePlaysLabel(t, contentMode: frame.contentMode, playingRound: frame.playingRound) == null;
                            return InkWell(
                              borderRadius: BorderRadius.circular(SmileRadius.m),
                              onTap: () => _showNow(album),
                              child: SizedBox(
                                width: _albumTileWidth,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(SmileRadius.m + 3),
                                        border: Border.all(color: current ? scheme.primary : Colors.transparent, width: 3),
                                      ),
                                      child: albumCover(album.channelId, album.channelName, _covers, size: 52),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      albumNameOf(album.channelId, album.channelName),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11.5, color: current ? scheme.onSurface : scheme.onSurfaceVariant),
                                    ),
                                    // Always in full -- only the album name is
                                    // shortened (2026-10-14).
                                    if (current)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          t.nowRunning,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SmileSpacing.m),

                  // --- Remote control (2026-10-14) ----------------------------
                  _Card(
                    children: [
                      _Label(t.remoteTitle),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoundButton(icon: SmileIcons.previous, tooltip: t.ctrlBack, onTap: () => _command('back')),
                          _RoundButton(
                            icon: _remotePaused ? SmileIcons.playFilled : SmileIcons.pause,
                            tooltip: _remotePaused ? t.ctrlPlay : t.ctrlPause,
                            main: true,
                            onTap: () => _command(_remotePaused ? 'play' : 'pause'),
                          ),
                          _RoundButton(icon: SmileIcons.nextItem, tooltip: t.ctrlNext, onTap: () => _command('next')),
                        ],
                      ),
                      const SizedBox(height: SmileSpacing.m),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(SmileIcons.newest),
                          label: Text(t.remoteNewest(20)),
                          onPressed: () => _command('newest'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SmileSpacing.m),

                  // --- Lieblingsbilder (2026-10-14) -----------------------------
                  _Card(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _Label(t.favoritesCount((_favorites ?? const []).length))),
                          Padding(
                            padding: const EdgeInsets.only(bottom: SmileSpacing.s),
                            child: InkWell(
                              onTap: _openFavorites,
                              child: Text(t.favoritesSeeAll, style: TextStyle(color: scheme.primary, fontSize: 13.5)),
                            ),
                          ),
                        ],
                      ),
                      if ((_favorites ?? const []).isEmpty)
                        Text(t.favoritesEmptyHint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))
                      else
                        InkWell(
                          onTap: _openFavorites,
                          child: Row(
                            children: [
                              for (final favorite in _favorites!.take(4))
                                Padding(
                                  padding: const EdgeInsets.only(right: SmileSpacing.s),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(SmileRadius.m),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: favorite.item.thumbnailUrl == null
                                          ? ColoredBox(color: scheme.surfaceContainerHighest)
                                          : CachedNetworkImage(
                                              imageUrl: favorite.item.thumbnailUrl!,
                                              cacheKey: '${favorite.item.id}_grid',
                                              fit: BoxFit.cover,
                                              fadeInDuration: Duration.zero,
                                              errorWidget: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
                                            ),
                                    ),
                                  ),
                                ),
                              if (_favorites!.length > 4)
                                Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(SmileRadius.m),
                                  ),
                                  child: Text('+${_favorites!.length - 4}', style: TextStyle(color: scheme.onSurfaceVariant)),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: SmileSpacing.m),

                  // --- Settings as tiles --------------------------------------
                  Row(
                    children: [
                      Expanded(
                        child: _Tile(
                          icon: frame.videoSound ? SmileIcons.soundOn : SmileIcons.soundOff,
                          label: t.tileVideoSound,
                          value: frame.videoSound ? t.valueOn : t.valueOff,
                          on: frame.videoSound,
                          onTap: () => _setVideoSound(!frame.videoSound),
                        ),
                      ),
                      const SizedBox(width: SmileSpacing.m),
                      Expanded(
                        child: _Tile(
                          icon: SmileIcons.controls,
                          label: t.controlLevel,
                          value: _levelName(t, frame),
                          on: true,
                          onTap: () => _openPage(
                            (f, spaceId) => FrameControlsScreen(frame: f, spaceId: spaceId, frameService: _service),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SmileSpacing.m),
                  _Card(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(SmileIcons.playback),
                        title: Text(t.playbackTitle),
                        subtitle: Text(_playbackSummary(t, frame)),
                        trailing: Icon(SmileIcons.chevron, size: 16, color: scheme.onSurfaceVariant),
                        onTap: () => _openPage(
                          (f, spaceId) => FramePlaybackScreen(frame: f, spaceId: spaceId, frameService: _service),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(SmileIcons.controls),
                        title: Text(t.controlsTitle),
                        subtitle: Text(_levelName(t, frame)),
                        trailing: Icon(SmileIcons.chevron, size: 16, color: scheme.onSurfaceVariant),
                        onTap: () => _openPage(
                          (f, spaceId) => FrameControlsScreen(frame: f, spaceId: spaceId, frameService: _service),
                        ),
                      ),
                      SmileActionRow(icon: SmileIcons.album, label: t.manageAlbums, onTap: _openSettings),
                      SmileActionRow(icon: SmileIcons.settings, label: t.settingsAndDevice, onTap: _openSettings),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children, this.padding = const EdgeInsets.all(SmileSpacing.m)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // A Material, not a coloured Container: ListTiles paint their ink on it
    // (Crashlytics 2026-10-15).
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(SmileRadius.l),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SmileSpacing.s),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}

/// A remote-control button: round and big; coral for the main one.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.main = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool main;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: main ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, size: 28, color: main ? scheme.onPrimary : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// One setting, big enough to hit without looking twice; coral when on.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, required this.on, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.primaryContainer : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(SmileRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(SmileRadius.l),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SmileSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: on ? scheme.primary : scheme.onSurface),
              const SizedBox(height: SmileSpacing.s),
              Text(label),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 12.5, color: on ? scheme.primary : scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
