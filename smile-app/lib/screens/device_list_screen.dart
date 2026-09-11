import 'package:flutter/material.dart';

import '../services/device_service.dart';
import 'device_settings_screen.dart';

/// Per-Space device list -- reached from spaces_screen.dart. Shows each
/// device's lifecycle status at a glance; renaming, revoke/reactivate, and
/// compliance detail live in device_settings_screen.dart.
class DeviceListScreen extends StatefulWidget {
  DeviceListScreen({super.key, required this.spaceId, required this.spaceName, DeviceService? deviceService})
      : deviceService = deviceService ?? DeviceService();

  final String spaceId;
  final String spaceName;
  final DeviceService deviceService;

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<SmileDevice>? _devices;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final devices = await widget.deviceService.listDevices(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _devices ??= const [];
        _errorMessage = 'Geräte konnten nicht geladen werden: $e';
      });
    }
  }

  bool _isInactive(SmileDevice device) => device.lifecycleState == 'revoked' || device.lifecycleState == 'retired';

  String _statusLabel(SmileDevice device) => switch (device.lifecycleState) {
        'active' => 'Aktiv',
        'offline' => 'Offline',
        'revoked' => 'Widerrufen',
        'retired' => 'Ersetzt (retired)',
        'pairing' => 'Wird gekoppelt…',
        _ => device.lifecycleState,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Geräte · ${widget.spaceName}')),
      body: _devices == null
          ? const Center(child: CircularProgressIndicator())
          : _devices!.isEmpty
              ? Center(
                  child: Text(_errorMessage ?? 'Noch kein Frame in diesem Space gekoppelt.'),
                )
              : ListView(
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    for (final device in _devices!)
                      ListTile(
                        leading: Icon(
                          Icons.tablet_mac,
                          color: _isInactive(device) ? Theme.of(context).disabledColor : null,
                        ),
                        title: Text(
                          device.name,
                          style: _isInactive(device) ? TextStyle(color: Theme.of(context).disabledColor) : null,
                        ),
                        subtitle: Text(_statusLabel(device)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DeviceSettingsScreen(
                                device: device,
                                spaceId: widget.spaceId,
                                deviceService: widget.deviceService,
                              ),
                            ),
                          );
                          await _load();
                        },
                      ),
                  ],
                ),
    );
  }
}
