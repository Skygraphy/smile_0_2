import 'package:flutter/material.dart';

import '../main.dart';
import '../services/push_service.dart';
import 'channel_list_screen.dart';
import 'device_list_screen.dart';
import 'groups_screen.dart';
import 'join_channel_screen.dart';
import 'pair_frame_screen.dart';

/// Landing screen after login. Full Space/Channel management (creation
/// flow, channel setup, member invites, device fleet) is Phase 6 scope --
/// this is deliberately minimal: list Spaces the user owns, let them
/// create one if they have none, and pair a Frame to one (Phase 2's own
/// scope, concept doc sect. 14).
class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  final _pushService = PushService();
  List<Map<String, dynamic>>? _spaces;
  String? _errorMessage;
  bool _isCreating = false;

  /// Deregisters this device's push token *before* signing out -- once
  /// signed out there's no session left for user_push_tokens' RLS
  /// (`user_id = auth.uid()`) to authorize the delete under, and without
  /// this a shared/reused device would keep getting the previous account's
  /// notifications (join requests, new photos, ...) until FCM eventually
  /// reports the token dead on its own.
  Future<void> _signOut() async {
    final token = await _pushService.getToken();
    if (token != null) {
      try {
        await supabase.from('user_push_tokens').delete().eq('fcm_token', token);
      } catch (_) {
        // Best-effort -- signing out must not get stuck on this.
      }
    }
    await supabase.auth.signOut();
  }

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    try {
      final rows = await supabase.from('spaces').select('id, name').order('created_at');
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

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.diversity_3),
            tooltip: 'Meine Gruppen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GroupsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _spaces == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Angemeldet als $email', style: Theme.of(context).textTheme.bodySmall),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings_display),
                            tooltip: 'Geräte',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DeviceListScreen(
                                  spaceId: space['id'] as String,
                                  spaceName: space['name'] as String,
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add_to_home_screen),
                            label: const Text('Frame koppeln'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PairFrameScreen(spaceId: space['id'] as String),
                              ),
                            ),
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
                      MaterialPageRoute(builder: (_) => JoinChannelScreen()),
                    );
                    await _loadSpaces();
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text('Einladung einlösen'),
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
