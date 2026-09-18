import 'package:flutter/material.dart';

import '../services/frame_service.dart';
import 'frame_settings_screen.dart';

/// Per-Space Frame list -- reached from spaces_screen.dart. Shows each
/// Frame's lifecycle status at a glance; renaming, revoke/reactivate, and
/// channel assignment live in frame_settings_screen.dart.
class FrameListScreen extends StatefulWidget {
  FrameListScreen({super.key, required this.spaceId, required this.spaceName, FrameService? frameService})
      : frameService = frameService ?? FrameService();

  final String spaceId;
  final String spaceName;
  final FrameService frameService;

  @override
  State<FrameListScreen> createState() => _FrameListScreenState();
}

class _FrameListScreenState extends State<FrameListScreen> {
  List<SmileFrame>? _frames;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final frames = await widget.frameService.listFrames(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _frames = frames;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _frames ??= const [];
        _errorMessage = 'Frames konnten nicht geladen werden: $e';
      });
    }
  }

  String _statusLabel(SmileFrame frame) => switch (frame.lifecycleState) {
        'active' => 'Aktiv',
        'revoked' => 'Widerrufen',
        'pending' => 'Wartet auf Kopplung…',
        _ => frame.lifecycleState,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Frames · ${widget.spaceName}')),
      body: _frames == null
          ? const Center(child: CircularProgressIndicator())
          : _frames!.isEmpty
              ? Center(
                  child: Text(_errorMessage ?? 'Noch kein Frame in diesem Space erstellt.'),
                )
              : ListView(
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    for (final frame in _frames!)
                      ListTile(
                        leading: Icon(
                          Icons.tablet_mac,
                          color: frame.isRevoked ? Theme.of(context).disabledColor : null,
                        ),
                        title: Text(
                          frame.name,
                          style: frame.isRevoked ? TextStyle(color: Theme.of(context).disabledColor) : null,
                        ),
                        subtitle: Text(_statusLabel(frame)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FrameSettingsScreen(
                                frame: frame,
                                spaceId: widget.spaceId,
                                frameService: widget.frameService,
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
