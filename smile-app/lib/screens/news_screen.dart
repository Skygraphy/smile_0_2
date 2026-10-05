import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import '../services/membership_service.dart';
import '../services/space_service.dart';
import '../services/sync_bus.dart';
import '../services/trash_service.dart';

/// "Neuigkeiten" (navigation decision A, 2026-10-05): everything waiting
/// for the caller in one place, opened from the top-bar icon --
///   - Einladungen: invites addressed to them (Co-Admin of a Space, Member
///     of an album, an album offered to one of their Spaces),
///   - Anfragen: as a manager, people asking to join or see their albums,
///   - Eigene Anfragen: requests they sent, still waiting,
///   - Papierkorb: deleted Spaces/albums, restorable for 30 days.
///
/// The connection model behind it is the symmetric invite/request/accept
/// of migrations/0031 -- there is no shareable code, only a known person
/// inviting another known person.
class NewsScreen extends StatefulWidget {
  NewsScreen({
    super.key,
    MembershipService? membershipService,
    SpaceService? spaceService,
    TrashService? trashService,
  })  : membershipService = membershipService ?? MembershipService(),
        spaceService = spaceService ?? SpaceService(),
        trashService = trashService ?? TrashService();

  final MembershipService membershipService;
  final SpaceService spaceService;
  final TrashService trashService;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SyncReload {
  MyInvitesInbox? _inbox;
  List<MyCoOwnerInvite> _coAdminInvites = const [];
  List<Map<String, dynamic>> _mySpaces = const [];
  List<TrashItem> _trash = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() => _load();

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.membershipService.listMyInvites(includeManaged: true),
        supabase.from('spaces').select('id, name').order('created_at'),
        widget.spaceService.listMyCoOwnerInvites(),
        widget.trashService.listTrash(),
      ]);
      if (!mounted) return;
      setState(() {
        _inbox = results[0] as MyInvitesInbox;
        _mySpaces = List<Map<String, dynamic>>.from(results[1] as List);
        _coAdminInvites = results[2] as List<MyCoOwnerInvite>;
        _trash = results[3] as List<TrashItem>;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = SmileTexts.of(context).newsLoadError('$e'));
    }
  }

  /// Runs [action], reloads, and confirms with [success] -- a row that just
  /// vanishes on success looks exactly like nothing happened.
  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final t = SmileTexts.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await _load();
      if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.actionFailed('$e'))));
    }
  }

  Future<void> _acceptShareInvite(ChannelRequest request) async {
    final t = SmileTexts.of(context);
    if (_mySpaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.needOwnSpace)));
      return;
    }
    var spaceId = _mySpaces.length == 1 ? _mySpaces.first['id'] as String : null;
    spaceId ??= await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t.chooseSpace),
        children: [
          for (final space in _mySpaces)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(space['id'] as String),
              child: Row(
                children: [
                  const SmileObjectIcon(icon: SmileIcons.space, size: 32),
                  const SizedBox(width: SmileSpacing.m),
                  Expanded(child: Text(space['name'] as String)),
                ],
              ),
            ),
        ],
      ),
    );
    if (spaceId == null) return;
    final chosen = spaceId;
    await _run(
      () => widget.membershipService.decideShareRequest(request.id, accept: true, spaceId: chosen),
      success: t.acceptedShare(request.channelName ?? ''),
    );
  }

  Widget _decide({required VoidCallback onAccept, required VoidCallback onDecline}) {
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

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final inbox = _inbox;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(t.news),
      ),
      body: inbox == null
          ? Center(child: _errorMessage != null ? Text(_errorMessage!) : const CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildBody(context, t, inbox)),
    );
  }

  Widget _buildBody(BuildContext context, SmileTexts t, MyInvitesInbox inbox) {
    bool isInvite(ChannelRequest r) => r.direction == RequestDirection.invite;
    final albumInvites = [...inbox.membershipRequests, ...inbox.shareRequests].where(isInvite).toList();
    final mySent = [...inbox.membershipRequests, ...inbox.shareRequests].where((r) => !isInvite(r)).toList();
    final managed = [...inbox.managedMembershipRequests, ...inbox.managedShareRequests];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final nothing = albumInvites.isEmpty && _coAdminInvites.isEmpty && managed.isEmpty && mySent.isEmpty && _trash.isEmpty;

    return ListView(
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (nothing)
          Padding(
            padding: const EdgeInsets.only(top: 140),
            child: SmileEmptyState(icon: SmileIcons.news, title: t.newsEmptyTitle, message: t.newsEmptyMessage),
          ),

        // --- Einladungen (to me) -----------------------------------------
        if (_coAdminInvites.isNotEmpty || albumInvites.isNotEmpty)
          SmileInfoSection(
            title: t.invitations,
            children: [
              for (final invite in _coAdminInvites)
                SmileObjectTile(
                  leading: SmileAvatar(name: invite.founderLabel, avatarUrl: invite.founderAvatarUrl, size: 40),
                  title: invite.spaceName ?? invite.spaceId,
                  subtitleIcon: SmileIcons.coAdmin,
                  subtitle: t.inviteCoAdminFrom(invite.founderLabel),
                  trailing: _decide(
                    onAccept: () => _run(
                      () => widget.spaceService.decideCoOwnerInvite(invite.id, accept: true),
                      success: t.acceptedCoAdmin(invite.spaceName ?? ''),
                    ),
                    onDecline: () => _run(() => widget.spaceService.decideCoOwnerInvite(invite.id, accept: false)),
                  ),
                ),
              for (final request in albumInvites)
                SmileObjectTile(
                  leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl, size: 40),
                  title: request.channelName ?? request.channelId,
                  subtitleIcon: request.kind == RequestKind.membership ? SmileIcons.member : SmileIcons.shared,
                  subtitle: request.kind == RequestKind.membership
                      ? t.inviteMemberFrom(request.counterpartLabel)
                      : t.inviteShareFrom(request.counterpartLabel),
                  trailing: _decide(
                    onAccept: () => request.kind == RequestKind.membership
                        ? _run(
                            () => widget.membershipService.decideMembershipRequest(request.id, accept: true),
                            success: t.acceptedAlbum(request.channelName ?? ''),
                          )
                        : _acceptShareInvite(request),
                    onDecline: () => _run(
                      () => request.kind == RequestKind.membership
                          ? widget.membershipService.decideMembershipRequest(request.id, accept: false)
                          : widget.membershipService.decideShareRequest(request.id, accept: false),
                    ),
                  ),
                ),
            ],
          ),

        // --- Anfragen (to albums I manage) --------------------------------
        if (managed.isNotEmpty)
          SmileInfoSection(
            title: t.requests,
            children: [
              for (final request in managed)
                SmileObjectTile(
                  leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl, size: 40),
                  title: request.channelName ?? request.channelId,
                  subtitleIcon: request.kind == RequestKind.membership ? SmileIcons.member : SmileIcons.viewer,
                  subtitle: request.kind == RequestKind.membership
                      ? t.requestMemberFrom(request.counterpartLabel)
                      : t.requestShareFrom(request.counterpartLabel),
                  trailing: _decide(
                    onAccept: () => _run(
                      () => request.kind == RequestKind.membership
                          ? widget.membershipService.decideMembershipRequest(request.id, accept: true)
                          : widget.membershipService.decideShareRequest(request.id, accept: true),
                      success: t.requestAccepted,
                    ),
                    onDecline: () => _run(
                      () => request.kind == RequestKind.membership
                          ? widget.membershipService.decideMembershipRequest(request.id, accept: false)
                          : widget.membershipService.decideShareRequest(request.id, accept: false),
                    ),
                  ),
                ),
            ],
          ),

        // --- Eigene Anfragen ----------------------------------------------
        if (mySent.isNotEmpty)
          SmileInfoSection(
            title: t.myRequests,
            children: [
              for (final request in mySent)
                SmileObjectTile(
                  leading: const SmileObjectIcon(icon: SmileIcons.album, size: 40),
                  title: request.channelName ?? request.channelId,
                  subtitleIcon: SmileIcons.pending,
                  subtitle: t.waitingForAnswer,
                  trailing: IconButton(
                    icon: Icon(SmileIcons.close, color: muted),
                    tooltip: t.actionWithdraw,
                    onPressed: () => _run(
                      () => request.kind == RequestKind.membership
                          ? widget.membershipService.withdrawMembershipRequest(request.id)
                          : widget.membershipService.withdrawShareRequest(request.id),
                    ),
                  ),
                ),
            ],
          ),

        // --- Papierkorb ---------------------------------------------------
        if (_trash.isNotEmpty)
          SmileInfoSection(
            title: t.trashTitle,
            children: [
              for (final item in _trash)
                SmileObjectTile(
                  leading: SmileObjectIcon(icon: item.isSpace ? SmileIcons.space : SmileIcons.album, size: 40),
                  title: item.name,
                  subtitle: [
                    if (item.spaceName != null) t.trashSpaceIn(item.spaceName!),
                    t.trashGoneOn(_date(item.purgeAfter)),
                  ].join(' · '),
                  subtitleMaxLines: 2,
                  trailing: IconButton(
                    icon: Icon(SmileIcons.restore, color: Theme.of(context).colorScheme.primary),
                    tooltip: t.actionRestore,
                    onPressed: () => _run(() => widget.trashService.restore(item), success: t.restored(item.name)),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
