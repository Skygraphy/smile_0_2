import 'package:flutter/material.dart';

import '../main.dart';
import '../services/membership_service.dart';
import '../widgets/smile_avatar.dart';

/// Channel roster + the two symmetric invite mechanisms (see
/// migrations/0031_architecture_reset.sql): "Person einladen" grants
/// posting rights (channel_membership_requests); "Space einladen" grants
/// another Space view-only access (channel_share_requests). Only the
/// channel's SCO (its home Space's owner) can invite, remove a member, or
/// decide a pending *request* -- mirrored server-side by RLS on every
/// underlying write, not just enforced by hiding buttons here.
class ChannelMembersScreen extends StatefulWidget {
  ChannelMembersScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    MembershipService? membershipService,
  }) : membershipService = membershipService ?? MembershipService();

  final String channelId;
  final String channelName;
  final MembershipService membershipService;

  @override
  State<ChannelMembersScreen> createState() => _ChannelMembersScreenState();
}

class _ChannelMembersScreenState extends State<ChannelMembersScreen> {
  ChannelRoster? _roster;
  MyInvitesInbox? _inbox;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final roster = await widget.membershipService.listChannelMembers(widget.channelId);
      // Only the SCO may list requests for this channel (list-my-invites
      // rejects anyone else) -- skip the call entirely for a plain member
      // instead of surfacing an expected 403 as an error.
      final inbox = roster.callerIsSco
          ? await widget.membershipService.listMyInvites(channelId: widget.channelId)
          : null;
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _inbox = inbox;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Mitglieder konnten nicht geladen werden: $e');
    }
  }

  Future<void> _leaveChannel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Channel verlassen?'),
        content: const Text('Du verlierst den Zugriff auf alle Fotos in diesem Channel.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Verlassen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.membershipService.leaveChannel(widget.channelId);
    // The channel feed underneath is no longer accessible -- go straight
    // back to the Space list instead of leaving a stale feed screen on the
    // stack that would just show a permission error on its next reload.
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _removeMember(ChannelMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member.label} entfernen?'),
        content: const Text('Die Person verliert den Zugriff auf diesen Channel.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Entfernen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.membershipService.removeMember(channelId: widget.channelId, userId: member.userId);
    await _load();
  }

  Future<void> _showInviteMemberDialog() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => const _EmailDialog(
        title: 'Person einladen',
        explanation: 'Die Person braucht bereits einen Smile-Account. Sie kann die Einladung annehmen oder ablehnen.',
        confirmLabel: 'Einladen',
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await widget.membershipService.inviteMember(channelId: widget.channelId, email: email.trim());
      await _load();
    } on ChannelRequestException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Einladen fehlgeschlagen: $e');
    }
  }

  Future<void> _showInviteShareDialog() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => const _EmailDialog(
        title: 'Space einladen',
        explanation:
            'Der/die Owner eines anderen Space kann diesen Channel danach mit seinem/ihrem Space nur ansehen (kein Posten).',
        confirmLabel: 'Einladen',
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await widget.membershipService.inviteShare(channelId: widget.channelId, email: email.trim());
      await _load();
    } on ChannelRequestException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Einladen fehlgeschlagen: $e');
    }
  }

  Future<void> _decideMembershipRequest(ChannelRequest request, {required bool accept}) async {
    try {
      await widget.membershipService.decideMembershipRequest(request.id, accept: accept);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Anfrage konnte nicht ${accept ? "genehmigt" : "abgelehnt"} werden: $e');
    }
  }

  Future<void> _decideShareRequest(ChannelRequest request, {required bool accept}) async {
    try {
      await widget.membershipService.decideShareRequest(request.id, accept: accept);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Anfrage konnte nicht ${accept ? "genehmigt" : "abgelehnt"} werden: $e');
    }
  }

  Future<void> _withdrawMembershipInvite(ChannelRequest request) async {
    await widget.membershipService.withdrawMembershipRequest(request.id);
    await _load();
  }

  Future<void> _withdrawShareInvite(ChannelRequest request) async {
    await widget.membershipService.withdrawShareRequest(request.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final currentUserId = supabase.auth.currentUser?.id;
    final isMember = roster?.members.any((m) => m.userId == currentUserId) ?? false;
    final inbox = _inbox;
    final membershipRequestsToDecide =
        (inbox?.membershipRequests ?? []).where((r) => r.direction == RequestDirection.request).toList();
    final pendingMembershipInvites =
        (inbox?.membershipRequests ?? []).where((r) => r.direction == RequestDirection.invite).toList();
    final shareRequestsToDecide =
        (inbox?.shareRequests ?? []).where((r) => r.direction == RequestDirection.request).toList();
    final pendingShareInvites =
        (inbox?.shareRequests ?? []).where((r) => r.direction == RequestDirection.invite).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mitglieder · ${widget.channelName}'),
        actions: [
          if (isMember && !(roster?.callerIsSco ?? false))
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Channel verlassen',
              onPressed: _leaveChannel,
            ),
        ],
      ),
      body: roster == null
          ? Center(child: _errorMessage != null ? Text(_errorMessage!) : const CircularProgressIndicator())
          : ListView(
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                for (final member in roster.members)
                  ListTile(
                    leading: SmileAvatar(name: member.label, avatarUrl: member.avatarUrl),
                    title: Text(member.label),
                    trailing: roster.callerIsSco && member.userId != currentUserId
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Entfernen',
                            onPressed: () => _removeMember(member),
                          )
                        : (member.userId == currentUserId ? const Text('Du') : null),
                  ),
                if (roster.callerIsSco && membershipRequestsToDecide.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Beitrittsanfragen'),
                  ),
                  for (final request in membershipRequestsToDecide)
                    ListTile(
                      leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl),
                      title: Text(request.counterpartLabel),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Genehmigen',
                            onPressed: () => _decideMembershipRequest(request, accept: true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Ablehnen',
                            onPressed: () => _decideMembershipRequest(request, accept: false),
                          ),
                        ],
                      ),
                    ),
                ],
                if (roster.callerIsSco && pendingMembershipInvites.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Ausstehende Einladungen'),
                  ),
                  for (final request in pendingMembershipInvites)
                    ListTile(
                      leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl),
                      title: Text(request.counterpartLabel),
                      subtitle: const Text('Wartet auf Annahme'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Zurückziehen',
                        onPressed: () => _withdrawMembershipInvite(request),
                      ),
                    ),
                ],
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Geteilt mit', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (roster.sharedSpaces.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('Noch mit keinem anderen Space geteilt.'),
                  ),
                for (final space in roster.sharedSpaces)
                  ListTile(
                    leading: const Icon(Icons.hub_outlined),
                    title: Text(space.name),
                    subtitle: const Text('Nur ansehen'),
                  ),
                if (roster.callerIsSco && shareRequestsToDecide.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Freigabe-Anfragen'),
                  ),
                  for (final request in shareRequestsToDecide)
                    ListTile(
                      leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl),
                      title: Text(request.counterpartLabel),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Genehmigen',
                            onPressed: () => _decideShareRequest(request, accept: true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Ablehnen',
                            onPressed: () => _decideShareRequest(request, accept: false),
                          ),
                        ],
                      ),
                    ),
                ],
                if (roster.callerIsSco && pendingShareInvites.isNotEmpty) ...[
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Ausstehende Freigabe-Einladungen'),
                  ),
                  for (final request in pendingShareInvites)
                    ListTile(
                      leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl),
                      title: Text(request.counterpartLabel),
                      subtitle: const Text('Wartet auf Annahme'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Zurückziehen',
                        onPressed: () => _withdrawShareInvite(request),
                      ),
                    ),
                ],
                if (roster.callerIsSco) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showInviteMemberDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Person einladen'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _showInviteShareDialog,
                          icon: const Icon(Icons.hub_outlined),
                          label: const Text('Space einladen'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.title, required this.explanation, required this.confirmLabel});

  final String title;
  final String explanation;
  final String confirmLabel;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.explanation, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(widget.confirmLabel)),
      ],
    );
  }
}
