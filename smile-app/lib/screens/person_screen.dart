import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/invite_service.dart';
import '../services/membership_service.dart';
import '../services/offline.dart';
import '../services/profile_service.dart';
import '../widgets/friendly_error.dart';

/// Someone's card, opened from their link or QR code (smileapp.app/@name,
/// 2026-10-17): who it is, and "In ein Album einladen".
class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, required this.handle});

  final String handle;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  final _invites = InviteService();
  KnownPerson? _person;
  bool _loading = true;
  bool _isMe = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final person = await _invites.findByHandle(widget.handle);
      var isMe = false;
      if (person == null) isMe = (await ProfileService().getMyProfile())?.handle == widget.handle;
      if (!mounted) return;
      setState(() {
        _person = person;
        _isMe = isMe;
      });
    } catch (e) {
      if (mounted) setState(() => _message = SmileTexts.of(context).actionFailed(errorReason(context, e)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _inviteIntoAlbum(KnownPerson person) async {
    final t = SmileTexts.of(context);
    final albums = _invites.albumsICanInviteTo();
    final album = await showModalBottomSheet<InvitableAlbum>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
        child: FutureBuilder<List<InvitableAlbum>>(
          future: albums,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(SmileSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final list = snapshot.data ?? const <InvitableAlbum>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.s),
                  child: Text(t.pickAlbumToInvite, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(SmileSpacing.l),
                    child: Text(t.noAlbumsToInvite,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.only(bottom: SmileSpacing.m + MediaQuery.paddingOf(context).bottom),
                      children: [
                        for (final a in list)
                          SmileObjectTile(
                            leading: const Icon(SmileIcons.album),
                            title: a.name,
                            subtitle: a.spaceName,
                            onTap: () => Navigator.of(sheetContext).pop(a),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
    if (album == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MembershipService().inviteMember(channelId: album.id, userId: person.userId);
      messenger.showSnackBar(SnackBar(content: Text(t.inviteSentTo(person.name))));
    } catch (e) {
      if (!mounted) return;
      if (Offline.isConnectionError(e)) {
        await showNoConnection(context);
        return;
      }
      setState(() => _message = e is ChannelRequestException ? e.message : t.actionFailed(errorReason(context, e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final person = _person;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SmileSpacing.l),
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (person != null) ...[
                      SmileAvatar(name: person.name, avatarUrl: person.avatarUrl, size: 96),
                      const SizedBox(height: SmileSpacing.m),
                      Text(person.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('@${person.handle ?? widget.handle}',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: SmileSpacing.xl),
                      FilledButton.icon(
                        onPressed: () => _inviteIntoAlbum(person),
                        icon: const Icon(SmileIcons.invite),
                        label: Text(t.inviteIntoAlbum),
                      ),
                    ] else ...[
                      Icon(SmileIcons.handle, size: 56, color: muted),
                      const SizedBox(height: SmileSpacing.m),
                      Text('@${widget.handle}', style: theme.textTheme.titleMedium),
                      const SizedBox(height: SmileSpacing.s),
                      if (_message == null)
                        Text(_isMe ? t.personIsYou : t.personNotFound,
                            textAlign: TextAlign.center, style: TextStyle(color: muted)),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: SmileSpacing.m),
                      Text(_message!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
