import 'dart:async';

import 'package:flutter/material.dart';
import '../services/perf.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../widgets/friendly_error.dart';

import '../main.dart';
import '../services/avatar_upload.dart';
import '../services/channel_picker_service.dart';
import '../services/channel_service.dart';
import '../services/local_changes.dart';
import '../services/space_service.dart';
import '../services/sync_bus.dart';
import '../widgets/local_display.dart';
import '../widgets/album_covers.dart';
import '../widgets/top_bar_actions.dart';
import '../services/offline.dart';
import 'channel_feed_screen.dart';
import 'scan_code_screen.dart';
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

/// A Space the caller manages -- where "Neues Album" can put an album.
class _ManagedSpace {
  const _ManagedSpace({required this.id, required this.name, required this.albums, required this.frames, this.avatarPath});

  final String id;
  final String name;
  final int albums;
  final int frames;
  final String? avatarPath;
}

class _ChannelsHomeScreenState extends State<ChannelsHomeScreen> with SyncReload {
  List<ChannelWithActivity>? _channels;
  String? _errorMessage;

  /// Spaces the caller manages (Admin or Co-Admin -- spaces_select returns
  /// only those); empty for a plain Member, who then gets no "Neues Album".
  List<_ManagedSpace> _managed = const [];

  @override
  void initState() {
    super.initState();
    // The list as last loaded shows at once (also offline), then refreshes.
    widget.channelPickerService.cachedMyChannels().then((cached) {
      if (cached != null && mounted && _channels == null) {
        setState(() => _channels = cached);
        Perf.mark('album list shown (from the phone)');
      }
    });
    _load();
  }

  @override
  Future<void> onSync() => _load();

  Future<void> _load() async {
    unawaited(_loadManaged());
    Perf.start('album list');
    try {
      final channels = await widget.channelPickerService.listMyChannelsWithActivity();
      Perf.end('album list', '${channels.length} albums');
      Perf.mark('album list shown');
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      final offline = Offline.isConnectionError(e);
      setState(() {
        _channels ??= const [];
        // Offline: the hint above says it; the list as last loaded stays.
        _errorMessage = offline ? null : SmileTexts.of(context).albumsLoadError(errorReason(context, e));
      });
    }
  }


  Future<void> _loadManaged() async {
    try {
      final results = await Future.wait<dynamic>([
        supabase.from('spaces').select('id, name, avatar_path').order('created_at'),
        supabase.from('channels').select('space_id'),
        supabase.from('frames').select('space_id'),
      ]);
      Map<String, int> countBySpace(List rows) {
        final counts = <String, int>{};
        for (final row in rows.cast<Map<String, dynamic>>()) {
          final id = row['space_id'] as String;
          counts[id] = (counts[id] ?? 0) + 1;
        }
        return counts;
      }

      final albums = countBySpace(results[1] as List);
      final frames = countBySpace(results[2] as List);
      if (!mounted) return;
      setState(() {
        _managed = [
          for (final row in (results[0] as List).cast<Map<String, dynamic>>())
            _ManagedSpace(
              id: row['id'] as String,
              name: row['name'] as String,
              albums: albums[row['id']] ?? 0,
              frames: frames[row['id']] ?? 0,
              avatarPath: row['avatar_path'] as String?,
            ),
        ];
      });
    } catch (_) {
      // Offline or the like: the menu keeps what it knew.
    }
  }

  /// "Neues Album" from the ⋮ menu (2026-10-13, like WhatsApp's "Neue
  /// Gruppe"): straight to the name with one Space, else first which
  /// Space; the new album opens right away.
  Future<void> _newAlbum() async {
    final t = SmileTexts.of(context);
    final navigator = Navigator.of(context);
    final spaces = _managed;
    if (spaces.isEmpty) return;
    final space = spaces.length == 1 ? spaces.single : await _pickSpace(spaces);
    if (space == null || !mounted) return;
    final shownSpace = spaceNameOf(space.id, space.name);
    final name = await showSmileNameDialog(
      context,
      title: t.newAlbum,
      subtitle: t.inSpaceLine(shownSpace),
      confirmLabel: t.create,
      hint: t.createAlbumHint,
    );
    if (name == null) return;
    try {
      final channelId = await ChannelService().createChannel(spaceId: space.id, name: name);
      unawaited(_load());
      await navigator.push(MaterialPageRoute(builder: (_) => ChannelFeedScreen(channelId: channelId, channelName: name)));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed(errorReason(context, e)));
    }
  }

  Future<_ManagedSpace?> _pickSpace(List<_ManagedSpace> spaces) {
    final t = SmileTexts.of(context);
    return showModalBottomSheet<_ManagedSpace>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.s),
              child: Text(t.newAlbumWhere, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final space in spaces)
              SmileObjectTile(
                leading: objectPicture(
                  key: LocalChanges.spacePicture(space.id),
                  name: spaceNameOf(space.id, space.name),
                  serverUrl: avatarPathToUrl(space.avatarPath),
                ),
                title: spaceNameOf(space.id, space.name),
                subtitle: [t.albumCount(space.albums), t.frameCount(space.frames)].join(' · '),
                onTap: () => Navigator.of(context).pop(space),
              ),
            const SizedBox(height: SmileSpacing.s),
          ],
        ),
      ),
    );
  }

  /// "Ich wurde eingeladen": invitations arrive by email address and wait
  /// in Neuigkeiten -- there is no invite code to type in.
  /// "Ich wurde eingeladen": scan the QR code or type the code (2026-10-11).
  Future<void> _scanCode() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanCodeScreen()));
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
      if (mounted) setState(() => _errorMessage = t.actionFailed(errorReason(context, e)));
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
        // As big as WhatsApp's name in its top bar (2026-10-17).
        title: const SmileWordmark(fontSize: 25),
        actions: smileTopBarActions(
          onPhotoSent: _load,
          primary: _managed.isEmpty ? null : SmileMenuEntry(icon: SmileIcons.add, label: SmileTexts.of(context).newAlbum, onTap: _newAlbum),
          onChanged: _load,
        ),
      ),
      body: _body(channels),
    );
  }

  Widget _body(List<ChannelWithActivity>? channels) {
    return channels == null
          ? const Center(child: CircularProgressIndicator())
          : channels.isEmpty
              ? _FirstSteps(errorMessage: _errorMessage, onInvited: _scanCode, onSetUp: _setUpSpace)
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
                          // Same cover logic as everywhere, own changes included.
                          leading: albumCover(
                            channel.channelId,
                            albumNameOf(channel.channelId, channel.channelName),
                            {channel.channelId: channel},
                          ),
                          title: albumNameOf(channel.channelId, channel.channelName),
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
                                  channelName: albumNameOf(channel.channelId, channel.channelName),
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
