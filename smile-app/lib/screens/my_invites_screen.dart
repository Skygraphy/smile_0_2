import 'package:flutter/material.dart';

import '../main.dart';
import '../services/membership_service.dart';
import '../widgets/smile_avatar.dart';

/// "Meine Einladungen": the caller's personal inbox for both connection
/// mechanisms (see migrations/0031_architecture_reset.sql) -- invites
/// addressed to them to accept/decline (channel membership = posting
/// rights, channel share = view-only for one of their own Spaces), and the
/// status of any request they made themselves. Replaces the pre-reset
/// join_channel_screen.dart's code-redemption flow entirely -- there is no
/// more shareable code, only a known person inviting another known person.
class MyInvitesScreen extends StatefulWidget {
  MyInvitesScreen({super.key, MembershipService? membershipService})
      : membershipService = membershipService ?? MembershipService();

  final MembershipService membershipService;

  @override
  State<MyInvitesScreen> createState() => _MyInvitesScreenState();
}

class _MyInvitesScreenState extends State<MyInvitesScreen> {
  MyInvitesInbox? _inbox;
  List<Map<String, dynamic>>? _mySpaces;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.membershipService.listMyInvites(),
        supabase.from('spaces').select('id, name').order('created_at'),
      ]);
      if (!mounted) return;
      setState(() {
        _inbox = results[0] as MyInvitesInbox;
        _mySpaces = List<Map<String, dynamic>>.from(results[1] as List);
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Einladungen konnten nicht geladen werden: $e');
    }
  }

  Future<void> _decideMembership(ChannelRequest request, {required bool accept}) async {
    try {
      await widget.membershipService.decideMembershipRequest(request.id, accept: accept);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $e')));
    }
  }

  Future<void> _declineShare(ChannelRequest request) async {
    try {
      await widget.membershipService.decideShareRequest(request.id, accept: false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aktion fehlgeschlagen: $e')));
    }
  }

  Future<void> _acceptShare(ChannelRequest request) async {
    final spaces = _mySpaces ?? [];
    if (spaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Du brauchst zuerst einen eigenen Space, um eine Freigabe anzunehmen.')),
      );
      return;
    }
    String? spaceId = spaces.length == 1 ? spaces.first['id'] as String : null;
    if (spaceId == null && mounted) {
      spaceId = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Mit welchem Space verknüpfen?'),
          children: [
            for (final space in spaces)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(space['id'] as String),
                child: Text(space['name'] as String),
              ),
          ],
        ),
      );
    }
    if (spaceId == null) return;
    try {
      await widget.membershipService.decideShareRequest(request.id, accept: true, spaceId: spaceId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Annehmen fehlgeschlagen: $e')));
    }
  }

  Future<void> _withdraw(ChannelRequest request) async {
    try {
      if (request.kind == RequestKind.membership) {
        await widget.membershipService.withdrawMembershipRequest(request.id);
      } else {
        await widget.membershipService.withdrawShareRequest(request.id);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zurückziehen fehlgeschlagen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    final pendingToMe = [
      ...(inbox?.membershipRequests ?? []).where((r) => r.direction == RequestDirection.invite),
      ...(inbox?.shareRequests ?? []).where((r) => r.direction == RequestDirection.invite),
    ];
    final mySentRequests = [
      ...(inbox?.membershipRequests ?? []).where((r) => r.direction == RequestDirection.request),
      ...(inbox?.shareRequests ?? []).where((r) => r.direction == RequestDirection.request),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Meine Einladungen')),
      body: inbox == null
          ? Center(child: _errorMessage != null ? Text(_errorMessage!) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                  ],
                  if (pendingToMe.isEmpty && mySentRequests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Keine offenen Einladungen oder Anfragen.'),
                    ),
                  for (final request in pendingToMe)
                    Card(
                      child: ListTile(
                        leading: SmileAvatar(name: request.counterpartLabel, avatarUrl: request.counterpartAvatarUrl),
                        title: Text(request.channelName ?? request.channelId),
                        subtitle: Text(
                          request.kind == RequestKind.membership
                              ? '${request.counterpartLabel} lädt dich zum Mitmachen ein'
                              : '${request.counterpartLabel} bietet an, diesen Channel mit deinem Space zu teilen',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Annehmen',
                              onPressed: () => request.kind == RequestKind.membership
                                  ? _decideMembership(request, accept: true)
                                  : _acceptShare(request),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Ablehnen',
                              onPressed: () => request.kind == RequestKind.membership
                                  ? _decideMembership(request, accept: false)
                                  : _declineShare(request),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (mySentRequests.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Eigene Anfragen', style: Theme.of(context).textTheme.titleMedium),
                    for (final request in mySentRequests)
                      Card(
                        child: ListTile(
                          title: Text(request.channelName ?? request.channelId),
                          subtitle: const Text('Wartet auf Bestätigung'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Zurückziehen',
                            onPressed: () => _withdraw(request),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
