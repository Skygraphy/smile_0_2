import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../main.dart';
import '../services/membership_service.dart';
import '../widgets/smile_avatar.dart';

/// Channel roster + role management + code-based invites (Phase 6a). Any
/// member can see the roster and generate an invite code; role changes,
/// removal, revoking a code, and adding an existing Space member are
/// restricted to a channel admin/Space Owner/staff (mirrored server-side by
/// list-channel-members/list-space-members and by RLS on the underlying
/// writes -- the `caller_is_admin`/`caller_is_space_owner` flags here only
/// control what's *shown*, not what's allowed).
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
  List<JoinRequest> _joinRequests = [];
  String? _errorMessage;

  static const _roleLabels = {
    'channel_admin': 'Admin',
    'contributor': 'Mitwirkend',
    'viewer': 'Nur ansehen',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final roster = await widget.membershipService.listChannelMembers(widget.channelId);
      // Only an admin/space-owner/staff may list requests (list-channel-
      // join-requests rejects anyone else) -- skip the call entirely for a
      // plain member instead of surfacing an expected 403 as an error.
      final joinRequests = roster.callerIsAdmin
          ? await widget.membershipService.listJoinRequests(widget.channelId)
          : <JoinRequest>[];
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _joinRequests = joinRequests;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Mitglieder konnten nicht geladen werden: $e');
    }
  }

  Future<void> _decideJoinRequest(JoinRequest request, {required bool approve}) async {
    try {
      await widget.membershipService.decideJoinRequest(request.id, approve: approve);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Anfrage konnte nicht ${approve ? "genehmigt" : "abgelehnt"} werden: $e');
    }
  }

  Future<void> _changeRole(ChannelMember member, String role) async {
    await widget.membershipService.updateMemberRole(member.membershipId, role);
    await _load();
  }

  Future<void> _leaveChannel(ChannelMember ownRow) async {
    if (ownRow.isGroupDerived) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Channel verlassen'),
          content: Text(
            'Dein Zugriff kommt über die Gruppe „${ownRow.viaGroupName}". Verlasse diese Gruppe unter "Meine Gruppen", um den Zugriff auf diesen Channel zu verlieren.',
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Verstanden'))],
        ),
      );
      return;
    }
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
    await widget.membershipService.leaveChannel(ownRow.membershipId);
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
    await widget.membershipService.removeMember(member.membershipId);
    await _load();
  }

  Future<void> _showInviteDialog() async {
    final roster = _roster;
    if (roster == null) return;
    ChannelInvite? invite;
    String? error;
    bool requiresApproval = false;
    bool isCreating = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> generate() async {
            setDialogState(() => isCreating = true);
            try {
              final created = await widget.membershipService.createChannelInvite(
                channelId: widget.channelId,
                requiresApproval: requiresApproval,
              );
              setDialogState(() => invite = created);
            } catch (e) {
              setDialogState(() => error = 'Code konnte nicht erstellt werden: $e');
            }
          }

          return AlertDialog(
            title: const Text('Einladungscode'),
            content: SizedBox(
              width: 280,
              child: invite != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          requiresApproval
                              ? 'Zeige diesen Code der Person -- ein Admin muss den Beitritt danach noch bestätigen.'
                              : 'Zeige diesen Code der Person, die dem Channel beitreten soll.',
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.white,
                          child: QrImageView(data: invite!.code, size: 200),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          invite!.code,
                          style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Gültig bis ${invite!.expiresAt.toLocal()}'.split('.').first),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: requiresApproval,
                          title: const Text('Beitritt muss genehmigt werden'),
                          onChanged: isCreating ? null : (value) => setDialogState(() => requiresApproval = value ?? false),
                        ),
                        const SizedBox(height: 8),
                        if (error != null) ...[
                          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 8),
                        ],
                        ElevatedButton(
                          onPressed: isCreating ? null : generate,
                          child: isCreating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Code erzeugen'),
                        ),
                      ],
                    ),
            ),
            actions: [
              if (invite != null && (roster.callerIsAdmin))
                TextButton(
                  onPressed: () async {
                    await widget.membershipService.revokeInvite(invite!.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Widerrufen'),
                ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen')),
            ],
          );
        },
      ),
    );
  }

  /// "Mit anderem Space teilen" (0030_multi_space_channels.sql): generates a
  /// channel_space_share code -- the owner of a *different* Space redeems
  /// it (via a "Code einlösen" action on spaces_screen.dart) to link their
  /// own Space to this channel, so both households see and can post into
  /// the same channel from then on.
  Future<void> _showShareWithSpaceDialog() async {
    ChannelInvite? invite;
    String? error;
    bool isCreating = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> generate() async {
            setDialogState(() => isCreating = true);
            try {
              final created = await widget.membershipService.createChannelSpaceShare(channelId: widget.channelId);
              setDialogState(() => invite = created);
            } catch (e) {
              setDialogState(() => error = 'Code konnte nicht erstellt werden: $e');
            }
          }

          return AlertDialog(
            title: const Text('Mit anderem Space teilen'),
            content: SizedBox(
              width: 280,
              child: invite != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Zeige diesen Code dem Owner des anderen Space -- er/sie löst ihn unter "Meine Spaces" ein.',
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.white,
                          child: QrImageView(data: invite!.code, size: 200),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          invite!.code,
                          style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Gültig bis ${invite!.expiresAt.toLocal()}'.split('.').first),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Ab dann sehen und teilen beide Spaces diesen Channel gemeinsam.'),
                        const SizedBox(height: 8),
                        if (error != null) ...[
                          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: isCreating ? null : generate,
                          child: isCreating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Code erzeugen'),
                        ),
                      ],
                    ),
            ),
            actions: [
              if (invite != null)
                TextButton(
                  onPressed: () async {
                    await widget.membershipService.revokeInvite(invite!.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Widerrufen'),
                ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddExistingMemberDialog() async {
    final roster = _roster;
    if (roster == null) return;
    List<SpaceMemberCandidate>? candidates;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (candidates == null && error == null) {
            // A channel can be linked to more than one Space now -- merge
            // candidates from every linked Space the caller can query
            // (list-space-members itself still gates each call to
            // Space-Owner-or-staff of that specific Space).
            Future.wait(
              roster.spaces.map(
                (space) => widget.membershipService
                    .listAddableSpaceMembers(spaceId: space.id, excludeChannelId: widget.channelId)
                    .catchError((_) => <SpaceMemberCandidate>[]),
              ),
            ).then((results) {
              final byUserId = <String, SpaceMemberCandidate>{};
              for (final list in results) {
                for (final c in list) {
                  byUserId[c.userId] = c;
                }
              }
              setDialogState(() => candidates = byUserId.values.toList());
            }).catchError((e) => setDialogState(() => error = 'Liste konnte nicht geladen werden: $e'));
          }
          if (error != null) {
            return AlertDialog(content: Text(error!), actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen')),
            ]);
          }
          if (candidates == null) {
            return const AlertDialog(content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())));
          }
          if (candidates!.isEmpty) {
            return AlertDialog(
              title: const Text('Bestehendes Mitglied hinzufügen'),
              content: const Text('Niemand aus anderen Channels dieses Space kann hinzugefügt werden.'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen'))],
            );
          }
          return AlertDialog(
            title: const Text('Bestehendes Mitglied hinzufügen'),
            content: SizedBox(
              width: 300,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final candidate in candidates!)
                    ListTile(
                      leading: SmileAvatar(name: candidate.label, avatarUrl: candidate.avatarUrl),
                      title: Text(candidate.label),
                      onTap: () async {
                        await widget.membershipService.addExistingMember(
                          channelId: widget.channelId,
                          userId: candidate.userId,
                          role: 'contributor',
                        );
                        if (context.mounted) Navigator.of(context).pop();
                        await _load();
                      },
                    ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen'))],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final currentUserId = supabase.auth.currentUser?.id;
    final ownRow = roster?.members.where((m) => m.userId == currentUserId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text('Mitglieder · ${widget.channelName}'),
        actions: [
          if (ownRow != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Channel verlassen',
              onPressed: () => _leaveChannel(ownRow),
            ),
        ],
      ),
      body: roster == null
          ? Center(child: _errorMessage != null ? Text(_errorMessage!) : const CircularProgressIndicator())
          : ListView(
              children: [
                for (final member in roster.members)
                  ListTile(
                    leading: SmileAvatar(name: member.label, avatarUrl: member.avatarUrl),
                    title: Text(member.label),
                    subtitle: Text(
                      member.isGroupDerived
                          ? '${_roleLabels[member.role] ?? member.role} · über Gruppe „${member.viaGroupName}"'
                          : _roleLabels[member.role] ?? member.role,
                    ),
                    trailing: roster.callerIsAdmin
                        ? PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'remove') {
                                _removeMember(member);
                              } else {
                                _changeRole(member, value);
                              }
                            },
                            itemBuilder: (context) => [
                              for (final entry in _roleLabels.entries)
                                CheckedPopupMenuItem(
                                  value: entry.key,
                                  checked: member.role == entry.key,
                                  child: Text(entry.value),
                                ),
                              // A group-derived row is owned by the reconcile
                              // trigger (migrations/0020_groups.sql) -- a
                              // direct delete here would just silently
                              // reappear the next time anything about that
                              // group changes. Removal has to happen at the
                              // source: leave the group, or revoke its grant.
                              if (!member.isGroupDerived) ...[
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'remove', child: Text('Entfernen')),
                              ],
                            ],
                          )
                        : (member.userId == currentUserId ? const Text('Du') : null),
                  ),
                if (roster.callerIsAdmin && _joinRequests.isNotEmpty) ...[
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Beitrittsanfragen', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final request in _joinRequests)
                    ListTile(
                      leading: SmileAvatar(name: request.label, avatarUrl: request.avatarUrl),
                      title: Text(request.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Genehmigen',
                            onPressed: () => _decideJoinRequest(request, approve: true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Ablehnen',
                            onPressed: () => _decideJoinRequest(request, approve: false),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showInviteDialog,
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Einladungscode zeigen'),
                      ),
                      if (roster.callerIsSpaceOwner) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _showAddExistingMemberDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Bestehendes Mitglied hinzufügen'),
                        ),
                      ],
                      if (roster.callerIsAdmin || roster.callerIsSpaceOwner) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _showShareWithSpaceDialog,
                          icon: const Icon(Icons.hub_outlined),
                          label: const Text('Mit anderem Space teilen'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
