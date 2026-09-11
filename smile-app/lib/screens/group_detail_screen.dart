import 'package:flutter/material.dart';

import '../services/group_service.dart';

/// Two independent sections for one group: who's in it, and which channels
/// it's granted access to. Both take effect immediately -- adding a member
/// grants them every already-granted channel, granting a channel admits
/// every current member -- via the reconcile trigger in
/// migrations/0020_groups.sql, not anything in this screen.
class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group, required this.groupService});

  final SmileGroup group;
  final GroupService groupService;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<GroupMember>? _members;
  List<GroupGrant>? _grants;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.groupService.listGroupMembers(widget.group.id),
        widget.groupService.listGrants(widget.group.id),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<GroupMember>;
        _grants = results[1] as List<GroupGrant>;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _members ??= const [];
        _grants ??= const [];
        _errorMessage = 'Gruppendetails konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _addMember() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => _EmailDialog(
        title: 'Person hinzufügen',
        label: 'E-Mail-Adresse',
        confirmLabel: 'Hinzufügen',
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await widget.groupService.addGroupMember(groupId: widget.group.id, email: email.trim());
      setState(() => _errorMessage = null);
      await _load();
    } on GroupServiceException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Hinzufügen fehlgeschlagen: $e');
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    await widget.groupService.removeGroupMember(member.id);
    await _load();
  }

  Future<void> _grantChannel() async {
    final channels = await widget.groupService.listGrantableChannels();
    final alreadyGrantedIds = _grants!.map((g) => g.channelId).toSet();
    final choices = channels.where((c) => !alreadyGrantedIds.contains(c.channelId)).toList();
    if (!mounted) return;
    if (choices.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Channel freigeben'),
          content: const Text('Es gibt keine weiteren Channels, die du administrierst.'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen'))],
        ),
      );
      return;
    }
    final picked = await showDialog<GrantableChannel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Channel freigeben'),
        children: [
          for (final channel in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(channel),
              child: Text('${channel.spaceName} → ${channel.channelName}'),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await widget.groupService.grantChannel(groupId: widget.group.id, channelId: picked.channelId);
    await _load();
  }

  Future<void> _revokeGrant(GroupGrant grant) async {
    await widget.groupService.revokeGrant(grant.grantId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    final grants = _grants;
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: members == null || grants == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                Text('Mitglieder', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (members.isEmpty) const Text('Noch niemand in dieser Gruppe.'),
                for (final member in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person),
                    title: Text(member.email ?? member.userId),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Entfernen',
                      onPressed: () => _removeMember(member),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Person hinzufügen'),
                ),
                const SizedBox(height: 28),
                Text('Freigegebene Channels', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (grants.isEmpty) const Text('Noch keinem Channel freigegeben.'),
                for (final grant in grants)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text('${grant.spaceName} → ${grant.channelName}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Widerrufen',
                      onPressed: () => _revokeGrant(grant),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _grantChannel,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Channel freigeben'),
                ),
              ],
            ),
    );
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.title, required this.label, required this.confirmLabel});

  final String title;
  final String label;
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
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(widget.confirmLabel)),
      ],
    );
  }
}
