import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;

import '../main.dart';
import '../services/avatar_upload.dart';
import '../services/profile_service.dart';
import '../services/push_service.dart';
import '../services/sync_bus.dart';
import '../widgets/avatar_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../widgets/top_bar_actions.dart';
import 'avatar_viewer_screen.dart';

/// WhatsApp's own Settings screen layout: avatar with a small camera badge
/// overlapping its bottom-right corner, name underneath. Three separate
/// tap targets, each doing one thing (mirrors real WhatsApp exactly,
/// per the user's explicit request):
/// - tapping the avatar photo itself -> full-screen view (AvatarViewerScreen)
/// - tapping the small camera badge -> change the picture (camera/gallery/URL)
/// - tapping the name -> rename (no pencil: the pencil is the Member badge)
/// The third tab of HomeShell ("Profil"); below the header sit the
/// account details and Abmelden.
class SettingsScreen extends StatefulWidget {
  SettingsScreen({super.key, ProfileService? profileService}) : profileService = profileService ?? ProfileService();

  final ProfileService profileService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SyncReload {
  final _pushService = PushService();
  SmileProfile? _profile;
  String? _errorMessage;
  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() => _load();

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
      setState(() => _errorMessage = SmileTexts.of(context).profileLoadError('$e'));
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
        if (mounted) setState(() => _errorMessage = SmileTexts.of(context).avatarUploadError('$e'));
      }
    } else {
      setState(() => _isPickingAvatar = true);
      try {
        url = source == AvatarSource.camera
            ? await widget.profileService.uploadMyAvatarFromCamera()
            : await widget.profileService.uploadMyAvatarFromGallery();
      } catch (e) {
        if (mounted) setState(() => _errorMessage = SmileTexts.of(context).avatarUploadError('$e'));
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
    final t = SmileTexts.of(context);
    final newName =
        await showSmileNameDialog(context, title: t.changeName, confirmLabel: t.save, initialValue: profile.displayName);
    if (newName == null) return;
    try {
      await widget.profileService.setDisplayName(newName);
      if (!mounted) return;
      setState(() => _profile = SmileProfile(userId: profile.userId, displayName: newName, avatarUrl: profile.avatarUrl));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.nameSaveError('$e'));
    }
  }

  /// At the bottom of the Profil tab -- a rare,
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
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.signOut,
      message: t.signOutQuestion,
      confirmLabel: t.signOut,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    // Pop anything pushed on top of the shell first, so main.dart's
    // AuthGate swapping to LoginScreen underneath is what the user sees.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await _signOut();
  }

  /// Everything of this person goes (delete-account). Afterwards the
  /// session is worthless -- sign out locally so AuthGate shows the login.
  Future<void> _confirmDeleteAccount() async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.deleteAccountTitle,
      message: t.deleteAccountMessage,
      confirmLabel: t.deleteAccountConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.profileService.deleteMyAccount();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await supabase.auth.signOut(scope: SignOutScope.local);
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
    final t = SmileTexts.of(context);
    final profile = _profile;
    final scheme = Theme.of(context).colorScheme;
    final email = supabase.auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: Text(t.profile), actions: smileTopBarActions()),
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
                          FilledButton(onPressed: _load, child: Text(t.retry)),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.only(top: SmileSpacing.xl, bottom: SmileSpacing.xl),
              children: [
                Center(
                  child: Stack(
                    children: [
                      Tooltip(
                        message: t.viewPicture,
                        child: GestureDetector(
                          onTap: _viewAvatarFullScreen,
                          child: SmileAvatar(name: profile.displayName, avatarUrl: profile.avatarUrl, size: 128),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Tooltip(
                          message: t.changePicture,
                          child: GestureDetector(
                            onTap: _isPickingAvatar ? null : _changeAvatar,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: scheme.primary,
                              child: _isPickingAvatar
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
                                      ),
                                    )
                                  : Icon(SmileIcons.camera, size: 20, color: scheme.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SmileSpacing.m),
                // Rename = tap the name (decision 5), like Album and Space.
                Center(
                  child: Tooltip(
                    message: t.changeName,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(SmileRadius.s),
                      onTap: _editName,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(
                          profile.displayName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
                  ),
                const SizedBox(height: SmileSpacing.l),
                SmileInfoSection(
                  title: t.account,
                  children: [
                    if (email != null)
                      SmileObjectTile(
                        leading: Icon(SmileIcons.email, color: scheme.onSurfaceVariant),
                        title: email,
                        subtitle: t.emailAddress,
                      ),
                    SmileActionRow(icon: SmileIcons.leave, label: t.signOut, destructive: true, onTap: _confirmSignOut),
                    SmileActionRow(icon: SmileIcons.delete, label: t.deleteAccount, destructive: true, onTap: _confirmDeleteAccount),
                  ],
                ),
              ],
            ),
    );
  }
}
