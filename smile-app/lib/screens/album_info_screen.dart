import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import '../services/channel_service.dart';
import '../services/membership_service.dart';
import '../services/sync_bus.dart';
import '../widgets/email_dialog.dart';

/// The album's info page, WhatsApp-group-info style (decision 5,
/// 2026-10-05): big icon + name (tap to rename), quick actions, then
/// Personen, Shared with, Läuft auf, and Leave/Delete last.
///
/// Behind it are the two symmetric invite mechanisms (see
/// migrations/0031_architecture_reset.sql): inviting a person grants
/// posting rights (channel_membership_requests); sharing with a Space
/// grants view-only access (channel_share_requests). Only the album's
/// managers -- its home Space's Admin and Co-Admins ("SCO" in code) --
/// may invite, remove, decide requests, rename or delete; RLS enforces
/// the same server-side on every write, the UI only hides what can't work.
class AlbumInfoScreen extends StatefulWidget {
  AlbumInfoScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    this.onRenamed,
    MembershipService? membershipService,
    ChannelService? channelService,
  })  : membershipService = membershipService ?? MembershipService(),
        channelService = channelService ?? ChannelService();

  final String channelId;
  final String channelName;
  final ValueChanged<String>? onRenamed;
  final MembershipService membershipService;
  final ChannelService channelService;

  @override
  State<AlbumInfoScreen> createState() => _AlbumInfoScreenState();
}

class _AlbumInfoScreenState extends State<AlbumInfoScreen> with SyncReload {
  ChannelRoster? _roster;
  MyInvitesInbox? _inbox;
  List<({String frameId, String frameName})> _frames = const [];
  late String _name = widget.channelName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() async {
    if (await closeIfGone(context, table: 'channels', id: widget.channelId)) return;
    await _load();
  }

  Future<void> _load() async {
    try {
      final roster = await widget.membershipService.listChannelMembers(widget.channelId);
      // Only a manager may list this album's requests (list-my-invites
      // rejects anyone else) -- skip the call instead of surfacing an
      // expected 403 as an error.
      final results = await Future.wait<dynamic>([
        if (roster.callerIsSco) widget.membershipService.listMyInvites(channelId: widget.channelId),
        widget.channelService.listFramesShowing(widget.channelId),
        supabase.from('channels').select('name').eq('id', widget.channelId).maybeSingle(),
      ]);
      if (!mounted) return;
      final row = results.last as Map<String, dynamic>?;
      setState(() {
        _roster = roster;
        _inbox = roster.callerIsSco ? results.first as MyInvitesInbox : null;
        _frames = results[results.length - 2] as List<({String frameId, String frameName})>;
        if (row != null) _name = row['name'] as String;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = SmileTexts.of(context).albumInfoLoadError('$e'));
    }
  }

  /// Runs [action], reloads, and shows a readable error instead of an
  /// unhandled exception if it fails.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ChannelRequestException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = SmileTexts.of(context).actionFailed('$e'));
    }
  }

  Future<void> _rename() async {
    final t = SmileTexts.of(context);
    final name = await showSmileNameDialog(context, title: t.renameAlbum, confirmLabel: t.save, initialValue: _name);
    if (name == null) return;
    await _run(() => widget.channelService.renameChannel(channelId: widget.channelId, name: name));
    if (!mounted) return;
    setState(() => _name = name);
    widget.onRenamed?.call(name);
  }

  Future<void> _inviteMember() async {
    final t = SmileTexts.of(context);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => EmailDialog(
        title: t.inviteToAlbum,
        explanation: t.inviteToAlbumHint,
        confirmLabel: t.actionInvite,
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    await _run(() => widget.membershipService.inviteMember(channelId: widget.channelId, email: email.trim()));
  }

  Future<void> _inviteShare() async {
    final t = SmileTexts.of(context);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => EmailDialog(
        title: t.shareWithSpace,
        explanation: t.shareWithSpaceHint,
        confirmLabel: t.actionInvite,
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    await _run(() => widget.membershipService.inviteShare(channelId: widget.channelId, email: email.trim()));
  }

  Future<void> _removeMember(ChannelMember member) async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.removePersonTitle(member.label),
      message: t.removePersonMessage,
      confirmLabel: t.actionRemove,
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() => widget.membershipService.removeMember(channelId: widget.channelId, userId: member.userId));
  }

  /// The album's own side ending a share (decision 2026-09-29) -- the
  /// viewing household is notified server-side (notify-event).
  Future<void> _endShare(SharedSpaceRef space) async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.endShareTitle(space.name),
      message: t.endShareMessage(space.name, _name),
      confirmLabel: t.endShare,
      destructive: true,
    );
    if (!confirmed) return;
    await _run(() => widget.membershipService.revokeShare(channelId: widget.channelId, spaceId: space.id));
  }

  Future<void> _leave() async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: '${t.leaveAlbum}?',
      message: t.leaveAlbumMessage,
      confirmLabel: t.actionLeave,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.membershipService.leaveChannel(widget.channelId);
      // The feed underneath is no longer accessible -- straight back home.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
    }
  }

  Future<void> _delete() async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.deleteAlbumTitle(_name),
      message: t.deleteAlbumMessage,
      confirmLabel: t.actionDelete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.channelService.deleteChannel(widget.channelId);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
    }
  }

  /// Tapping a removable person offers "Aus dem Album entfernen" in a
  /// bottom sheet, WhatsApp-style, instead of a permanent X on every row.
  Future<void> _showMemberActions(ChannelMember member) async {
    final t = SmileTexts.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: SmileAvatar(name: member.label, avatarUrl: member.avatarUrl, size: 36),
              title: Text(member.label),
            ),
            SmileActionRow(
              icon: SmileIcons.remove,
              label: t.removeFromAlbum,
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _removeMember(member);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShareActions(SharedSpaceRef space) async {
    final t = SmileTexts.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: SmileInitialsTile(name: space.name, size: 36), title: Text(space.name)),
            SmileActionRow(
              icon: SmileIcons.shared,
              label: t.endShare,
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                _endShare(space);
              },
            ),
          ],
        ),
      ),
    );
  }

  SmileRole _roleOf(ChannelMember member, ChannelRoster roster) {
    if (member.userId == roster.administratorUserId) return SmileRole.admin;
    if (roster.coAdminUserIds.contains(member.userId)) return SmileRole.coAdmin;
    return SmileRole.member;
  }

  Widget _decideButtons({required VoidCallback onAccept, required VoidCallback onDecline}) {
    final t = SmileTexts.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(SmileIcons.accept, color: Theme.of(context).colorScheme.primary),
          tooltip: t.actionAccept,
          onPressed: onAccept,
        ),
        IconButton(icon: const Icon(SmileIcons.close), tooltip: t.actionDecline, onPressed: onDecline),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final roster = _roster;
    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: roster == null
          ? Center(child: _errorMessage != null ? Text(_errorMessage!) : const CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildBody(context, t, roster, currentUserId)),
    );
  }

  Widget _buildBody(BuildContext context, SmileTexts t, ChannelRoster roster, String? currentUserId) {
    final isManager = roster.callerIsSco;
    final isMember = roster.members.any((m) => m.userId == currentUserId);
    final inbox = _inbox;
    bool isInvite(ChannelRequest r) => r.direction == RequestDirection.invite;
    final membershipRequestsToDecide = (inbox?.membershipRequests ?? []).where((r) => !isInvite(r)).toList();
    final pendingMembershipInvites = (inbox?.membershipRequests ?? []).where(isInvite).toList();
    final shareRequestsToDecide = (inbox?.shareRequests ?? []).where((r) => !isInvite(r)).toList();
    final pendingShareInvites = (inbox?.shareRequests ?? []).where(isInvite).toList();
    final homeSpace = roster.homeSpaceName;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      children: [
        SmileInfoHeader(
          icon: SmileIcons.album,
          title: _name,
          subtitleIcon: SmileIcons.space,
          subtitle: [
            if (homeSpace != null) t.albumInSpace(homeSpace),
            t.personCount(roster.members.length),
          ].join(' · '),
          onRename: isManager ? _rename : null,
          renameTooltip: t.renameAlbum,
        ),
        if (isManager)
          SmileQuickActions(actions: [
            SmileQuickAction(icon: SmileIcons.invite, label: t.actionInvite, onTap: _inviteMember),
            SmileQuickAction(icon: SmileIcons.share, label: t.actionShare, onTap: _inviteShare),
          ]),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),

        // --- Personen ---------------------------------------------------
        SmileInfoSection(
          title: t.personCount(roster.members.length),
          children: [
            for (final member in roster.members)
              Builder(builder: (context) {
                final isMe = member.userId == currentUserId;
                // Nobody but the Admin themselves may remove the Admin --
                // not even a Co-Admin (migrations/0045).
                final removable = isManager && !isMe && member.userId != roster.administratorUserId;
                return SmileObjectTile(
                  leading: SmileAvatar(name: member.label, avatarUrl: member.avatarUrl, size: 40),
                  title: isMe ? t.you : member.label,
                  trailing: SmileRoleBadge(role: _roleOf(member, roster)),
                  onTap: removable ? () => _showMemberActions(member) : null,
                );
              }),
            for (final request in membershipRequestsToDecide)
              SmileObjectTile(
                leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl, size: 40),
                title: request.counterpartLabel,
                subtitle: t.wantsToJoin,
                trailing: _decideButtons(
                  onAccept: () => _run(() => widget.membershipService.decideMembershipRequest(request.id, accept: true)),
                  onDecline: () =>
                      _run(() => widget.membershipService.decideMembershipRequest(request.id, accept: false)),
                ),
              ),
            for (final request in pendingMembershipInvites)
              SmileObjectTile(
                leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl, size: 40),
                title: request.counterpartLabel,
                subtitleIcon: SmileIcons.pending,
                subtitle: t.invitedWaiting,
                trailing: IconButton(
                  icon: Icon(SmileIcons.close, color: muted),
                  tooltip: t.actionWithdraw,
                  onPressed: () => _run(() => widget.membershipService.withdrawMembershipRequest(request.id)),
                ),
              ),
            if (isManager) SmileActionRow(icon: SmileIcons.invite, label: t.inviteToAlbum, onTap: _inviteMember),
          ],
        ),

        // --- Shared with ------------------------------------------------
        if (isManager || roster.sharedSpaces.isNotEmpty)
          SmileInfoSection(
            title: t.sharedWith,
            children: [
              if (roster.sharedSpaces.isEmpty && shareRequestsToDecide.isEmpty && pendingShareInvites.isEmpty)
                SmileSectionHint(icon: SmileIcons.shared, text: t.notSharedYet),
              for (final space in roster.sharedSpaces)
                SmileObjectTile(
                  leading: SmileInitialsTile(name: space.name, size: 40),
                  title: space.name,
                  subtitleIcon: SmileIcons.viewer,
                  subtitle: t.sharedViewOnly,
                  onTap: isManager ? () => _showShareActions(space) : null,
                ),
              for (final request in shareRequestsToDecide)
                SmileObjectTile(
                  leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl, size: 40),
                  title: request.counterpartLabel,
                  subtitle: t.wantsToShare,
                  trailing: _decideButtons(
                    onAccept: () => _run(() => widget.membershipService.decideShareRequest(request.id, accept: true)),
                    onDecline: () => _run(() => widget.membershipService.decideShareRequest(request.id, accept: false)),
                  ),
                ),
              for (final request in pendingShareInvites)
                SmileObjectTile(
                  leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl, size: 40),
                  title: request.counterpartLabel,
                  subtitleIcon: SmileIcons.pending,
                  subtitle: t.invitedWaiting,
                  trailing: IconButton(
                    icon: Icon(SmileIcons.close, color: muted),
                    tooltip: t.actionWithdraw,
                    onPressed: () => _run(() => widget.membershipService.withdrawShareRequest(request.id)),
                  ),
                ),
              if (isManager) SmileActionRow(icon: SmileIcons.share, label: t.shareWithSpace, onTap: _inviteShare),
            ],
          ),

        // --- Läuft auf --------------------------------------------------
        // Only Frames of Spaces the caller manages are visible (RLS), so a
        // plain member sees this section only if it has entries.
        if (isManager || _frames.isNotEmpty)
          SmileInfoSection(
            title: t.showsOn,
            children: [
              if (_frames.isEmpty) SmileSectionHint(icon: SmileIcons.frame, text: t.notOnAnyFrame),
              for (final frame in _frames)
                SmileObjectTile(
                  leading: SmileInitialsTile(name: frame.frameName, size: 40),
                  title: frame.frameName,
                ),
            ],
          ),

        // --- Leave / delete --------------------------------------------
        if (isMember || isManager)
          SmileInfoSection(
            children: [
              // Managers too (decision 2026-10-01): they become members of
              // every album automatically (migrations/0052), so they must be
              // able to leave one they don't want to post in.
              if (isMember) SmileActionRow(icon: SmileIcons.leave, label: t.leaveAlbum, destructive: true, onTap: _leave),
              if (isManager)
                SmileActionRow(icon: SmileIcons.delete, label: t.deleteAlbum, destructive: true, onTap: _delete),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
