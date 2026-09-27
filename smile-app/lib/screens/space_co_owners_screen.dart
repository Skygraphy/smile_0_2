import 'package:flutter/material.dart';

import '../main.dart';
import '../services/space_service.dart';
import '../services/sync_bus.dart';
import '../widgets/email_dialog.dart';
import '../widgets/smile_avatar.dart';

/// "Verwaltung teilen": who else has full SCO-equivalent power over this
/// Space besides its founder (migrations/0037_space_co_owners.sql), plus
/// the founder's own two ways to hand that role off entirely -- transfer
/// it to a co-owner here, or (automatically, not from this screen) have it
/// pass to the longest-standing co-owner if their account is ever deleted.
/// Mirrors WhatsApp's own "admin leaves the group" behavior.
class SpaceCoOwnersScreen extends StatefulWidget {
  SpaceCoOwnersScreen({super.key, required this.spaceId, required this.spaceName, SpaceService? spaceService})
      : spaceService = spaceService ?? SpaceService();

  final String spaceId;
  final String spaceName;
  final SpaceService spaceService;

  @override
  State<SpaceCoOwnersScreen> createState() => _SpaceCoOwnersScreenState();
}

class _SpaceCoOwnersScreenState extends State<SpaceCoOwnersScreen> with SyncReload {
  SpaceCoOwnership? _ownership;
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
      final ownership = await widget.spaceService.listCoOwners(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _ownership = ownership;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Verwaltung konnte nicht geladen werden: $e');
    }
  }

  Future<void> _inviteCoOwner() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => const EmailDialog(
        title: 'Co-Owner einladen',
        explanation:
            'Die Person braucht bereits einen Smile-Account. Sie kann die Einladung annehmen oder ablehnen, bevor sie Verwaltungsrechte über diesen Space bekommt.',
        confirmLabel: 'Einladen',
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await widget.spaceService.inviteCoOwner(spaceId: widget.spaceId, email: email.trim());
      await _load();
    } on SpaceServiceException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Einladen fehlgeschlagen: $e');
    }
  }

  Future<void> _withdrawInvite(PendingCoOwnerInvite invite) async {
    await widget.spaceService.withdrawCoOwnerInvite(invite.id);
    await _load();
  }

  Future<void> _removeCoOwner(SpaceCoOwner coOwner) async {
    final isSelf = coOwner.userId == supabase.auth.currentUser?.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isSelf ? 'Verwaltung verlassen?' : '${coOwner.label} entfernen?'),
        content: Text(
          isSelf
              ? 'Du verlierst deine Verwaltungsrechte über diesen Space.'
              : '${coOwner.label} verliert die Verwaltungsrechte über diesen Space.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isSelf ? 'Verlassen' : 'Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.spaceService.removeCoOwner(spaceId: widget.spaceId, userId: coOwner.userId);
    // Removing yourself means the very next load of this screen would just
    // 403 (space_co_owners_select's RLS no longer includes you) -- same
    // reasoning as channel_members_screen.dart's _leaveChannel: leave the
    // screen instead of reloading it into a permission error.
    if (isSelf) {
      if (mounted) Navigator.of(context).pop();
    } else {
      await _load();
    }
  }

  Future<void> _transferOwnership(SpaceCoOwner coOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${coOwner.label} zum Administrator machen?'),
        content: const Text(
          'Diese Person wird der neue Administrator dieses Space. Du bleibst weiterhin Co-Owner mit vollen Rechten, '
          'verlierst aber die alleinige Kontrolle darüber, wer sonst noch verwaltet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Übertragen')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.spaceService.transferOwnership(spaceId: widget.spaceId, newOwnerUserId: coOwner.userId);
      await _load();
    } on SpaceServiceException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Übertragen fehlgeschlagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownership = _ownership;
    final currentUserId = supabase.auth.currentUser?.id;
    final isCoOwner = ownership?.coOwners.any((c) => c.userId == currentUserId) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('Verwaltung · ${widget.spaceName}')),
      body: ownership == null
          ? Center(child: _errorMessage != null ? Text(_errorMessage!) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  ListTile(
                    leading: SmileAvatar(name: ownership.founderLabel, avatarUrl: ownership.founderAvatarUrl),
                    title: Text(ownership.founderLabel),
                    subtitle: const Text('Administrator'),
                    trailing: ownership.founderUserId == currentUserId ? const Text('Du') : null,
                  ),
                  for (final coOwner in ownership.coOwners)
                    ListTile(
                      leading: SmileAvatar(name: coOwner.label, avatarUrl: coOwner.avatarUrl),
                      title: Text(coOwner.label),
                      subtitle: Text(coOwner.userId == currentUserId ? 'Co-Owner · Du' : 'Co-Owner'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ownership.callerIsFounder)
                            IconButton(
                              icon: const Icon(Icons.swap_horiz),
                              tooltip: 'Zum Administrator machen',
                              onPressed: () => _transferOwnership(coOwner),
                            ),
                          if (ownership.callerIsFounder || coOwner.userId == currentUserId)
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: coOwner.userId == currentUserId ? 'Verlassen' : 'Entfernen',
                              onPressed: () => _removeCoOwner(coOwner),
                            ),
                        ],
                      ),
                    ),
                  if (ownership.callerIsFounder && ownership.pendingInvites.isNotEmpty) ...[
                    const Divider(height: 32),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Ausstehende Einladungen'),
                    ),
                    for (final invite in ownership.pendingInvites)
                      ListTile(
                        leading: SmileAvatar(name: invite.label, avatarUrl: invite.avatarUrl),
                        title: Text(invite.label),
                        subtitle: const Text('Annahme ausstehend'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Zurückziehen',
                          onPressed: () => _withdrawInvite(invite),
                        ),
                      ),
                  ],
                  if (ownership.callerIsFounder) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: _inviteCoOwner,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Co-Owner einladen'),
                      ),
                    ),
                  ],
                  if (!ownership.callerIsFounder && !isCoOwner)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nur der Administrator und Co-Owner können diesen Space verwalten.'),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
