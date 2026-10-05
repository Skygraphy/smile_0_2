import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../screens/my_invites_screen.dart';
import '../screens/quick_capture_channel_picker_screen.dart';
import '../services/news_service.dart';
import '../services/sync_bus.dart';

/// Camera + Neuigkeiten: the two actions every tab's top bar carries
/// (navigation decision A, 2026-10-05).
List<Widget> smileTopBarActions({VoidCallback? onPhotoSent}) => [
      QuickCaptureButton(onDone: onPhotoSent),
      NewsButton(),
    ];

/// Take a photo right away, then pick the album to send it to.
class QuickCaptureButton extends StatelessWidget {
  const QuickCaptureButton({super.key, this.onDone});

  final VoidCallback? onDone;

  Future<void> _capture(BuildContext context) async {
    final navigator = Navigator.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension = picked.path.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => QuickCaptureChannelPickerScreen(bytes: bytes, fileExtension: extension, mimeType: mimeType),
      ),
    );
    onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(SmileIcons.camera),
      tooltip: SmileTexts.of(context).actionSendPhoto,
      onPressed: () => _capture(context),
    );
  }
}

/// The Neuigkeiten icon. No counter (user's decision): neutral while
/// nothing waits, tinted coral as soon as an invite waits for the
/// caller's decision. Re-checks on every sync event, so an invite
/// arriving via push lights it up without any user action.
class NewsButton extends StatefulWidget {
  NewsButton({super.key, NewsService? newsService}) : newsService = newsService ?? NewsService();

  final NewsService newsService;

  @override
  State<NewsButton> createState() => _NewsButtonState();
}

class _NewsButtonState extends State<NewsButton> with SyncReload {
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  Future<void> onSync() => _check();

  Future<void> _check() async {
    try {
      final pending = await widget.newsService.hasPendingForMe();
      if (mounted && pending != _pending) setState(() => _pending = pending);
    } catch (_) {
      // Keep the last known state; a failed check must not make the
      // icon flicker or show an error in the top bar.
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyInvitesScreen()));
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return IconButton(
      icon: Icon(SmileIcons.news, color: _pending ? Theme.of(context).colorScheme.primary : null),
      tooltip: _pending ? t.newsWaiting : t.news,
      onPressed: _open,
    );
  }
}
