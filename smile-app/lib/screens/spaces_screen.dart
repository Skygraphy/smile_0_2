import 'package:flutter/material.dart';

import '../main.dart';
import '../services/membership_service.dart';
import 'channel_list_screen.dart';
import 'device_list_screen.dart';
import 'join_channel_screen.dart';
import 'pair_frame_screen.dart';

/// "Meine Spaces" -- Space/Frame administration (create a Space, pair a
/// Frame, manage devices). Demoted from the app's landing screen to a
/// secondary area reachable from channels_home_screen.dart's overflow
/// menu once the home screen became a flat, recency-sorted Channel list
/// (Spaces/Frames are infrastructure behind the actual communication,
/// not the communication itself -- see project_ui-redesign-concepts).
/// A normal pushed screen now, no header camera/overflow chrome of its
/// own -- that lives on the actual home screen only, same as WhatsApp
/// never repeats its own chat-list header controls on a sub-screen.
class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  List<Map<String, dynamic>>? _spaces;
  String? _errorMessage;
  bool _isCreating = false;

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

  /// Redeeming a channel_space_share code (0030_multi_space_channels.sql):
  /// links one of *my* Spaces to a channel someone else shares -- e.g. Opa
  /// entering a code Oma generated in her "Enkelkinder" channel so both
  /// households see and can post into it from then on. Unlike a plain
  /// membership invite (JoinChannelScreen), this needs the redeemer to also
  /// pick *which* of their own Spaces gets linked.
  Future<void> _redeemChannelSpaceShare() async {
    final spaces = _spaces;
    if (spaces == null || spaces.isEmpty) return;
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _EnterCodeDialog(),
    );
    if (code == null || code.trim().isEmpty) return;

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
      final result = await MembershipService().claimChannelSpaceShare(code: code.trim(), spaceId: spaceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${result.channelName}" ist jetzt mit diesem Space verknüpft.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code konnte nicht eingelöst werden: $e')),
      );
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: (_spaces?.isEmpty ?? true) ? null : _redeemChannelSpaceShare,
                  icon: const Icon(Icons.hub_outlined),
                  label: const Text('Channel-Code einlösen'),
                ),
              ],
            ),
    );
  }
}

class _EnterCodeDialog extends StatefulWidget {
  @override
  State<_EnterCodeDialog> createState() => _EnterCodeDialogState();
}

class _EnterCodeDialogState extends State<_EnterCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Code eingeben'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Code'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Einlösen'),
        ),
      ],
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
