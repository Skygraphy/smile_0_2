import 'package:flutter/material.dart';

import '../services/membership_service.dart';

/// "Freigaben verwalten": every channel currently shared (view-only) into
/// this Space, with a revoke action -- the linked Space's own owner can
/// always unilaterally revoke (channel_shares_owner_delete's RLS never
/// lets the channel's SCO block this), so this has to live on the Space
/// side, not the channel side. Directly implements the scenario from the
/// architecture reset's design conversation: Roman must be able to check
/// (and potentially revoke) what Davidopa currently sees, since he's the
/// one who has to control that, not Ernst.
class SpaceSharedChannelsScreen extends StatefulWidget {
  const SpaceSharedChannelsScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
    required this.membershipService,
  });

  final String spaceId;
  final String spaceName;
  final MembershipService membershipService;

  @override
  State<SpaceSharedChannelsScreen> createState() => _SpaceSharedChannelsScreenState();
}

class _SpaceSharedChannelsScreenState extends State<SpaceSharedChannelsScreen> {
  List<SharedChannelSummary>? _channels;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final channels = await widget.membershipService.listSharedChannelsForSpace(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _channels ??= const [];
        _errorMessage = 'Freigaben konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _revoke(SharedChannelSummary channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${channel.channelName}" nicht mehr anzeigen?'),
        content: const Text('Dieser Space verliert sofort die Sicht auf diesen Channel.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Widerrufen')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.membershipService.revokeShare(channelId: channel.channelId, spaceId: widget.spaceId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    return Scaffold(
      appBar: AppBar(title: Text('Freigaben · ${widget.spaceName}')),
      body: channels == null
          ? Center(child: _errorMessage != null ? Text(_errorMessage!) : const CircularProgressIndicator())
          : channels.isEmpty
              ? const Center(child: Text('Kein Channel wurde mit diesem Space geteilt.'))
              : ListView(
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    for (final channel in channels)
                      ListTile(
                        leading: const Icon(Icons.hub_outlined),
                        title: Text(channel.channelName),
                        subtitle: const Text('Nur ansehen'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Widerrufen',
                          onPressed: () => _revoke(channel),
                        ),
                      ),
                  ],
                ),
    );
  }
}
