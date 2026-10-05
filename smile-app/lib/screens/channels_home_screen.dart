import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/channel_picker_service.dart';
import '../services/sync_bus.dart';
import '../widgets/top_bar_actions.dart';
import 'channel_feed_screen.dart';
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
  ChannelsHomeScreen({super.key, ChannelPickerService? channelPickerService, this.onOpenSpaces})
      : channelPickerService = channelPickerService ?? ChannelPickerService();

  final ChannelPickerService channelPickerService;

  /// Switches to the Spaces tab when hosted in HomeShell; without it the
  /// Spaces screen is pushed instead.
  final VoidCallback? onOpenSpaces;

  @override
  State<ChannelsHomeScreen> createState() => _ChannelsHomeScreenState();
}

class _ChannelsHomeScreenState extends State<ChannelsHomeScreen> with SyncReload {
  List<ChannelWithActivity>? _channels;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() => _load();

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
        _errorMessage = SmileTexts.of(context).albumsLoadError('$e');
      });
    }
  }


  Future<void> _openMySpaces() async {
    final onOpenSpaces = widget.onOpenSpaces;
    if (onOpenSpaces != null) return onOpenSpaces();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SpacesScreen()));
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
        actions: smileTopBarActions(onPhotoSent: _load),
      ),
      body: channels == null
          ? const Center(child: CircularProgressIndicator())
          : channels.isEmpty
              ? _EmptyState(errorMessage: _errorMessage, onOpenSpaces: _openMySpaces)
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
                        SmileObjectTile(
                          leading: const SmileObjectIcon(icon: SmileIcons.album),
                          title: channel.channelName,
                          // Role icon first: pencil = Member (may post),
                          // binoculars = Viewer (sees it via a share).
                          subtitleIcon: channel.isMember ? SmileRole.member.icon : SmileRole.viewer.icon,
                          subtitle: channel.spaceLabel,
                          trailing: Text(
                            _relativeTime(channel.lastActivityAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
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

/// Interim empty state -- the "Zwei Wege" first-start screen (decision 6)
/// replaces it in a later stage. Invitations are reachable through the
/// Neuigkeiten icon in the top bar.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.errorMessage, required this.onOpenSpaces});

  final String? errorMessage;
  final VoidCallback onOpenSpaces;

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Column(
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: SmileEmptyState(
            icon: SmileIcons.album,
            title: t.albumsEmptyTitle,
            message: t.albumsEmptyMessage,
            actionLabel: t.openSpaces,
            actionIcon: SmileIcons.space,
            onAction: onOpenSpaces,
          ),
        ),
      ],
    );
  }
}
