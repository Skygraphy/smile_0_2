import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/avatar_upload.dart';
import '../services/channel_picker_service.dart';
import '../services/frame_service.dart';
import '../services/local_changes.dart';
import '../services/offline.dart';
import '../services/sync_bus.dart';
import '../widgets/album_covers.dart';
import '../widgets/frame_status.dart';
import '../widgets/friendly_error.dart';
import '../widgets/local_display.dart';
import '../widgets/top_bar_actions.dart';
import 'frame_remote_screen.dart';

/// The "Frames" tab (decided 2026-10-11): every Frame one manages as a
/// card -- online or not, what it shows, sound and album switching right
/// there. A tap opens its remote control (FrameRemoteScreen).
class FramesScreen extends StatefulWidget {
  const FramesScreen({super.key});

  @override
  State<FramesScreen> createState() => _FramesScreenState();
}

class _FramesScreenState extends State<FramesScreen> with SyncReload {
  final _service = FrameService();
  List<ManagedFrame>? _frames;
  Map<String, ChannelWithActivity> _covers = const {};
  /// Sound flipped on a card, before the server's answer.
  final Map<String, bool> _sound = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() => _load();

  Future<void> _load() async {
    unawaited(loadAlbumCovers().then((c) {
      if (mounted) setState(() => _covers = c);
    }));
    try {
      final frames = await _service.listMyFrames();
      if (!mounted) return;
      setState(() {
        _frames = frames;
        _sound.clear();
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      final offline = Offline.noteFailure(e);
      setState(() {
        _frames ??= const [];
        _errorMessage = offline ? null : SmileTexts.of(context).frameInfoLoadError(errorReason(context, e));
      });
    }
  }

  Future<void> _open(ManagedFrame item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FrameRemoteScreen(
          frameId: item.frame.id,
          frame: item.frame,
          spaceId: item.spaceId,
          spaceName: item.spaceName,
        ),
      ),
    );
    if (mounted) await _load();
  }

  bool _soundOf(ManagedFrame item) => _sound[item.frame.id] ?? item.frame.videoSound;

  Future<void> _toggleSound(ManagedFrame item) async {
    final value = !_soundOf(item);
    setState(() => _sound[item.frame.id] = value);
    final saved = await LocalChanges.instance.run(
      overrides: const {},
      commit: () => _service.setVideoSound(frameId: item.frame.id, enabled: value),
      affects: tablesChanged({'frames'}, spaceIds: {item.spaceId}),
    );
    if (!saved && mounted) await _load();
  }

  /// The card's "Album wechseln": its albums as a list, one tap switches.
  Future<void> _switchAlbum(ManagedFrame item) async {
    final t = SmileTexts.of(context);
    final List<FrameChannelAssignment> albums;
    try {
      albums = await _service.listAssignedChannels(item.frame.id);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed(errorReasonIn(t, e)));
      return;
    }
    if (!mounted) return;
    final current = LocalChanges.instance.text(LocalChanges.frameAlbum(item.frame.id)) ?? item.frame.currentChannelId;
    final picked = await showModalBottomSheet<FrameChannelAssignment>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.s),
              child: Text(t.switchAlbum, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            if (albums.isEmpty) SmileSectionHint(icon: SmileIcons.album, text: t.noAlbumAssigned),
            for (final album in albums)
              SmileObjectTile(
                leading: albumCover(album.channelId, album.channelName, _covers, size: 40),
                title: albumNameOf(album.channelId, album.channelName),
                subtitle: album.channelId == current ? t.showingNow : null,
                subtitleIcon: SmileIcons.play,
                subtitleHighlight: true,
                onTap: () => Navigator.of(sheetContext).pop(album),
              ),
            const SizedBox(height: SmileSpacing.m),
          ],
        ),
      ),
    );
    if (picked == null || picked.channelId == current || !mounted) return;
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.frameAlbum(item.frame.id): picked.channelId},
      commit: () => _service.showChannelNow(frameId: item.frame.id, channelId: picked.channelId),
      affects: tablesChanged({'frames'}, spaceIds: {item.spaceId}),
    );
    if (saved && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final frames = _frames;
    return Scaffold(
      appBar: AppBar(title: Text(t.frames), actions: smileTopBarActions()),
      body: frames == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(SmileSpacing.m),
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SmileSpacing.m),
                      child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (frames.isEmpty) SmileEmptyState(icon: SmileIcons.frame, title: t.noFrameYet),
                  for (final item in frames) ...[
                    _FrameCard(
                      item: item,
                      covers: _covers,
                      sound: _soundOf(item),
                      onOpen: () => _open(item),
                      onToggleSound: () => _toggleSound(item),
                      onSwitchAlbum: () => _switchAlbum(item),
                    ),
                    const SizedBox(height: SmileSpacing.m),
                  ],
                ],
              ),
            ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.item,
    required this.covers,
    required this.sound,
    required this.onOpen,
    required this.onToggleSound,
    required this.onSwitchAlbum,
  });

  final ManagedFrame item;
  final Map<String, ChannelWithActivity> covers;
  final bool sound;
  final VoidCallback onOpen;
  final VoidCallback onToggleSound;
  final VoidCallback onSwitchAlbum;

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final frame = item.frame;
    final name = frameNameOf(frame.id, frame.name);
    final currentId = LocalChanges.instance.text(LocalChanges.frameAlbum(frame.id)) ?? frame.currentChannelId;
    // The name for an own switch just made comes from the album list.
    final currentName = currentId == null
        ? null
        : currentId == frame.currentChannelId
            ? item.currentAlbumName
            : covers[currentId]?.channelName;

    Widget quick(IconData icon, String label, VoidCallback onTap, {bool on = false}) => Expanded(
          child: Material(
            color: on ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(SmileRadius.m),
            child: InkWell(
              borderRadius: BorderRadius.circular(SmileRadius.m),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: on ? scheme.primary : scheme.onSurface),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(color: on ? scheme.primary : scheme.onSurface)),
                  ],
                ),
              ),
            ),
          ),
        );

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(SmileRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(SmileRadius.l),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(SmileSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SmileStatusDot(
                    online: frame.isOnline,
                    child: objectPicture(
                      key: LocalChanges.framePicture(frame.id),
                      name: name,
                      serverUrl: avatarPathToUrl(frame.avatarPath),
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: SmileSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          frameStatusLine(t, frame, spaceName: item.spaceName),
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(SmileIcons.chevron, color: scheme.onSurfaceVariant),
                ],
              ),
              if (currentId != null) ...[
                const SizedBox(height: SmileSpacing.m),
                Row(
                  children: [
                    albumCover(currentId, currentName ?? '', covers, size: 40),
                    const SizedBox(width: SmileSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.nowShowingLabel, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          Text(currentName == null ? '…' : albumNameOf(currentId, currentName)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SmileSpacing.m),
              Row(
                children: [
                  quick(sound ? SmileIcons.soundOn : SmileIcons.soundOff, sound ? t.soundOn : t.soundOff, onToggleSound,
                      on: sound),
                  const SizedBox(width: SmileSpacing.s),
                  quick(SmileIcons.switchAlbum, t.switchAlbum, onSwitchAlbum),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
