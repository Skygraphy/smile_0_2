import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_service.dart';
import '../services/channel_picker_service.dart';
import '../widgets/album_covers.dart';
import '../services/avatar_upload.dart';
import '../services/object_picture_service.dart';
import '../widgets/picture_sheet.dart';
import '../services/sync_bus.dart';

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
    _load();
  }

  @override
  Future<void> onSync() async {
    if (await closeIfGone(context, table: 'frames', id: widget.frame.id)) return;
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
      if (!mounted) return;
      setState(() {
        _assignments ??= const [];
        _errorMessage = SmileTexts.of(context).frameInfoLoadError('$e');
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = SmileTexts.of(context).actionFailed('$e'));
    }
  }

  Future<void> _rename() async {
    final t = SmileTexts.of(context);
    final name = await showSmileNameDialog(context, title: t.renameFrame, confirmLabel: t.save, initialValue: _frame.name);
    if (name == null) return;
    await _run(() => widget.frameService.renameFrame(frameId: _frame.id, name: name));
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
      confirmLabel: t.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.frameService.deleteFrame(_frame.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
    }
  }

  /// Optimistic: the switch moves at once, a failure reloads the truth.
  Future<void> _setAlbumSwitch(bool value) async {
    setState(() => _frame = _frame.copyWith(channelSwitchEnabled: value));
    await _run(() => widget.frameService.setChannelSwitchEnabled(frameId: _frame.id, enabled: value));
  }

  Future<void> _setVideoSound(bool value) async {
    setState(() => _frame = _frame.copyWith(videoSound: value));
    await _run(() => widget.frameService.setVideoSound(frameId: _frame.id, enabled: value));
  }

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

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final assignments = _assignments;
    final scheme = Theme.of(context).colorScheme;
    final status = switch (_frame.lifecycleState) {
      'active' => t.frameActive,
      'revoked' => t.frameRevoked,
      _ => t.framePending,
    };
    final spaceName = widget.spaceName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: () => Navigator.of(context).maybePop()),
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
                          name: _frame.name,
                          hasCustomPicture: _frame.avatarPath != null,
                        );
                        if (changed) await _load();
                      },
                      child: SmileStatusDot(
                        online: _frame.isOnline,
                        child: SmileAlbumCover(name: _frame.name, imageUrl: avatarPathToUrl(_frame.avatarPath), size: 80),
                      ),
                    ),
                    title: _frame.name,
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
                          title: assignment.channelName,
                          trailing: IconButton(
                            icon: Icon(SmileIcons.close, color: scheme.onSurfaceVariant),
                            tooltip: t.removeFromFrame,
                            onPressed: () => _run(
                              () => widget.frameService.unassignChannel(frameId: _frame.id, channelId: assignment.channelId),
                            ),
                          ),
                        ),
                      SmileActionRow(icon: SmileIcons.add, label: t.addAlbumToFrame, onTap: _addAlbum),
                    ],
                  ),
                  SmileInfoSection(
                    children: [
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
