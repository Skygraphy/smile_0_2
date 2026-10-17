import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../services/offline_http_client.dart';
import '../widgets/friendly_error.dart';

import '../services/frame_service.dart';
import '../services/channel_picker_service.dart';
import '../widgets/album_covers.dart';
import '../widgets/local_display.dart';
import '../services/local_changes.dart';
import '../services/avatar_upload.dart';
import '../services/object_picture_service.dart';
import '../widgets/picture_sheet.dart';
import '../services/sync_bus.dart';
import 'channel_feed_screen.dart';
import 'create_frame_screen.dart';

/// A Frame's info page, same pattern as Album and Space: icon + name
/// (tap to rename), status (device, last seen, app version, battery),
/// settings (video sound, album switch), which albums it shows, and
/// revoke/reactivate last. No MDM/compliance surface (removed with the
/// architecture reset, migrations/0031) -- just operational telemetry.
class FrameSettingsScreen extends StatefulWidget {
  const FrameSettingsScreen({
    super.key,
    required this.frame,
    required this.spaceId,
    required this.frameService,
    this.spaceName,
  });

  final SmileFrame frame;
  final String spaceId;
  final String? spaceName;
  final FrameService frameService;

  @override
  State<FrameSettingsScreen> createState() => _FrameSettingsScreenState();
}

class _FrameSettingsScreenState extends State<FrameSettingsScreen> with SyncReload {
  late SmileFrame _frame = widget.frame;
  List<FrameChannelAssignment>? _assignments;
  Map<String, ChannelWithActivity> _covers = const {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFromPhoneThenServer());
  }

  @override
  Future<void> onSync() async {
    if (await closeIfGone(context, table: 'frames', id: widget.frame.id)) return;
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
        widget.frameService.getFrame(widget.frame.id),
        widget.frameService.listAssignedChannels(widget.frame.id),
      ]);
      if (!mounted) return;
      setState(() {
        _frame = results[0] as SmileFrame;
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

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = SmileTexts.of(context).actionFailed(errorReason(context, e)));
    }
  }

  Future<void> _rename() async {
    final t = SmileTexts.of(context);
    final name = await showSmileNameDialog(context, title: t.renameFrame, confirmLabel: t.save, initialValue: _shownName);
    if (name == null) return;
    // Shows at once everywhere (LocalChanges, 2026-10-09).
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.frameName(_frame.id): name},
      commit: () => widget.frameService.renameFrame(frameId: _frame.id, name: name),
      affects: tablesChanged({'frames'}, spaceIds: {widget.spaceId}),
    );
    if (saved && mounted) await _load();
  }

  Future<void> _toggleRevoked() async {
    final t = SmileTexts.of(context);
    final revoking = !_frame.isRevoked;
    if (revoking) {
      final confirmed = await showSmileConfirmDialog(
        context,
        title: '${t.revokeFrame}?',
        message: t.revokeFrameMessage,
        confirmLabel: t.frameRevoked,
        destructive: true,
      );
      if (!confirmed) return;
    }
    await _run(() => widget.frameService.setRevoked(frameId: _frame.id, revoked: revoking));
  }

  Future<void> _delete() async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.deleteFrameTitle(_frame.name),
      message: t.deleteFrameMessage,
      names: [_frame.name],
      confirmLabel: t.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.frameService.deleteFrame(_frame.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed(errorReason(context, e)));
    }
  }

  /// Optimistic: the switch moves at once, a failure says why and reloads
  /// the truth.
  Future<void> _setAlbumSwitch(bool value) async {
    setState(() => _frame = _frame.copyWith(channelSwitchEnabled: value));
    await _saveSetting(() => widget.frameService.setChannelSwitchEnabled(frameId: _frame.id, enabled: value));
  }

  Future<void> _setVideoSound(bool value) async {
    setState(() => _frame = _frame.copyWith(videoSound: value));
    await _saveSetting(() => widget.frameService.setVideoSound(frameId: _frame.id, enabled: value));
  }

  Future<void> _saveSetting(Future<void> Function() save) async {
    final saved = await LocalChanges.instance.run(
      overrides: const {},
      commit: save,
      affects: tablesChanged({'frames'}, spaceIds: {widget.spaceId}),
    );
    if (!saved && mounted) await _load();
  }

  String get _shownName => frameNameOf(_frame.id, _frame.name);

  /// Albums still on the Frame -- one just taken off is gone at once.
  List<FrameChannelAssignment>? get _visibleAssignments => _assignments
      ?.where((a) => !LocalChanges.instance.flag(LocalChanges.frameAlbumRemoved(_frame.id, a.channelId)))
      .toList();

  Future<void> _addAlbum() async {
    final t = SmileTexts.of(context);
    final choices = await widget.frameService.listUnassignedChannelsInSpace(spaceId: widget.spaceId, frameId: _frame.id);
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
    await _run(() => widget.frameService.assignChannel(frameId: _frame.id, channelId: picked.channelId));
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  /// The album the Frame shows right now: the server's current album
  /// (migrations/0069), else -- before its first sync -- the first one.
  String? get _shownChannelId {
    final assignments = _visibleAssignments ?? const <FrameChannelAssignment>[];
    final current = LocalChanges.instance.text(LocalChanges.frameAlbum(_frame.id)) ?? _frame.currentChannelId;
    if (current != null && assignments.any((a) => a.channelId == current)) return current;
    return assignments.isEmpty ? null : assignments.first.channelId;
  }

  Future<void> _showNow(FrameChannelAssignment assignment) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = SmileTexts.of(context);
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.frameAlbum(_frame.id): assignment.channelId},
      commit: () => widget.frameService.showChannelNow(frameId: _frame.id, channelId: assignment.channelId),
      affects: tablesChanged({'frames'}, spaceIds: {widget.spaceId}),
    );
    if (saved) {
      messenger.showSnackBar(
        SnackBar(
          content: SmileNamedText(
            t.frameSwitched(_shownName, albumNameOf(assignment.channelId, assignment.channelName)),
            names: [_shownName, albumNameOf(assignment.channelId, assignment.channelName)],
          ),
        ),
      );
      if (mounted) await _load();
    }
  }

  Future<void> _showAlbumActions(FrameChannelAssignment assignment) async {
    final t = SmileTexts.of(context);
    final isShown = assignment.channelId == _shownChannelId;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: albumCover(assignment.channelId, assignment.channelName, _covers, size: 36),
              title: Text(albumNameOf(assignment.channelId, assignment.channelName)),
            ),
            if (!isShown)
              SmileActionRow(
                icon: SmileIcons.play,
                label: t.showNow,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showNow(assignment);
                },
              ),
            SmileActionRow(
              icon: SmileIcons.album,
              label: t.openAlbum,
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChannelFeedScreen(channelId: assignment.channelId, channelName: assignment.channelName),
                  ),
                );
              },
            ),
            SmileActionRow(
              icon: SmileIcons.close,
              label: t.removeFromFrame,
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _removeAlbum(assignment);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAlbum(FrameChannelAssignment assignment) async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.removeFromFrameTitle(assignment.channelName),
      message: t.removeFromFrameMessage,
      names: [assignment.channelName],
      confirmLabel: t.actionRemove,
      destructive: true,
    );
    if (!confirmed) return;
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.frameAlbumRemoved(_frame.id, assignment.channelId): true},
      commit: () => widget.frameService.unassignChannel(frameId: _frame.id, channelId: assignment.channelId),
      affects: tablesChanged({'frame_channels', 'frames'}, channelIds: {assignment.channelId}, spaceIds: {widget.spaceId}),
    );
    if (saved && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final assignments = _visibleAssignments;
    final scheme = Theme.of(context).colorScheme;
    final status = switch (_frame.lifecycleState) {
      'active' => t.frameActive,
      'revoked' => t.frameRevoked,
      _ => t.framePending,
    };
    final spaceName = widget.spaceName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(SmileIconsBold.back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: assignments == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  SmileInfoHeader(
                    icon: SmileIcons.frame,
                    leading: SmileEditablePicture(
                      tooltip: t.changeObjectPicture,
                      onEdit: () async {
                        final changed = await changeObjectPicture(
                          context,
                          kind: ObjectKind.frame,
                          id: _frame.id,
                          name: _shownName,
                          hasCustomPicture: _frame.avatarPath != null,
                        );
                        if (changed) await _load();
                      },
                      child: SmileStatusDot(
                        online: _frame.isOnline,
                        child: objectPicture(
                          key: LocalChanges.framePicture(_frame.id),
                          name: _shownName,
                          serverUrl: avatarPathToUrl(_frame.avatarPath),
                          size: 80,
                        ),
                      ),
                    ),
                    title: _shownName,
                    subtitleIcon: spaceName == null ? null : SmileIcons.space,
                    subtitle: [if (spaceName != null) t.frameInSpace(spaceName), status].join(' · '),
                    onRename: _rename,
                    renameTooltip: t.renameFrame,
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(_errorMessage!, style: TextStyle(color: scheme.error)),
                    ),
                  SmileInfoSection(
                    title: t.status,
                    children: [
                      _statusRow(t.device, _frame.deviceModel ?? '—'),
                      _statusRow(t.lastSeen, _formatDateTime(_frame.lastSeenAt)),
                      _statusRow(t.appVersion, _frame.currentAppVersion ?? '—'),
                      _statusRow(
                        t.battery,
                        _frame.batteryLevel != null
                            ? '${_frame.batteryLevel} %${_frame.isCharging == true ? ' (${t.charging})' : ''}'
                            : '—',
                      ),
                      const SizedBox(height: SmileSpacing.s),
                    ],
                  ),
                  SmileInfoSection(
                    title: t.settings,
                    children: [
                      SwitchListTile(
                        title: Text(t.videoSound),
                        subtitle: Text(t.videoSoundHint),
                        value: _frame.videoSound,
                        onChanged: _setVideoSound,
                      ),
                      SwitchListTile(
                        title: Text(t.albumSwitch),
                        subtitle: Text(t.albumSwitchHint),
                        value: _frame.channelSwitchEnabled,
                        onChanged: _setAlbumSwitch,
                      ),
                    ],
                  ),
                  SmileInfoSection(
                    title: t.showsAlbums,
                    children: [
                      if (assignments.isEmpty) SmileSectionHint(icon: SmileIcons.album, text: t.noAlbumAssigned),
                      for (final assignment in assignments)
                        SmileObjectTile(
                          leading: albumCover(assignment.channelId, assignment.channelName, _covers, size: 40),
                          title: albumNameOf(assignment.channelId, assignment.channelName),
                          subtitle: assignment.channelId == _shownChannelId ? t.showingNow : null,
                          subtitleIcon: SmileIcons.play,
                          subtitleHighlight: true,
                          // Three dots instead of a direct X (decided 2026-10-08):
                          // removing is behind a menu + confirmation, like
                          // people and shares on the album page.
                          // A plain icon, not an IconButton: the whole row opens
                          // the menu, and IconButton's padding pushed the dots
                          // away from the right edge.
                          trailing: Icon(SmileIcons.more, color: scheme.onSurfaceVariant),
                          onTap: () => _showAlbumActions(assignment),
                        ),
                      SmileActionRow(icon: SmileIcons.add, label: t.addAlbumToFrame, onTap: _addAlbum),
                    ],
                  ),
                  SmileInfoSection(
                    children: [
                      // A new tablet takes over this Frame (2026-10-11).
                      if (!_frame.isRevoked && _frame.pairingCode != null)
                        SmileActionRow(
                          icon: SmileIcons.inviteCode,
                          label: t.connectOtherDevice,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CreateFrameScreen(spaceId: widget.spaceId, existingFrame: _frame),
                            ),
                          ),
                        ),
                      SmileActionRow(
                        icon: _frame.isRevoked ? SmileIcons.restore : SmileIcons.close,
                        label: _frame.isRevoked ? t.reactivateFrame : t.revokeFrame,
                        destructive: !_frame.isRevoked,
                        onTap: _toggleRevoked,
                      ),
                      SmileActionRow(icon: SmileIcons.delete, label: t.deleteFrame, destructive: true, onTap: _delete),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _statusRow(String label, String value) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l, vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: muted))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
