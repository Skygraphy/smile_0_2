import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import '../services/feedback_service.dart';
import '../services/frame_service.dart';
import '../services/screen_report.dart';
import '../services/test_media.dart';

/// "Hilfe & Feedback" (2026-11-20): a problem, an idea or a question for
/// the operator, with up to 3 pictures and optionally one of the Frames.
/// What goes along is shown openly before sending.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.initialImages = const [], this.screen});

  /// From "Screenshot melden" or shared from the gallery (2026-11-21).
  final List<Uint8List> initialImages;

  /// Where the screenshot was taken (goes along to the Verwaltung).
  final String? screen;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _maxImages = 3;

  final _text = TextEditingController();
  FeedbackKind _kind = FeedbackKind.problem;
  final _images = <Uint8List>[];
  List<ManagedFrame> _frames = const [];
  String? _frameId;
  Map<String, String> _device = const {};
  bool _sending = false;
  // null = writing; true = arrived; false = waits for the internet.
  bool? _sent;
  // The app's last errors go along (named in the info box, not shown).
  bool _hasErrors = false;

  @override
  void initState() {
    super.initState();
    _images.addAll(widget.initialImages.take(_maxImages));
    _hasErrors = ErrorTrail.recent().isNotEmpty;
    _text.addListener(() => setState(() {}));
    unawaited(_load());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final device = await FeedbackService.instance.deviceInfo();
    List<ManagedFrame> frames = const [];
    try {
      frames = await FrameService().listMyFrames();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _device = device;
      _frames = frames;
    });
  }

  Future<void> _addImage() async {
    final List<XFile> picked;
    if (smileTestMode) {
      picked = await pickTestMedia(multiple: false, videos: false);
    } else {
      final one = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1600, maxHeight: 1600);
      picked = one == null ? const [] : [one];
    }
    if (picked.isEmpty) return;
    final bytes = await picked.first.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (_images.length < _maxImages) _images.add(bytes);
    });
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final arrived = await FeedbackService.instance.send(
      kind: _kind,
      message: _text.text.trim(),
      frameId: _frameId,
      images: List.of(_images),
      screen: widget.screen,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = arrived;
    });
  }

  String _deviceLine(SmileTexts t) {
    final parts = [
      if (_device['app_version'] != null) 'Smile ${_device['app_version']!.split('+').first}',
      if (_device['device'] != null) _device['device']!,
      if (_device['os'] != null) _device['os']!,
      if (_device['language'] != null) _device['language']!.toUpperCase(),
    ];
    var line = parts.join(' · ');
    if (_frames.isNotEmpty) line += ' · ${t.feedbackFrameAlong}';
    if (widget.screen != null) line += ' · ${t.feedbackScreenAlong}';
    if (_hasErrors) line += ' · ${t.feedbackErrorsAlong}';
    return line;
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.helpFeedback)),
      body: SafeArea(child: _sent != null ? _thanks(t) : _form(t)),
    );
  }

  Widget _thanks(SmileTexts t) {
    final scheme = Theme.of(context).colorScheme;
    final arrived = _sent == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.xl * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (arrived ? SmileTheme.success : scheme.primary).withValues(alpha: 0.15),
              ),
              child: Icon(arrived ? SmileIcons.check : SmileIcons.waiting, size: 40, color: arrived ? SmileTheme.success : scheme.primary),
            ),
            const SizedBox(height: SmileSpacing.l),
            Text(arrived ? t.feedbackThanksTitle : t.feedbackQueuedTitle,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: SmileSpacing.s),
            Text(arrived ? t.feedbackThanksText : t.feedbackQueuedText,
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
            const SizedBox(height: SmileSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.done),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(SmileTexts t) {
    final scheme = Theme.of(context).colorScheme;
    final email = supabase.auth.currentUser?.email;
    final label = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    return ListView(
      padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.s, SmileSpacing.l, SmileSpacing.xl),
      children: [
        Wrap(
          spacing: SmileSpacing.s,
          runSpacing: SmileSpacing.s,
          children: [
            for (final (kind, text) in [
              (FeedbackKind.problem, t.feedbackKindProblem),
              (FeedbackKind.idea, t.feedbackKindIdea),
              (FeedbackKind.question, t.feedbackKindQuestion),
            ])
              ChoiceChip(
                label: Text(text),
                selected: _kind == kind,
                showCheckmark: false,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: SmileSpacing.m),
        TextField(
          controller: _text,
          minLines: 5,
          maxLines: 12,
          maxLength: 5000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: t.feedbackMessageHint,
            counterText: '',
            filled: true,
            fillColor: scheme.surfaceContainer,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(SmileRadius.m), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: SmileSpacing.l),
        Text(t.feedbackImages, style: label),
        const SizedBox(height: SmileSpacing.s),
        Wrap(
          spacing: SmileSpacing.s,
          runSpacing: SmileSpacing.s,
          children: [
            for (var i = 0; i < _images.length; i++)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(SmileRadius.s),
                    child: ColoredBox(color: Colors.black, child: Image.memory(_images[i], width: 72, height: 96, fit: BoxFit.contain)),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _images.removeAt(i)),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surfaceContainerHighest),
                        child: Icon(SmileIcons.close, size: 14, color: scheme.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            if (_images.length < _maxImages)
              InkWell(
                borderRadius: BorderRadius.circular(SmileRadius.s),
                onTap: _addImage,
                child: Container(
                  width: 72,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SmileRadius.s),
                    border: Border.all(color: scheme.outline, width: 1.2),
                  ),
                  child: Icon(SmileIcons.add, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        if (_frames.isNotEmpty) ...[
          const SizedBox(height: SmileSpacing.l),
          Text(t.feedbackFrame, style: label),
          const SizedBox(height: SmileSpacing.s),
          DropdownButtonFormField<String?>(
            initialValue: _frameId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: scheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(horizontal: SmileSpacing.m, vertical: SmileSpacing.m),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(SmileRadius.m), borderSide: BorderSide.none),
            ),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(t.feedbackFrameNone)),
              for (final f in _frames) DropdownMenuItem<String?>(value: f.frame.id, child: Text(f.frame.name)),
            ],
            onChanged: (v) => setState(() => _frameId = v),
          ),
        ],
        const SizedBox(height: SmileSpacing.l),
        Container(
          padding: const EdgeInsets.all(SmileSpacing.m),
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(SmileRadius.m)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.feedbackSentAlong(_deviceLine(t)), style: label.copyWith(height: 1.45)),
              if (email != null) ...[
                const SizedBox(height: SmileSpacing.xs),
                Text(t.feedbackReplyTo(email), style: label.copyWith(height: 1.45)),
              ],
            ],
          ),
        ),
        const SizedBox(height: SmileSpacing.l),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
          child: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.feedbackSend),
        ),
      ],
    );
  }
}
