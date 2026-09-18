import 'package:flutter/material.dart';

import '../services/frame_service.dart';

/// Channel-Wechsel-Freigabe (Personal Mode) and which channels a Frame
/// shows -- the minimal Frame-settings surface needed to make the Frame
/// channel-switcher usable. No MDM/compliance surface any more (removed
/// with the architecture reset, migrations/0031_architecture_reset.sql) --
/// just plain operational telemetry (last seen, app version, battery).
class FrameSettingsScreen extends StatefulWidget {
  const FrameSettingsScreen({
    super.key,
    required this.frame,
    required this.spaceId,
    required this.frameService,
  });

  final SmileFrame frame;
  final String spaceId;
  final FrameService frameService;

  @override
  State<FrameSettingsScreen> createState() => _FrameSettingsScreenState();
}

class _FrameSettingsScreenState extends State<FrameSettingsScreen> {
  late SmileFrame _frame = widget.frame;
  List<FrameChannelAssignment>? _assignments;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.frameService.getFrame(widget.frame.id),
        widget.frameService.listAssignedChannels(widget.frame.id),
      ]);
      if (!mounted) return;
      setState(() {
        _frame = results[0] as SmileFrame;
        _assignments = results[1] as List<FrameChannelAssignment>;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignments ??= const [];
        _errorMessage = 'Frame-Details konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _frame.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frame umbenennen'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Speichern')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == _frame.name) return;
    await widget.frameService.renameFrame(frameId: _frame.id, name: name.trim());
    await _load();
  }

  Future<void> _toggleRevoked() async {
    final revoking = !_frame.isRevoked;
    if (revoking) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Frame widerrufen?'),
          content: const Text(
            'Das Frame verliert sofort jeden Zugriff (Sync, Fotos). Es kann später jederzeit wieder aktiviert werden.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Widerrufen')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await widget.frameService.setRevoked(frameId: _frame.id, revoked: revoking);
    await _load();
  }

  Future<void> _toggleChannelSwitch(bool value) async {
    setState(() => _frame = SmileFrame(
          id: _frame.id,
          name: _frame.name,
          lifecycleState: _frame.lifecycleState,
          channelSwitchEnabled: value,
          pairingCode: _frame.pairingCode,
          pairingCodeExpiresAt: _frame.pairingCodeExpiresAt,
          currentAppVersion: _frame.currentAppVersion,
          lastSeenAt: _frame.lastSeenAt,
          batteryLevel: _frame.batteryLevel,
          isCharging: _frame.isCharging,
        ));
    await widget.frameService.setChannelSwitchEnabled(frameId: _frame.id, enabled: value);
  }

  Future<void> _unassign(FrameChannelAssignment assignment) async {
    await widget.frameService.unassignChannel(frameId: _frame.id, channelId: assignment.channelId);
    await _load();
  }

  Future<void> _assignChannel() async {
    final choices = await widget.frameService.listUnassignedChannelsInSpace(
      spaceId: widget.spaceId,
      frameId: _frame.id,
    );
    if (!mounted) return;
    if (choices.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Channel zuweisen'),
          content: const Text('Es gibt keine weiteren Channels, die dieser Space sehen kann.'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen'))],
        ),
      );
      return;
    }
    final picked = await showDialog<AssignableChannel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Channel zuweisen'),
        children: [
          for (final channel in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(channel),
              child: Text(channel.channelName),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await widget.frameService.assignChannel(frameId: _frame.id, channelId: picked.channelId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final assignments = _assignments;
    return Scaffold(
      appBar: AppBar(
        title: Text(_frame.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: 'Umbenennen', onPressed: _rename),
          IconButton(
            icon: Icon(_frame.isRevoked ? Icons.lock_open : Icons.block),
            tooltip: _frame.isRevoked ? 'Wieder aktivieren' : 'Widerrufen',
            onPressed: _toggleRevoked,
          ),
        ],
      ),
      body: assignments == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                _buildStatusCard(context),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Channel-Wechsel erlauben'),
                  subtitle: const Text(
                    'Personal Mode: die Person vor dem Frame kann selbst zwischen den zugewiesenen Channels wechseln.',
                  ),
                  value: _frame.channelSwitchEnabled,
                  onChanged: _toggleChannelSwitch,
                ),
                const SizedBox(height: 20),
                Text('Zugewiesene Channels', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (assignments.isEmpty) const Text('Noch kein Channel zugewiesen.'),
                for (final assignment in assignments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(assignment.channelName),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Entfernen',
                      onPressed: () => _unassign(assignment),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _assignChannel,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Channel zuweisen'),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _frame.isRevoked ? Icons.block : Icons.circle,
                  size: 12,
                  color: _frame.isRevoked
                      ? Theme.of(context).colorScheme.error
                      : (_frame.lifecycleState == 'active' ? Colors.green : Colors.grey),
                ),
                const SizedBox(width: 8),
                Text(
                  _frame.isRevoked ? 'Widerrufen' : (_frame.lifecycleState == 'active' ? 'Aktiv' : 'Wartet auf Kopplung'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statusRow('Zuletzt gesehen', _formatDateTime(_frame.lastSeenAt)),
            _statusRow('App-Version', _frame.currentAppVersion ?? '—'),
            _statusRow(
              'Akku',
              _frame.batteryLevel != null
                  ? '${_frame.batteryLevel}%${_frame.isCharging == true ? ' (lädt)' : ''}'
                  : '—',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
