import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';

/// Photo or video? Asked by every camera button (album and the quick
/// capture in the top bar) -- a plain choice instead of WhatsApp's
/// hold-to-record, which only works with an own in-app camera (decided
/// 2026-10-08). Then the system camera in that mode. Null = cancelled.
Future<({XFile file, bool isVideo})?> captureWithChoice(BuildContext context) async {
  final t = SmileTexts.of(context);
  final video = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(SmileIcons.camera),
            title: Text(t.takePhoto),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ListTile(
            leading: const Icon(SmileIcons.recordVideo),
            title: Text(t.recordVideo),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
  if (video == null) return null;
  final file = await capture(video: video);
  return file == null ? null : (file: file, isVideo: video);
}

/// The system camera in photo or video mode.
Future<XFile?> capture({required bool video}) => video
    ? ImagePicker().pickVideo(source: ImageSource.camera)
    : ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
