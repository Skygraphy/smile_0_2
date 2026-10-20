import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;

import '../main.dart';
import '../services/avatar_upload.dart';
import '../services/local_changes.dart';
import '../widgets/local_display.dart';
import '../services/profile_service.dart';
import '../services/push_service.dart';
import '../services/sync_bus.dart';
import '../widgets/avatar_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../widgets/friendly_error.dart';
import '../services/video_quality.dart';
import '../services/upload_queue.dart';
import 'avatar_viewer_screen.dart';
import 'handle_edit_screen.dart';
import '../services/tips.dart';
import 'my_card_screen.dart';
import '../services/frame_service.dart';
import '../services/preferred_frame.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    // The stored "Videos senden" choice.
    unawaited(VideoQuality.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Tips.offerFirst(context, [(TipId.smileName, null), (TipId.videoQuality, null)]);
    });
  }

  @override
  Future<void> onSync() => _load();

  /// The caller's Frames and the preferred one (2026-10-18).
  List<ManagedFrame> _frames = const [];
  String? _preferredFrameId;

  Future<void> _loadFrames() async {
    try {
      final frames = await FrameService().listMyFrames();
      final preferred = await PreferredFrame.get();
      if (mounted) {
        setState(() {
          _frames = frames;
          _preferredFrameId = preferred;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickPreferredFrame() async {
    final t = SmileTexts.of(context);
    // '' = ask each time.
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(t.preferredFrame),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.of(context).pop(''), child: Text(t.preferredFrameAsk)),
          for (final f in _frames)
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(f.frame.id), child: Text(f.frame.name)),
        ],
      ),
    );
    if (picked == null) return;
    await PreferredFrame.set(picked.isEmpty ? null : picked);
    if (mounted) setState(() => _preferredFrameId = picked.isEmpty ? null : picked);
  }

  Future<void> _load() async {
    unawaited(_loadFrames());
    try {
      final profile = await widget.profileService.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _errorMessage = null;
      });
      // A Smile name already: its tip is not needed.
      if (profile?.handle != null) unawaited(Tips.markUsed(TipId.smileName));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = SmileTexts.of(context).profileLoadError(errorReason(context, e)));
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

  /// The new picture shows at once while it uploads (LocalChanges,
  /// 2026-10-09); a failure takes it back with a message.
  Future<void> _changeAvatar() async {
    final source = await showAvatarSourceSheet(context);
    if (source == null || !mounted) return;
    final LocalPicture shown;
    final Future<void> Function() commit;
    if (source == AvatarSource.url) {
      final picture = await showAvatarUrlDialog(context);
      if (picture == null) return;
      shown = LocalPicture.bytes(picture.bytes);
      commit = () => widget.profileService.uploadMyAvatarPicked(picture);
    } else {
      final picked = await pickPictureBytes(source == AvatarSource.camera ? ImageSource.camera : ImageSource.gallery);
      if (picked == null) return;
      shown = LocalPicture.bytes(picked.bytes);
      commit = () => widget.profileService.uploadMyAvatarPicked(picked);
    }
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.profileAvatar: shown},
      commit: commit,
      // A new picture has a new address (migrations/0086): no old copy to
      // drop, just load the new one before the local one goes.
      warmUp: () async {
        final url = (await widget.profileService.getMyProfile())?.avatarUrl;
        if (url != null) await precacheUrl(url);
      },
      affects: tablesChanged({'profiles'}),
    );
    if (saved && mounted) await _load();
  }

  Future<void> _editName() async {
    final profile = _profile;
    if (profile == null) return;
    final t = SmileTexts.of(context);
    final newName =
        await showSmileNameDialog(context, title: t.changeName, confirmLabel: t.save, initialValue: profile.displayName);
    if (newName == null) return;
    final saved = await LocalChanges.instance.run(
      overrides: {LocalChanges.profileName: newName},
      commit: () => widget.profileService.setDisplayName(newName),
      affects: tablesChanged({'profiles'}),
      failureText: t.nameSaveError(''),
    );
    if (!saved || !mounted) return;
    setState(() => _profile =
        SmileProfile(userId: profile.userId, displayName: newName, avatarUrl: profile.avatarUrl, handle: profile.handle));
  }

  /// "Smile-Namen wählen" (2026-10-17).
  Future<void> _editHandle() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => HandleEditScreen(current: profile.handle, displayName: profile.displayName)),
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _openCard() async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyCardScreen(profile: profile)));
    if (mounted) await _load();
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
    final email = supabase.auth.currentUser?.email ?? '';
    // Walkthrough 2026-10-06: an account was deleted on the wrong login
    // (a shared test device). The dialog now names the account and only
    // confirms once its e-mail address is typed in.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteAccountDialog(
        name: _profile?.displayName ?? email,
        email: email,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.profileService.deleteMyAccount();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed(errorReason(context, e)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await UploadQueue.instance.clear();
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
    // Whatever still waits to be sent belongs to this account.
    await UploadQueue.instance.clear();
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final profile = _profile;
    final scheme = Theme.of(context).colorScheme;
    final email = supabase.auth.currentUser?.email;
    return Scaffold(
      // A page of its own from the ⋮ menu (2026-10-13), with its back arrow.
      appBar: AppBar(title: Text(t.settings)),
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
              padding: EdgeInsets.only(top: SmileSpacing.xl, bottom: SmileSpacing.xl + MediaQuery.paddingOf(context).bottom),
              children: [
                Center(
                  child: Stack(
                    children: [
                      Tooltip(
                        message: t.viewPicture,
                        child: GestureDetector(
                          onTap: _viewAvatarFullScreen,
                          child: myAvatar(name: myNameOf(profile.displayName), serverUrl: profile.avatarUrl, size: 128),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Tooltip(
                          message: t.changePicture,
                          child: GestureDetector(
                            onTap: _changeAvatar,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: scheme.primary,
                              // No waiting spinner: the new picture shows at once.
                              child: Icon(SmileIcons.camera, size: 20, color: scheme.onPrimary),
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
                          myNameOf(profile.displayName),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                if (profile.handle != null)
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(SmileRadius.s),
                      onTap: _editHandle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Text('@${profile.handle}',
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
                  ),
                const SizedBox(height: SmileSpacing.l),
                // Smile name and the own card (2026-10-17): found and
                // invited without an email address.
                SmileInfoSection(
                  title: t.smileName,
                  children: [
                    SmileObjectTile(
                      leading: Icon(SmileIcons.handle, color: scheme.onSurfaceVariant),
                      title: profile.handle != null ? '@${profile.handle}' : t.smileNameChoose,
                      subtitle: profile.handle != null ? t.smileName : null,
                      onTap: _editHandle,
                    ),
                    SmileObjectTile(
                      leading: Icon(SmileIcons.card, color: scheme.onSurfaceVariant),
                      title: t.myCard,
                      onTap: _openCard,
                    ),
                  ],
                ),
                // The Frame an album goes to with one tap (2026-10-18).
                if (_frames.isNotEmpty)
                  SmileInfoSection(
                    title: t.preferredFrame,
                    children: [
                      SmileObjectTile(
                        leading: Icon(SmileIcons.frame, color: scheme.onSurfaceVariant),
                        title: _frames.where((f) => f.frame.id == _preferredFrameId).firstOrNull?.frame.name ??
                            t.preferredFrameAsk,
                        subtitle: t.preferredFrameHint,
                        subtitleMaxLines: 2,
                        onTap: _pickPreferredFrame,
                      ),
                    ],
                  ),
                // "Videos senden" (2026-10-12): how much videos are shrunk.
                SmileInfoSection(
                  title: t.sendVideos,
                  children: [
                    ValueListenableBuilder<VideoQuality>(
                      valueListenable: VideoQuality.current,
                      builder: (context, quality, _) => Padding(
                        padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<VideoQuality>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(value: VideoQuality.high, label: Text(t.qualityHigh)),
                                ButtonSegment(value: VideoQuality.medium, label: Text(t.qualityMedium)),
                                ButtonSegment(value: VideoQuality.low, label: Text(t.qualityLow)),
                              ],
                              selected: {quality},
                              onSelectionChanged: (chosen) => VideoQuality.choose(chosen.first),
                            ),
                            const SizedBox(height: SmileSpacing.s),
                            Text(
                              switch (quality) {
                                VideoQuality.high => t.qualityHighHint,
                                VideoQuality.medium => t.qualityMediumHint,
                                VideoQuality.low => t.qualityLowHint,
                              },
                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Tipps (2026-10-18): on by default, all back from the start.
                SmileInfoSection(
                  title: t.tipsSection,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: Tips.enabled,
                      builder: (context, on, _) => SwitchListTile(
                        secondary: Icon(SmileIcons.lightbulb, color: scheme.onSurfaceVariant),
                        title: Text(t.tipsShow),
                        subtitle: Text(t.tipsShowHint),
                        value: on,
                        onChanged: (v) => Tips.setEnabled(v),
                      ),
                    ),
                    SmileObjectTile(
                      leading: Icon(SmileIcons.restore, color: scheme.onSurfaceVariant),
                      title: t.tipsReset,
                      subtitle: t.tipsResetHint,
                      subtitleMaxLines: 2,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final done = t.tipsResetDone;
                        await Tips.reset();
                        messenger.showSnackBar(SnackBar(content: Text(done)));
                      },
                    ),
                  ],
                ),
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

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.name, required this.email});

  final String name;
  final String email;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      widget.email.isNotEmpty && _controller.text.trim().toLowerCase() == widget.email.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(t.deleteAccountTitleNamed(widget.name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.deleteAccountWhich(widget.email), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: SmileSpacing.m),
            Text(t.deleteAccountMessage),
            const SizedBox(height: SmileSpacing.l),
            Text(t.deleteAccountTypeEmail),
            const SizedBox(height: SmileSpacing.s),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(hintText: widget.email),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.actionCancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(t.deleteAccountConfirm),
        ),
      ],
    );
  }
}
