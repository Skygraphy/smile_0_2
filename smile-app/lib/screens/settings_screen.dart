import 'package:flutter/material.dart';

import '../main.dart';
import '../services/avatar_upload.dart';
import '../services/profile_service.dart';
import '../services/push_service.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/smile_avatar.dart';
import 'avatar_viewer_screen.dart';

/// WhatsApp's own Settings screen layout: avatar with a small camera badge
/// overlapping its bottom-right corner, name underneath. Three separate
/// tap targets, each doing one thing (mirrors real WhatsApp exactly,
/// per the user's explicit request):
/// - tapping the avatar photo itself -> full-screen view (AvatarViewerScreen)
/// - tapping the small camera badge -> change the picture (camera/gallery/URL)
/// - tapping the name -> rename
/// Reached from spaces_screen.dart's overflow menu ("Einstellungen"), not
/// shown inline on the main Spaces list -- WhatsApp doesn't show your own
/// profile on its main chat list either.
class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key, ProfileService? profileService}) : profileService = profileService ?? ProfileService();

  final ProfileService profileService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _pushService = PushService();
  SmileProfile? _profile;
  String? _errorMessage;
  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.profileService.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Profil konnte nicht geladen werden: $e');
    }
  }

  void _viewAvatarFullScreen() {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvatarViewerScreen(name: profile.displayName, avatarUrl: profile.avatarUrl),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final source = await showAvatarSourceSheet(context);
    if (source == null) return;
    String? url;
    if (source == AvatarSource.url) {
      if (!mounted) return;
      final enteredUrl = await showAvatarUrlDialog(context);
      if (enteredUrl == null || enteredUrl.trim().isEmpty) return;
      setState(() => _isPickingAvatar = true);
      try {
        url = await widget.profileService.uploadMyAvatarFromUrl(enteredUrl.trim());
      } on AvatarUrlException catch (e) {
        if (mounted) setState(() => _errorMessage = e.message);
      } catch (e) {
        if (mounted) setState(() => _errorMessage = 'Bild konnte nicht hochgeladen werden: $e');
      }
    } else {
      setState(() => _isPickingAvatar = true);
      try {
        url = source == AvatarSource.camera
            ? await widget.profileService.uploadMyAvatarFromCamera()
            : await widget.profileService.uploadMyAvatarFromGallery();
      } catch (e) {
        if (mounted) setState(() => _errorMessage = 'Bild konnte nicht hochgeladen werden: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _isPickingAvatar = false;
      if (url != null && _profile != null) {
        _profile = SmileProfile(userId: _profile!.userId, displayName: _profile!.displayName, avatarUrl: url);
      }
    });
  }

  Future<void> _editName() async {
    final profile = _profile;
    if (profile == null) return;
    final controller = TextEditingController(text: profile.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name ändern'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Speichern')),
        ],
      ),
    );
    final trimmed = newName?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == profile.displayName) return;
    try {
      await widget.profileService.setDisplayName(trimmed);
      if (!mounted) return;
      setState(() => _profile = SmileProfile(userId: profile.userId, displayName: trimmed, avatarUrl: profile.avatarUrl));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Name konnte nicht gespeichert werden: $e');
    }
  }

  /// Moved here from spaces_screen.dart's overflow menu -- a rare,
  /// consequential action belongs at the bottom of Settings, not the
  /// top-level quick menu (still discoverable, unlike WhatsApp which
  /// hides it entirely behind account deletion/re-registration -- Smile's
  /// email/multi-person model doesn't fit that pattern, see the earlier
  /// discussion in this conversation). Deregisters this device's push
  /// token *before* signing out -- once signed out there's no session
  /// left for user_push_tokens' RLS (`user_id = auth.uid()`) to authorize
  /// the delete under, and without this a shared/reused device would
  /// keep getting the previous account's notifications until FCM
  /// eventually reports the token dead on its own.
  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Möchtest du dich wirklich abmelden?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Abmelden')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // This screen is pushed on top of Spaces, not the root itself (unlike
    // where this button used to live) -- pop back to the root route
    // first, so main.dart's AuthGate swapping to LoginScreen underneath
    // is actually what the user sees, instead of being left stranded on
    // this now-defunct Settings screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await _signOut();
  }

  Future<void> _signOut() async {
    final token = await _pushService.getToken();
    if (token != null) {
      try {
        await supabase.from('user_push_tokens').delete().eq('fcm_token', token);
      } catch (_) {
        // Best-effort -- signing out must not get stuck on this.
      }
    }
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: profile == null
          ? Center(
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _load, child: const Text('Erneut versuchen')),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              children: [
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _viewAvatarFullScreen,
                        child: SmileAvatar(name: profile.displayName, avatarUrl: profile.avatarUrl, size: 140),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isPickingAvatar ? null : _changeAvatar,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: _isPickingAvatar
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: _editName,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(profile.displayName, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(width: 8),
                        Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
                const SizedBox(height: 64),
                Center(
                  child: TextButton(
                    onPressed: _confirmSignOut,
                    // Buried by position (bottom of the screen), not by
                    // legibility -- a smaller font here would read as
                    // deliberately obscuring a real action, not just
                    // deprioritizing it. Same size as normal body text.
                    child: Text(
                      'Abmelden',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
