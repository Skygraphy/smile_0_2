import 'package:flutter/material.dart';

import '../services/channel_service.dart';
import '../services/sync_bus.dart';
import 'channel_feed_screen.dart';

/// Minimal Space-Owner-Home for Phase 3 testing (full version with device
/// assignment, channel requests, member management is Phase 6).
class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key, required this.spaceId, required this.spaceName});

  final String spaceId;
  final String spaceName;

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> with SyncReload {
  final _channelService = ChannelService();
  List<Map<String, dynamic>>? _channels;
  String? _errorMessage;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() async {
    if (await closeIfGone(context, table: 'spaces', id: widget.spaceId)) return;
    await _load();
  }

  Future<void> _load() async {
    try {
      final channels = await _channelService.listChannels(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _channels ??= const [];
        _errorMessage = 'Channels konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _createChannel() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreateChannelDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => _isCreating = true);
    try {
      await _channelService.createChannel(spaceId: widget.spaceId, name: name.trim());
      await _load();
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteChannel(Map<String, dynamic> channel) async {
    final name = channel['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Channel „$name“ löschen?'),
        content: const Text(
          'Alle Fotos in diesem Channel werden für alle Mitglieder, alle verknüpften Spaces und auf allen Frames '
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
      await _channelService.deleteChannel(channel['id'] as String);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Channel „$name“ gelöscht.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.spaceName)),
      body: _channels == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                for (final channel in _channels!)
                  Card(
                    child: ListTile(
                      title: Text(channel['name'] as String),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChannelFeedScreen(
                            channelId: channel['id'] as String,
                            channelName: channel['name'] as String,
                          ),
                        ),
                      ),
                      // Only the Administrator/co-owners ever reach this
                      // screen (spaces_screen lists only Spaces they manage).
                      trailing: PopupMenuButton<VoidCallback>(
                        onSelected: (action) => action(),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: () => _deleteChannel(channel), child: const Text('Channel löschen')),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isCreating ? null : _createChannel,
                  icon: const Icon(Icons.add),
                  label: const Text('Channel erstellen'),
                ),
              ],
            ),
    );
  }
}

class _CreateChannelDialog extends StatefulWidget {
  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Channel erstellen'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name (z.B. "Familie Sohn")'),
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
