import 'package:flutter/material.dart';

import '../services/group_service.dart';
import 'group_detail_screen.dart';

/// "Meine Gruppen" (Phase 6b): personal, creator-owned distribution lists
/// of people that can be granted contributor access to channels across any
/// number of Spaces the creator administers -- see group_service.dart and
/// migrations/0020_groups.sql. Reached from spaces_screen.dart, since a
/// group is not scoped to one Space.
class GroupsScreen extends StatefulWidget {
  GroupsScreen({super.key, GroupService? groupService}) : groupService = groupService ?? GroupService();

  final GroupService groupService;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<SmileGroup>? _groups;
  List<MyGroupMembership>? _memberships;
  String? _errorMessage;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.groupService.listMyGroups(),
        widget.groupService.listMyGroupMemberships(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<SmileGroup>;
        _memberships = results[1] as List<MyGroupMembership>;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groups ??= const [];
        _memberships ??= const [];
        _errorMessage = 'Gruppen konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _createGroup() async {
    final name = await showDialog<String>(context: context, builder: (context) => _CreateGroupDialog());
    if (name == null || name.trim().isEmpty) return;
    setState(() => _isCreating = true);
    try {
      await widget.groupService.createGroup(name.trim());
      await _load();
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _leaveGroup(MyGroupMembership membership) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${membership.groupName}" verlassen?'),
        content: const Text('Du verlierst dadurch den Zugriff auf alle Channels, die dir diese Gruppe freigegeben hat.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Verlassen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.groupService.leaveGroup(membership.groupId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final memberships = _memberships;
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Gruppen')),
      body: groups == null || memberships == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Noch keine Gruppe angelegt. Eine Gruppe fasst Personen zusammen, denen du in einem Rutsch Zugriff auf mehrere Channels geben kannst.',
                    ),
                  ),
                for (final group in groups)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.diversity_3),
                      title: Text(group.name),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(group: group, groupService: widget.groupService),
                          ),
                        );
                        await _load();
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('Gruppe erstellen'),
                ),
                if (memberships.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text('Mitglied in', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Gruppen, die dich (nicht von dir verwaltet) für Channels freigegeben haben.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (final membership in memberships)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.diversity_3_outlined),
                        title: Text(membership.groupName),
                        subtitle: Text(
                          [
                            if (membership.ownerEmail != null) 'von ${membership.ownerEmail}',
                            if (membership.channels.isEmpty)
                              'noch keinem Channel freigegeben'
                            else
                              'Zugriff auf: ${membership.channels.map((c) => '${c.spaceName} → ${c.channelName}').join(', ')}',
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: 'Verlassen',
                          onPressed: () => _leaveGroup(membership),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gruppe erstellen'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name (z.B. "Familie Schiener")'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Erstellen')),
      ],
    );
  }
}
