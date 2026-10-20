import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/avatar_upload.dart';

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

/// Follow-up prompt for [AvatarSource.url] (2026-10-20, test suite find 5):
/// the picture is loaded right here, and the dialog closes only once it is
/// there -- a wrong address or one without a picture is said under the
/// field, with the address kept for correcting. Returns the loaded picture,
/// or null if cancelled.
Future<PickedPicture?> showAvatarUrlDialog(BuildContext context) =>
    showDialog<PickedPicture>(context: context, builder: (_) => const _UrlPictureDialog());

class _UrlPictureDialog extends StatefulWidget {
  const _UrlPictureDialog();

  @override
  State<_UrlPictureDialog> createState() => _UrlPictureDialogState();
}

class _UrlPictureDialogState extends State<_UrlPictureDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = _controller.text.trim();
    if (url.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final picture = await fetchPictureFromUrl(url);
      if (mounted) Navigator.of(context).pop(picture);
    } on AvatarUrlException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    return AlertDialog(
      title: Text(t.pictureUrl),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_loading,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'https://…'),
            onSubmitted: (_) => _load(),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(SmileIcons.warning, size: 18, color: scheme.error),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(error, style: TextStyle(color: scheme.error, fontSize: 13.5))),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: Text(t.actionCancel)),
        TextButton(
          onPressed: _loading ? null : _load,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.load),
        ),
      ],
    );
  }
}
