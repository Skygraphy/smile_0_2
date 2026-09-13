import 'package:flutter/material.dart';

enum AvatarSource { camera, gallery, url }

/// Bottom sheet offering the three ways to set an avatar -- shared by the
/// user (profile_setup_screen.dart) and group (group_detail_screen.dart)
/// avatar pickers so the choice always looks and behaves the same.
Future<AvatarSource?> showAvatarSourceSheet(BuildContext context) {
  return showModalBottomSheet<AvatarSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Foto aufnehmen'),
            onTap: () => Navigator.of(context).pop(AvatarSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Vorhandenes Bild wählen'),
            onTap: () => Navigator.of(context).pop(AvatarSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Von einer Internetadresse laden'),
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
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bild-URL'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'https://…'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Laden')),
      ],
    ),
  );
}
