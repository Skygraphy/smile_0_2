import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../widgets/avatar_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../widgets/friendly_error.dart';

/// The mandatory first-login onboarding step -- main.dart's profile gate
/// shows this whenever profiles.display_name doesn't exist yet for the
/// current user. Only the name is actually enforced; the avatar is
/// optional since SmileAvatar always has a generated-initials fallback
/// (see project_ui-redesign-concepts: "Jeder User... benötigt zumindest
/// einen Namen und ein Profilbild" was resolved as "a real photo is
/// optional, a placeholder avatar is always shown" rather than a hard
/// upload requirement). Later edits go through SettingsScreen instead,
/// which has its own WhatsApp-style avatar/name interactions.
class ProfileSetupScreen extends StatefulWidget {
  ProfileSetupScreen({super.key, required this.onDone, ProfileService? profileService})
      : profileService = profileService ?? ProfileService();

  final VoidCallback onDone;
  final ProfileService profileService;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _avatarUrl;
  bool _isSaving = false;
  bool _isPickingAvatar = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Typing again clears the message (2026-10-20, test suite find 6).
    _nameController.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showAvatarSourceSheet(context);
    if (source == null) return;
    String? url;
    if (source == AvatarSource.url) {
      if (!mounted) return;
      final picture = await showAvatarUrlDialog(context);
      if (picture == null) return;
      setState(() => _isPickingAvatar = true);
      try {
        url = await widget.profileService.uploadMyAvatarPicked(picture);
      } catch (e) {
        if (mounted) setState(() => _errorMessage = 'Bild konnte nicht hochgeladen werden: ${errorReason(context, e)}');
      }
    } else {
      setState(() => _isPickingAvatar = true);
      try {
        url = source == AvatarSource.camera
            ? await widget.profileService.uploadMyAvatarFromCamera()
            : await widget.profileService.uploadMyAvatarFromGallery();
      } catch (e) {
        if (mounted) setState(() => _errorMessage = 'Bild konnte nicht hochgeladen werden: ${errorReason(context, e)}');
      }
    }
    if (!mounted) return;
    setState(() {
      _isPickingAvatar = false;
      if (url != null) _avatarUrl = url;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Bitte gib deinen Namen ein.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.profileService.setDisplayName(name, withAvatar: _avatarUrl != null);
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Speichern fehlgeschlagen: ${errorReason(context, e)}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: SmileWordmark(fontSize: 24)),
                          const SizedBox(height: 24),
                          Text(
                            SmileTexts.of(context).profileSetupQuestion,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: _isPickingAvatar ? null : _pickAvatar,
                              child: Stack(
                                children: [
                                  AnimatedBuilder(
                                    animation: _nameController,
                                    builder: (context, _) => SmileAvatar(
                                      name: _nameController.text,
                                      avatarUrl: _avatarUrl,
                                      size: 96,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      child: _isPickingAvatar
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                              ),
                                            )
                                          : Icon(
                                              SmileIcons.camera,
                                              size: 16,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _nameController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(labelText: SmileTexts.of(context).name),
                            onSubmitted: (_) => _save(),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(SmileIcons.warning, size: 18, color: Theme.of(context).colorScheme.error),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(SmileTexts.of(context).next),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
