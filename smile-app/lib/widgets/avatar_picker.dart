import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

enum AvatarSource { camera, gallery, url }

/// Bottom sheet offering the three ways to set an avatar -- shared by the
/// first-start profile setup (profile_setup_screen.dart) and the Profil tab
/// (settings_screen.dart) so the choice always looks and behaves the same.
Future<AvatarSource?> showAvatarSourceSheet(BuildContext context) {
  final t = SmileTexts.of(context);
  return showModalBottomSheet<AvatarSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(SmileIcons.camera),
            title: Text(t.takePhoto),
            onTap: () => Navigator.of(context).pop(AvatarSource.camera),
          ),
          ListTile(
            leading: const Icon(SmileIcons.picture),
            title: Text(t.choosePicture),
            onTap: () => Navigator.of(context).pop(AvatarSource.gallery),
          ),
          ListTile(
            leading: const Icon(SmileIcons.web),
            title: Text(t.pictureFromWeb),
            onTap: () => Navigator.of(context).pop(AvatarSource.url),
          ),
        ],
      ),
    ),
  );
}

/// Follow-up prompt for [AvatarSource.url] -- returns the entered URL, or
/// null if cancelled/left empty.
Future<String?> showAvatarUrlDialog(BuildContext context) {
  final t = SmileTexts.of(context);
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.pictureUrl),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'https://…'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.actionCancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text(t.load)),
      ],
    ),
  );
}
