import 'package:flutter/material.dart';

import '../main.dart';
import '../services/membership_service.dart';
import '../services/space_service.dart';
import '../services/sync_bus.dart';
import 'channel_list_screen.dart';
import 'create_frame_screen.dart';
import 'frame_list_screen.dart';
import 'my_invites_screen.dart';
import 'space_co_owners_screen.dart';
import 'space_shared_channels_screen.dart';

/// "Meine Spaces" -- Space/Frame administration (create a Space, create a
/// Frame, manage Frames, manage the shares this Space has received).
/// Demoted from the app's landing screen to a secondary area reachable
/// from channels_home_screen.dart's overflow menu once the home screen
/// became a flat, recency-sorted Channel list -- see
/// project_ui-redesign-concepts memory for the reasoning behind this.
class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> with SyncReload {
  List<Map<String, dynamic>>? _spaces;
  String? _errorMessage;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  @override
  Future<void> onSync() => _loadSpaces();

  Future<void> _loadSpaces() async {
    try {
      final rows = await supabase.from('spaces').select('id, name, owner_id').order('created_at');
      if (!mounted) return;
      setState(() {
        _spaces = List<Map<String, dynamic>>.from(rows);
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Without this, a network/permission failure here left _spaces stuck
      // at null forever -- a permanent loading spinner on the very first
      // screen after login, with no explanation.
      setState(() {
        _spaces ??= const [];
        _errorMessage = 'Spaces konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _createSpace() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreateSpaceDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _isCreating = true);
    try {
      await supabase.from('spaces').insert({'name': name.trim()});
      await _loadSpaces();
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteSpace(Map<String, dynamic> space) async {
    final name = space['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Space „$name“ löschen?'),
        content: const Text(
          'Alle Channels dieses Space mit allen Fotos, alle Frames und alle Freigaben werden für alle '
          'endgültig gelöscht. Das kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SpaceService().deleteSpace(space['id'] as String);
      await _loadSpaces();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Space „$name“ gelöscht.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Spaces'),
      ),
      body: _spaces == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 16),
                ],
                for (final space in _spaces!)
                  Card(
                    child: ListTile(
                      title: Text(space['name'] as String),
                      subtitle: const Text('Antippen für Channels'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChannelListScreen(
                            spaceId: space['id'] as String,
                            spaceName: space['name'] as String,
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton<VoidCallback>(
                        onSelected: (action) => action(),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FrameListScreen(
                                  spaceId: space['id'] as String,
                                  spaceName: space['name'] as String,
                                ),
                              ),
                            ),
                            child: const Text('Frames'),
                          ),
                          PopupMenuItem(
                            value: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => CreateFrameScreen(spaceId: space['id'] as String)),
                            ),
                            child: const Text('Frame erstellen'),
                          ),
                          PopupMenuItem(
                            value: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SpaceSharedChannelsScreen(
                                  spaceId: space['id'] as String,
                                  spaceName: space['name'] as String,
                                  membershipService: MembershipService(),
                                ),
                              ),
                            ),
                            child: const Text('Freigaben verwalten'),
                          ),
                          PopupMenuItem(
                            value: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SpaceCoOwnersScreen(
                                  spaceId: space['id'] as String,
                                  spaceName: space['name'] as String,
                                ),
                              ),
                            ),
                            child: const Text('Verwaltung teilen'),
                          ),
                          // Administrator only -- co-owners manage, but
                          // never end the Space (delete-space-or-channel).
                          if (space['owner_id'] == supabase.auth.currentUser?.id)
                            PopupMenuItem(
                              value: () => _deleteSpace(space),
                              child: Text('Space löschen', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createSpace,
                  icon: const Icon(Icons.add),
                  label: const Text('Space erstellen'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => MyInvitesScreen()),
                    );
                    await _loadSpaces();
                  },
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Meine Einladungen'),
                ),
              ],
            ),
    );
  }
}

class _CreateSpaceDialog extends StatefulWidget {
  @override
  State<_CreateSpaceDialog> createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends State<_CreateSpaceDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Space erstellen'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name (z.B. "Familie Müller")'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}
