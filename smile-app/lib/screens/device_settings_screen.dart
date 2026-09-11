import 'package:flutter/material.dart';

import '../services/device_service.dart';

/// Channel-Wechsel-Freigabe (Personal Mode, concept doc sect. 19) and which
/// channels of its own Space a device shows -- the minimal device-settings
/// surface needed to make the Frame channel-switcher usable. See
/// device_service.dart for why this is scoped to the device's own Space.
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({
    super.key,
    required this.device,
    required this.spaceId,
    required this.deviceService,
  });

  final SmileDevice device;
  final String spaceId;
  final DeviceService deviceService;

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  late SmileDevice _device = widget.device;
  List<DeviceChannelAssignment>? _assignments;
  bool? _channelSwitchEnabled;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.deviceService.getDevice(widget.device.id),
        widget.deviceService.listAssignedChannels(widget.device.id),
        widget.deviceService.getChannelSwitchEnabled(widget.device.id),
      ]);
      if (!mounted) return;
      setState(() {
        _device = results[0] as SmileDevice;
        _assignments = results[1] as List<DeviceChannelAssignment>;
        _channelSwitchEnabled = results[2] as bool;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignments ??= const [];
        _channelSwitchEnabled ??= false;
        _errorMessage = 'Geräte-Details konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _device.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerät umbenennen'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Speichern')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == _device.name) return;
    await widget.deviceService.renameDevice(deviceId: _device.id, name: name.trim());
    await _load();
  }

  Future<void> _toggleRevoked() async {
    final revoking = !_device.isRevoked;
    if (revoking) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gerät widerrufen?'),
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
    await widget.deviceService.setRevoked(deviceId: _device.id, revoked: revoking);
    await _load();
  }

  Future<void> _toggleChannelSwitch(bool value) async {
    setState(() => _channelSwitchEnabled = value);
    await widget.deviceService.setChannelSwitchEnabled(deviceId: _device.id, enabled: value);
  }

  Future<void> _unassign(DeviceChannelAssignment assignment) async {
    await widget.deviceService.unassignChannel(assignment.membershipId);
    await _load();
  }

  Future<void> _assignChannel() async {
    final choices = await widget.deviceService.listUnassignedChannelsInSpace(
      spaceId: widget.spaceId,
      deviceId: _device.id,
    );
    if (!mounted) return;
    if (choices.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Channel zuweisen'),
          content: const Text('Es gibt keine weiteren Channels in diesem Space.'),
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
    await widget.deviceService.assignChannel(deviceId: _device.id, channelId: picked.channelId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final assignments = _assignments;
    final channelSwitchEnabled = _channelSwitchEnabled;
    return Scaffold(
      appBar: AppBar(
        title: Text(_device.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: 'Umbenennen', onPressed: _rename),
          IconButton(
            icon: Icon(_device.isRevoked ? Icons.lock_open : Icons.block),
            tooltip: _device.isRevoked ? 'Wieder aktivieren' : 'Widerrufen',
            onPressed: _toggleRevoked,
          ),
        ],
      ),
      body: assignments == null || channelSwitchEnabled == null
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
                  value: channelSwitchEnabled,
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
    final complianceLabels = {
      'compliant': 'Konform',
      'drift_detected': 'Abweichung erkannt',
      'repaired': 'Repariert',
      'unknown': 'Unbekannt',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _device.isRevoked ? Icons.block : Icons.circle,
                  size: 12,
                  color: _device.isRevoked
                      ? Theme.of(context).colorScheme.error
                      : (_device.lifecycleState == 'active' ? Colors.green : Colors.grey),
                ),
                const SizedBox(width: 8),
                Text(
                  _device.isRevoked ? 'Widerrufen' : (_device.lifecycleState == 'active' ? 'Aktiv' : 'Offline'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statusRow('Zuletzt gesehen', _formatDateTime(_device.lastSeenAt)),
            _statusRow('App-Version', _device.currentAppVersion ?? '—'),
            _statusRow(
              'Akku',
              _device.batteryLevel != null
                  ? '${_device.batteryLevel}%${_device.isCharging == true ? ' (lädt)' : ''}'
                  : '—',
            ),
            _statusRow(
              'Compliance',
              _device.lastComplianceState != null
                  ? '${complianceLabels[_device.lastComplianceState] ?? _device.lastComplianceState} · ${_formatDateTime(_device.lastComplianceCheckAt)}'
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
