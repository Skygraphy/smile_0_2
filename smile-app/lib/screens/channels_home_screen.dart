import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import '../services/channel_picker_service.dart';
import '../services/space_service.dart';
import '../services/sync_bus.dart';
import '../widgets/top_bar_actions.dart';
import 'channel_feed_screen.dart';
import 'news_screen.dart';
import 'space_info_screen.dart';

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


  /// "Ich wurde eingeladen": invitations arrive by email address and wait
  /// in Neuigkeiten -- there is no invite code to type in.
  Future<void> _openNews() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewsScreen()));
    await _load();
  }

  /// "Ich richte Smile ein": name a Space, then land on its info page,
  /// whose empty sections offer the next steps (album, Frame).
  Future<void> _setUpSpace() async {
    final t = SmileTexts.of(context);
    final navigator = Navigator.of(context);
    final name = await showSmileNameDialog(context, title: t.createSpace, confirmLabel: t.create, hint: t.createSpaceHint);
    if (name == null) return;
    try {
      final spaceId = await SpaceService().createSpace(name);
      await navigator.push(MaterialPageRoute(builder: (_) => SpaceInfoScreen(spaceId: spaceId, spaceName: name)));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
    }
  }


  /// "Roman: 4 Fotos", "Du: Video", "Anna: 2 Fotos, 1 Video".
  String _lastPostLine(BuildContext context, ChannelWithActivity channel) {
    final t = SmileTexts.of(context);
    final post = channel.lastPost;
    if (post == null) return t.noPostsYet;
    final who = post.senderId == supabase.auth.currentUser?.id ? t.you : (post.senderName ?? t.someone);
    final what = [
      if (post.photos > 0) t.postPhotos(post.photos),
      if (post.videos > 0) t.postVideos(post.videos),
    ].join(', ');
    return t.lastPostBy(who, what);
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
              ? _FirstSteps(errorMessage: _errorMessage, onInvited: _openNews, onSetUp: _setUpSpace)
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
                          leading: SmileAlbumCover(
                            name: channel.channelName,
                            imageUrl: channel.coverUrl,
                            cacheKey: channel.coverMediaId == null ? null : 'cover_${channel.coverMediaId}',
                          ),
                          title: channel.channelName,
                          // Role icon first: pencil = Member (may post),
                          // binoculars = Viewer (sees it via a share); then
                          // the newest post, WhatsApp chat-list style.
                          subtitleIcon: channel.isMember ? SmileRole.member.icon : SmileRole.viewer.icon,
                          subtitle: _lastPostLine(context, channel),
                          trailing: _ActivityMeta(
                            time: _relativeTime(channel.lastActivityAt),
                            unread: channel.unreadCount,
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

/// First start, no albums yet (decision 6, "Zwei Wege", 2026-10-05):
/// most people arrive through an invitation, a few set Smile up -- so the
/// empty album list asks which of the two applies.
class _FirstSteps extends StatelessWidget {
  const _FirstSteps({required this.errorMessage, required this.onInvited, required this.onSetUp});

  final String? errorMessage;
  final VoidCallback onInvited;
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final theme = Theme.of(context);
    final email = supabase.auth.currentUser?.email;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l),
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: SmileSpacing.l),
            child: Text(errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 64),
        const Center(child: SmileObjectIcon(icon: SmileIcons.album, size: 72, iconSize: 34)),
        const SizedBox(height: SmileSpacing.m),
        Text(
          t.firstStepsWelcome,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: SmileSpacing.s),
        Text(
          t.firstStepsQuestion,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: SmileSpacing.xl),
        SmileChoiceCard(icon: SmileIcons.news, title: t.firstStepsInvited, hint: t.firstStepsInvitedHint, onTap: onInvited),
        const SizedBox(height: SmileSpacing.m),
        SmileChoiceCard(icon: SmileIcons.space, title: t.firstStepsSetup, hint: t.firstStepsSetupHint, onTap: onSetUp),
        if (email != null) ...[
          const SizedBox(height: SmileSpacing.xl),
          Text(
            t.firstStepsYourEmail(email),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Right side of an album row, WhatsApp-style: the time, and below it a
/// coral counter of others' posts not seen yet (the time turns coral too).
class _ActivityMeta extends StatelessWidget {
  const _ActivityMeta({required this.time, required this.unread});

  final String time;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUnread = unread > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          time,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasUnread ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: hasUnread ? FontWeight.w600 : null,
              ),
        ),
        if (hasUnread) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(SmileRadius.pill)),
            child: Text(
              unread > 99 ? '99+' : '$unread',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}
