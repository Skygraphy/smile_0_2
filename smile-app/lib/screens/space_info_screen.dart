import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import '../services/channel_service.dart';
import '../services/channel_picker_service.dart';
import '../services/frame_service.dart';
import '../services/membership_service.dart';
import '../services/space_service.dart';
import '../services/sync_bus.dart';
import '../widgets/email_dialog.dart';
import '../widgets/album_covers.dart';
import 'channel_feed_screen.dart';
import 'create_frame_screen.dart';
import 'frame_settings_screen.dart';
import 'trash_screen.dart';

/// A Space's info page, same pattern as the album's (decision 5,
/// 2026-10-05): icon + name (tap to rename), quick actions, then Alben,
/// albums shared into this Space, Frames, Admins, and Papierkorb /
/// Admin übergeben / Space löschen last. Replaces the old per-Space
/// overflow menu and its separate screens (channel list, frame list,
/// shares, "Verwaltung teilen").
///
/// Roles: the Admin is `spaces.owner_id` ("founder" in code), Co-Admins
/// are `space_co_owners`. Both manage everything; only the Admin invites
/// Co-Admins, hands the Admin role over and deletes the Space -- RLS and
/// the Edge Functions enforce the same, the UI only hides what can't work.
class SpaceInfoScreen extends StatefulWidget {
  SpaceInfoScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
    SpaceService? spaceService,
    ChannelService? channelService,
    FrameService? frameService,
    MembershipService? membershipService,
  })  : spaceService = spaceService ?? SpaceService(),
        channelService = channelService ?? ChannelService(),
        frameService = frameService ?? FrameService(),
        membershipService = membershipService ?? MembershipService();

  final String spaceId;
  final String spaceName;
  final SpaceService spaceService;
  final ChannelService channelService;
  final FrameService frameService;
  final MembershipService membershipService;

  @override
  State<SpaceInfoScreen> createState() => _SpaceInfoScreenState();
}

class _SpaceInfoScreenState extends State<SpaceInfoScreen> with SyncReload {
  late String _name = widget.spaceName;
  List<Map<String, dynamic>>? _albums;
  List<SharedChannelSummary> _sharedIn = const [];
  List<SmileFrame> _frames = const [];
  SpaceCoOwnership? _admins;
  Map<String, ChannelWithActivity> _covers = const {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() async {
    if (await closeIfGone(context, table: 'spaces', id: widget.spaceId)) return;
    await _load();
  }

  Future<void> _load() async {
    unawaited(loadAlbumCovers().then((c) {
      if (mounted) setState(() => _covers = c);
    }));
    try {
      final results = await Future.wait<dynamic>([
        supabase.from('spaces').select('name').eq('id', widget.spaceId).maybeSingle(),
        widget.channelService.listChannels(widget.spaceId),
        widget.membershipService.listSharedChannelsForSpace(widget.spaceId),
        widget.frameService.listFrames(widget.spaceId),
        widget.spaceService.listCoOwners(widget.spaceId),
      ]);
      if (!mounted) return;
      final row = results[0] as Map<String, dynamic>?;
      setState(() {
        if (row != null) _name = row['name'] as String;
        _albums = results[1] as List<Map<String, dynamic>>;
        _sharedIn = results[2] as List<SharedChannelSummary>;
        _frames = results[3] as List<SmileFrame>;
        _admins = results[4] as SpaceCoOwnership;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _albums ??= const [];
        _errorMessage = SmileTexts.of(context).spaceInfoLoadError('$e');
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on SpaceServiceException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = SmileTexts.of(context).actionFailed('$e'));
    }
  }

  Future<void> _rename() async {
    final t = SmileTexts.of(context);
    final name = await showSmileNameDialog(context, title: t.renameSpace, confirmLabel: t.save, initialValue: _name);
    if (name == null) return;
    await _run(() => widget.spaceService.renameSpace(spaceId: widget.spaceId, name: name));
  }

  Future<void> _createAlbum() async {
    final t = SmileTexts.of(context);
    final name = await showSmileNameDialog(context, title: t.createAlbum, confirmLabel: t.create, hint: t.createAlbumHint);
    if (name == null) return;
    await _run(() => widget.channelService.createChannel(spaceId: widget.spaceId, name: name));
  }

  Future<void> _connectFrame() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateFrameScreen(spaceId: widget.spaceId)));
    await _load();
  }

  Future<void> _inviteCoAdmin() async {
    final t = SmileTexts.of(context);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => EmailDialog(title: t.inviteCoAdmin, explanation: t.inviteCoAdminHint, confirmLabel: t.actionInvite),
    );
    if (email == null || email.trim().isEmpty) return;
    await _run(() => widget.spaceService.inviteCoOwner(spaceId: widget.spaceId, email: email.trim()));
  }

  Future<void> _makeAdmin(SpaceCoOwner coAdmin) async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.makeAdminTitle(coAdmin.label),
      message: t.makeAdminMessage,
      confirmLabel: t.makeAdmin,
    );
    if (!confirmed) return;
    await _run(() => widget.spaceService.transferOwnership(spaceId: widget.spaceId, newOwnerUserId: coAdmin.userId));
  }

  Future<void> _handOver() async {
    final t = SmileTexts.of(context);
    final coAdmins = _admins?.coOwners ?? const [];
    final picked = await showDialog<SpaceCoOwner>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t.chooseNewAdmin),
        children: [
          for (final coAdmin in coAdmins)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(coAdmin),
              child: Row(
                children: [
                  SmileAvatar(name: coAdmin.label, avatarUrl: coAdmin.avatarUrl, size: 32),
                  const SizedBox(width: SmileSpacing.m),
                  Expanded(child: Text(coAdmin.label)),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await _makeAdmin(picked);
  }

  Future<void> _removeCoAdmin(SpaceCoOwner coAdmin) async {
    final t = SmileTexts.of(context);
    final isSelf = coAdmin.userId == supabase.auth.currentUser?.id;
    final confirmed = await showSmileConfirmDialog(
      context,
      title: isSelf ? '${t.stepDown}?' : t.removeCoAdminTitle(coAdmin.label),
      message: isSelf ? t.stepDownMessage : t.removeCoAdminMessage,
      confirmLabel: isSelf ? t.actionLeave : t.actionRemove,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.spaceService.removeCoOwner(spaceId: widget.spaceId, userId: coAdmin.userId);
      // Stepping down means this Space is no longer visible to the caller
      // (spaces_select) -- leave instead of reloading into an error.
      if (isSelf) {
        if (mounted) Navigator.of(context).pop();
      } else {
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
    }
  }

  Future<void> _stopShowing(SharedChannelSummary album) async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.stopShowingTitle(album.channelName),
      message: t.stopShowingMessage,
      confirmLabel: t.stopShowing,
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() => widget.membershipService.revokeShare(channelId: album.channelId, spaceId: widget.spaceId));
  }

  Future<void> _delete() async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.deleteSpaceTitle(_name),
      message: t.deleteSpaceMessage,
      confirmLabel: t.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.spaceService.deleteSpace(widget.spaceId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger.showSnackBar(SnackBar(content: Text(t.inTrash(_name))));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
    }
  }

  Future<void> _sheet({required Widget header, required List<SmileActionRow> actions}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            for (final action in actions)
              SmileActionRow(
                icon: action.icon,
                label: action.label,
                destructive: action.destructive,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  action.onTap();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _frameStatus(SmileTexts t, SmileFrame frame) => switch (frame.lifecycleState) {
        'active' => t.frameActive,
        'revoked' => t.frameRevoked,
        _ => t.framePending,
      };

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final albums = _albums;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: albums == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildBody(context, t, albums)),
    );
  }

  Widget _buildBody(BuildContext context, SmileTexts t, List<Map<String, dynamic>> albums) {
    final admins = _admins;
    final currentUserId = supabase.auth.currentUser?.id;
    final isAdmin = admins?.callerIsFounder ?? false;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      children: [
        SmileInfoHeader(
          icon: SmileIcons.space,
          leading: SmileInitialsTile(name: _name, size: 80),
          title: _name,
          subtitleIcon: isAdmin ? SmileIcons.admin : SmileIcons.coAdmin,
          subtitle: admins == null ? null : (isAdmin ? t.youAreAdmin : t.youAreCoAdmin),
          onRename: _rename,
          renameTooltip: t.renameSpace,
        ),
        SmileQuickActions(actions: [
          SmileQuickAction(icon: SmileIcons.add, label: t.album, onTap: _createAlbum),
          SmileQuickAction(icon: SmileIcons.frame, label: t.frame, onTap: _connectFrame),
          if (isAdmin) SmileQuickAction(icon: SmileIcons.coAdmin, label: t.roleCoAdmin, onTap: _inviteCoAdmin),
        ]),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),

        // --- Alben ------------------------------------------------------
        SmileInfoSection(
          title: t.albumCount(albums.length),
          children: [
            if (albums.isEmpty) SmileSectionHint(icon: SmileIcons.album, text: t.noAlbumYet),
            for (final album in albums)
              SmileObjectTile(
                leading: albumCover(album['id'] as String, album['name'] as String, _covers, size: 40),
                title: album['name'] as String,
                trailing: Icon(SmileIcons.chevron, size: 16, color: muted),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChannelFeedScreen(
                        channelId: album['id'] as String,
                        channelName: album['name'] as String,
                      ),
                    ),
                  );
                  await _load();
                },
              ),
            SmileActionRow(icon: SmileIcons.add, label: t.createAlbum, onTap: _createAlbum),
          ],
        ),

        // --- Albums of other Spaces shared into this one (view only) -----
        if (_sharedIn.isNotEmpty)
          SmileInfoSection(
            title: t.sharedIntoSpace,
            children: [
              for (final album in _sharedIn)
                SmileObjectTile(
                  leading: albumCover(album.channelId, album.channelName, _covers, size: 40),
                  title: album.channelName,
                  subtitleIcon: SmileIcons.viewer,
                  subtitle: t.roleViewer,
                  onTap: () => _sheet(
                    header: ListTile(
                      leading: albumCover(album.channelId, album.channelName, _covers, size: 36),
                      title: Text(album.channelName),
                    ),
                    actions: [
                      SmileActionRow(
                        icon: SmileIcons.hide,
                        label: t.stopShowing,
                        destructive: true,
                        onTap: () => _stopShowing(album),
                      ),
                    ],
                  ),
                ),
            ],
          ),

        // --- Frames -----------------------------------------------------
        SmileInfoSection(
          title: t.frameCount(_frames.length),
          children: [
            if (_frames.isEmpty) SmileSectionHint(icon: SmileIcons.frame, text: t.noFrameYet),
            for (final frame in _frames)
              SmileObjectTile(
                leading: SmileStatusDot(online: frame.isOnline, child: SmileInitialsTile(name: frame.name, size: 40)),
                title: frame.name,
                subtitle: _frameStatus(t, frame),
                trailing: Icon(SmileIcons.chevron, size: 16, color: muted),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FrameSettingsScreen(
                        frame: frame,
                        spaceId: widget.spaceId,
                        spaceName: _name,
                        frameService: widget.frameService,
                      ),
                    ),
                  );
                  await _load();
                },
              ),
            SmileActionRow(icon: SmileIcons.add, label: t.connectFrame, onTap: _connectFrame),
          ],
        ),

        // --- Admins -----------------------------------------------------
        if (admins != null)
          SmileInfoSection(
            title: t.admins,
            children: [
              SmileObjectTile(
                leading: SmileAvatar(name: admins.founderLabel, avatarUrl: admins.founderAvatarUrl, size: 40),
                title: admins.founderUserId == currentUserId ? t.you : admins.founderLabel,
                trailing: const SmileRoleBadge(role: SmileRole.admin),
              ),
              for (final coAdmin in admins.coOwners)
                Builder(builder: (context) {
                  final isSelf = coAdmin.userId == currentUserId;
                  final actions = [
                    if (isAdmin)
                      SmileActionRow(icon: SmileIcons.handOver, label: t.makeAdmin, onTap: () => _makeAdmin(coAdmin)),
                    if (isAdmin || isSelf)
                      SmileActionRow(
                        icon: isSelf ? SmileIcons.leave : SmileIcons.remove,
                        label: isSelf ? t.stepDown : t.removeCoAdmin,
                        destructive: true,
                        onTap: () => _removeCoAdmin(coAdmin),
                      ),
                  ];
                  return SmileObjectTile(
                    leading: SmileAvatar(name: coAdmin.label, avatarUrl: coAdmin.avatarUrl, size: 40),
                    title: isSelf ? t.you : coAdmin.label,
                    trailing: const SmileRoleBadge(role: SmileRole.coAdmin),
                    onTap: actions.isEmpty
                        ? null
                        : () => _sheet(
                              header: ListTile(
                                leading: SmileAvatar(name: coAdmin.label, avatarUrl: coAdmin.avatarUrl, size: 36),
                                title: Text(coAdmin.label),
                              ),
                              actions: actions,
                            ),
                  );
                }),
              for (final invite in admins.pendingInvites)
                SmileObjectTile(
                  leading: SmileAvatar(name: invite.label, avatarUrl: invite.avatarUrl, size: 40),
                  title: invite.label,
                  subtitleIcon: SmileIcons.pending,
                  subtitle: t.invitedWaiting,
                  trailing: IconButton(
                    icon: Icon(SmileIcons.close, color: muted),
                    tooltip: t.actionWithdraw,
                    onPressed: () => _run(() => widget.spaceService.withdrawCoOwnerInvite(invite.id)),
                  ),
                ),
              if (isAdmin) SmileActionRow(icon: SmileIcons.invite, label: t.inviteCoAdmin, onTap: _inviteCoAdmin),
            ],
          ),

        // --- Papierkorb / hand over / delete -----------------------------
        SmileInfoSection(
          children: [
            SmileActionRow(
              icon: SmileIcons.trash,
              label: t.trashTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrashScreen())),
            ),
            if (isAdmin && (admins?.coOwners.isNotEmpty ?? false))
              SmileActionRow(icon: SmileIcons.handOver, label: t.actionHandOver, onTap: _handOver),
            if (isAdmin) SmileActionRow(icon: SmileIcons.delete, label: t.deleteSpace, destructive: true, onTap: _delete),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
