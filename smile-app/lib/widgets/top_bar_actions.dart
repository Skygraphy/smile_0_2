import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../screens/news_screen.dart';
import '../screens/quick_capture_channel_picker_screen.dart';
import '../services/news_service.dart';
import '../services/sync_bus.dart';
import 'capture_choice.dart';

/// Camera + Neuigkeiten: the two actions every tab's top bar carries
/// (navigation decision A, 2026-10-05).
List<Widget> smileTopBarActions({VoidCallback? onPhotoSent}) => [
      QuickCaptureButton(onDone: onPhotoSent),
      NewsButton(),
    ];

/// Take a photo or video right away, then pick the album to send it to.
class QuickCaptureButton extends StatelessWidget {
  const QuickCaptureButton({super.key, this.onDone});

  final VoidCallback? onDone;

  Future<void> _capture(BuildContext context) async {
    final navigator = Navigator.of(context);
    final captured = await captureWithChoice(context);
    if (captured == null) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => QuickCaptureChannelPickerScreen(file: captured.file, isVideo: captured.isVideo),
      ),
    );
    onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(SmileIcons.camera),
      tooltip: SmileTexts.of(context).captureInAlbum,
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
  NewsStatus _status = const NewsStatus(needsAnswer: false, unseenNews: false);

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  Future<void> onSync() => _check();

  Future<void> _check() async {
    try {
      final status = await widget.newsService.status();
      if (!mounted) return;
      if (status.needsAnswer != _status.needsAnswer || status.unseenNews != _status.unseenNews) {
        setState(() => _status = status);
      }
    } catch (_) {
      // Keep the last known state; a failed check must not make the
      // icon flicker or show an error in the top bar.
    }
  }

  Future<void> _open() async {
    final navigator = Navigator.of(context);
    // Opening Neuigkeiten = seen; again on the way out, so what arrived
    // while it was open doesn't bring the dot back.
    setState(() => _status = NewsStatus(needsAnswer: _status.needsAnswer, unseenNews: false));
    await widget.newsService.markSeen().catchError((_) {});
    await navigator.push(MaterialPageRoute(builder: (_) => NewsScreen()));
    await widget.newsService.markSeen().catchError((_) {});
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final coral = Theme.of(context).colorScheme.primary;
    return IconButton(
      // Coral icon = something waits for your answer; coral dot = news in
      // the Verlauf you haven't seen yet (decision 2026-10-06).
      icon: Badge(
        isLabelVisible: _status.unseenNews,
        smallSize: 9,
        backgroundColor: coral,
        child: Icon(SmileIcons.news, color: _status.needsAnswer ? coral : null),
      ),
      tooltip: _status.needsAnswer ? t.newsWaiting : (_status.unseenNews ? t.newsUnseen : t.news),
      onPressed: _open,
    );
  }
}
