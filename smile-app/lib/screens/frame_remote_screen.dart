import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../services/offline_http_client.dart';

import '../services/avatar_upload.dart';
import '../services/channel_picker_service.dart';
import '../services/frame_service.dart';
import '../services/local_changes.dart';
import '../services/sync_bus.dart';
import '../widgets/album_covers.dart';
import '../widgets/frame_status.dart';
import '../widgets/friendly_error.dart';
import '../widgets/local_display.dart';
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
      event.tables.contains('frames') || event.tables.contains('frame_channels') || event.tables.contains('channels');

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

  Future<void> _setAlbumSwitch(bool value) async {
    final frame = _frame;
    if (frame == null) return;
    setState(() => _frame = frame.copyWith(channelSwitchEnabled: value));
    await _save(() => _service.setChannelSwitchEnabled(frameId: widget.frameId, enabled: value));
  }

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
    FrameChannelAssignment? shown;
    for (final a in albums) {
      if (a.channelId == shownId) shown = a;
    }

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
                padding: const EdgeInsets.all(SmileSpacing.m),
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

                  // --- What it shows, and switching -------------------------
                  _Card(
                    children: [
                      _Label(t.nowShowingLabel),
                      Row(
                        children: [
                          if (shown != null) albumCover(shown.channelId, shown.channelName, _covers, size: 64),
                          const SizedBox(width: SmileSpacing.m),
                          Expanded(
                            child: Text(
                              shown == null ? t.noAlbumAssigned : albumNameOf(shown.channelId, shown.channelName),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      if (albums.length > 1) ...[
                        const SizedBox(height: SmileSpacing.m),
                        _Label(t.switchAlbum),
                        SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: albums.length,
                            separatorBuilder: (_, _) => const SizedBox(width: SmileSpacing.m),
                            itemBuilder: (context, i) {
                              final album = albums[i];
                              final current = album.channelId == shownId;
                              return InkWell(
                                borderRadius: BorderRadius.circular(SmileRadius.m),
                                onTap: () => _showNow(album),
                                child: SizedBox(
                                  width: 68,
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
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: SmileSpacing.m),

                  // --- Settings as tiles (more come here) -------------------
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
                          icon: SmileIcons.switchAlbum,
                          label: t.tileAlbumSwitch,
                          value: frame.channelSwitchEnabled ? t.valueAllowed : t.valueOff,
                          on: frame.channelSwitchEnabled,
                          onTap: () => _setAlbumSwitch(!frame.channelSwitchEnabled),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SmileSpacing.m),
                  _Card(
                    padding: EdgeInsets.zero,
                    children: [
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(SmileRadius.l),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
