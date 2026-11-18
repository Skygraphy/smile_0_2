import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_service.dart';

/// "Was sieht Oma gerade?" (2026-11-18, migrations/0107): the Frame's
/// screen, a new picture every few seconds. Only the Space's Admin and
/// Co-Admins; the Frame shows who is looking; ends by itself after 5
/// minutes. Closing the screen ends it at once.
class FrameLiveScreen extends StatefulWidget {
  const FrameLiveScreen({super.key, required this.frameId, required this.frameName});

  final String frameId;
  final String frameName;

  @override
  State<FrameLiveScreen> createState() => _FrameLiveScreenState();
}

class _FrameLiveScreenState extends State<FrameLiveScreen> {
  final _service = FrameService();
  Timer? _poll;
  Timer? _clock;
  bool _busy = false;

  /// The latest picture (kept while the next one loads, no flicker).
  Uint8List? _image;
  String? _imageAt;
  DateTime? _capturedAt;
  Map<String, dynamic>? _state;
  DateTime? _lastSeen;
  bool _ended = false;
  String? _busyWith;

  @override
  void initState() {
    super.initState();
    _start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _start() async {
    setState(() {
      _ended = false;
      _busyWith = null;
      _image = null;
      _capturedAt = null;
      _state = null;
    });
    try {
      final r = await _service.live(widget.frameId, 'start');
      if (!mounted) return;
      if (r['error'] == 'busy') {
        setState(() => _busyWith = r['watcher'] as String? ?? '');
        return;
      }
    } catch (_) {
      // The polling below shows "not answering" if it stays like that.
    }
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _get());
    unawaited(_get());
  }

  Future<void> _get() async {
    if (_busy || _ended) return;
    _busy = true;
    try {
      final r = await _service.live(widget.frameId, 'get', since: _imageAt);
      if (!mounted) return;
      if (r['ended'] == true) {
        _poll?.cancel();
        setState(() => _ended = true);
        return;
      }
      final at = r['captured_at'] as String?;
      final image = r['image'] as String?;
      if (image != null && at != null) {
        _image = base64Decode(image);
        _imageAt = at;
      }
      if (!mounted) return;
      setState(() {
        _capturedAt = at == null ? null : DateTime.tryParse(at)?.toLocal();
        _state = (r['state'] as Map?)?.cast<String, dynamic>();
        _lastSeen = DateTime.tryParse(r['last_seen_at'] as String? ?? '')?.toLocal();
      });
    } catch (_) {
      // Next round; the age below grows and says so.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    if (!_ended) unawaited(_service.live(widget.frameId, 'stop').catchError((Object _) => const <String, dynamic>{}));
    super.dispose();
  }

  String _status(SmileTexts t) {
    final s = _state;
    if (s == null) return t.liveWaiting;
    final album = s['album'] as String?;
    final sender = s['sender'] as String?;
    switch (s['state']) {
      case 'paused':
        return t.liveStatePaused;
      case 'quiet':
        return t.liveStateQuiet;
      case 'overview':
        return t.liveStateOverview;
    }
    if (album == null) return '';
    return sender == null || sender.isEmpty ? t.liveStatePlaying(album) : t.liveStatePlayingFrom(album, sender);
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final captured = _capturedAt;
    final age = captured == null ? null : DateTime.now().difference(captured).inSeconds.clamp(0, 9999);
    // No picture for a while: the Frame is off, asleep or offline.
    final silent = !_ended && _busyWith == null && (age == null ? false : age > 20);
    final waitingTooLong = captured == null && _poll != null && _lastSeen != null && DateTime.now().difference(_lastSeen!) > const Duration(minutes: 5);

    return Scaffold(
      appBar: AppBar(title: SmileFitText(t.liveTitle(widget.frameName))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_image != null)
                      Image.memory(_image!, fit: BoxFit.contain, gaplessPlayback: true)
                    else if (!_ended && _busyWith == null)
                      const Center(child: CircularProgressIndicator()),
                    if (age != null && !_ended)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: silent ? Colors.grey : Colors.redAccent, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(t.liveAge(age), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
            child: Text(
              _busyWith != null
                  ? t.liveBusy(_busyWith!)
                  : _ended
                      ? t.liveEnded
                      : silent || waitingTooLong
                          ? t.liveOffline
                          : _status(t),
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          if (_ended || _busyWith != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: _start, child: Text(t.liveAgain)),
          ],
          const SizedBox(height: 16),
          Text(t.liveHint, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
