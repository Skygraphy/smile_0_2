import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/channel_picker_service.dart';
import '../widgets/smile_avatar.dart';
import '../widgets/smile_wordmark.dart';
import 'channel_feed_screen.dart';
import 'groups_screen.dart';
import 'join_channel_screen.dart';
import 'quick_capture_channel_picker_screen.dart';
import 'settings_screen.dart';
import 'spaces_screen.dart';

/// The app's new landing screen. WhatsApp's chat list shows conversations
/// sorted by recency, not a device/contact hierarchy first -- Spaces and
/// Frames are infrastructure (device routing, ownership), the Channel is
/// where photo-exchange (the actual "communication") happens, so this
/// replaces the old Space-first home screen (spaces_screen.dart, now
/// "Meine Spaces", a secondary admin area reachable from the overflow
/// menu) with a flat list of every channel the caller can see, sorted by
/// most recent activity -- see project_ui-redesign-concepts memory for
/// the reasoning behind this.
class ChannelsHomeScreen extends StatefulWidget {
  ChannelsHomeScreen({super.key, ChannelPickerService? channelPickerService})
      : channelPickerService = channelPickerService ?? ChannelPickerService();

  final ChannelPickerService channelPickerService;

  @override
  State<ChannelsHomeScreen> createState() => _ChannelsHomeScreenState();
}

class _ChannelsHomeScreenState extends State<ChannelsHomeScreen> {
  List<ChannelWithActivity>? _channels;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final channels = await widget.channelPickerService.listMyChannelsWithActivity();
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

  Future<void> _quickCapture() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension = picked.path.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickCaptureChannelPickerScreen(bytes: bytes, fileExtension: extension, mimeType: mimeType),
      ),
    );
    await _load();
  }

  Future<void> _joinByInvite() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JoinChannelScreen()));
    await _load();
  }

  Future<void> _openMySpaces() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpacesScreen()));
    await _load();
  }

  String _relativeTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24 && now.day == local.day) return 'vor ${diff.inHours} Std.';
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) {
      return 'Gestern';
    }
    if (diff.inDays < 7) {
      const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      return weekdays[local.weekday - 1];
    }
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    return Scaffold(
      appBar: AppBar(
        title: const SmileWordmark(fontSize: 20),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: 'Foto senden',
            onPressed: _quickCapture,
          ),
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen())),
                child: const Text('Einstellungen'),
              ),
              PopupMenuItem(value: _openMySpaces, child: const Text('Meine Spaces')),
              PopupMenuItem(
                value: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupsScreen())),
                child: const Text('Meine Gruppen'),
              ),
            ],
          ),
        ],
      ),
      body: channels == null
          ? const Center(child: CircularProgressIndicator())
          : channels.isEmpty
              ? _EmptyState(errorMessage: _errorMessage, onOpenSpaces: _openMySpaces, onJoinByInvite: _joinByInvite)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                      for (final channel in channels)
                        ListTile(
                          leading: SmileAvatar(name: channel.channelName),
                          title: Text(channel.channelName),
                          subtitle: Text(channel.spaceLabel),
                          trailing: Text(
                            _relativeTime(channel.lastActivityAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChannelFeedScreen(
                                  channelId: channel.channelId,
                                  channelName: channel.channelName,
                                ),
                              ),
                            );
                            await _load();
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.errorMessage, required this.onOpenSpaces, required this.onJoinByInvite});

  final String? errorMessage;
  final VoidCallback onOpenSpaces;
  final VoidCallback onJoinByInvite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorMessage != null) ...[
              Text(errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
            ],
            const Text(
              'Noch keine Channels. Lege einen Space an oder tritt einem Channel per Einladung bei.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onOpenSpaces,
              icon: const Icon(Icons.workspaces_outlined),
              label: const Text('Meine Spaces öffnen'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onJoinByInvite,
              icon: const Icon(Icons.group_add),
              label: const Text('Einladung einlösen'),
            ),
          ],
        ),
      ),
    );
  }
}
