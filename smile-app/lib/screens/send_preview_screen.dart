import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/media_service.dart';
import '../services/tips.dart';

/// Before sending picked photos/videos (2026-10-17), like WhatsApp: a
/// preview with an optional title per item ("Titel hinzufügen ..."); with
/// several, a strip below to switch between them. Pops with one title per
/// file (null where none), or nothing when cancelled.
class SendPreviewScreen extends StatefulWidget {
  const SendPreviewScreen({super.key, required this.files, required this.albumName});

  final List<XFile> files;
  final String albumName;

  @override
  State<SendPreviewScreen> createState() => _SendPreviewScreenState();
}

class _SendPreviewScreenState extends State<SendPreviewScreen> {
  static const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'};

  late final List<TextEditingController> _captions =
      List.generate(widget.files.length, (_) => TextEditingController());
  late final List<Future<Uint8List?>> _pictures = [for (final f in widget.files) _pictureOf(f)];
  final _pages = PageController();
  int _index = 0;
  final _captionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Tips.offer(context, TipId.captionWhenSending, anchor: _captionKey);
    });
  }

  bool _isVideo(XFile f) => _videoExtensions.contains(f.path.split('.').last.toLowerCase());

  Future<Uint8List?> _pictureOf(XFile f) async =>
      _isVideo(f) ? MediaService.videoPosterBytes(File(f.path)) : f.readAsBytes();

  @override
  void dispose() {
    for (final c in _captions) {
      c.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  void _send() {
    if (_captions.any((c) => c.text.trim().isNotEmpty)) Tips.markUsed(TipId.captionWhenSending);
    Navigator.of(context).pop<List<String?>>([
      for (final c in _captions) c.text.trim().isEmpty ? null : c.text.trim(),
    ]);
  }

  Widget _picture(int i, {BoxFit fit = BoxFit.contain}) => FutureBuilder<Uint8List?>(
        future: _pictures[i],
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return const Center(child: CircularProgressIndicator());
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: fit, gaplessPlayback: true),
              if (_isVideo(widget.files[i]))
                Center(
                  child: Icon(SmileIcons.playFilled, size: fit == BoxFit.contain ? 56 : 18, color: Colors.white70),
                ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final many = widget.files.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(SmileIcons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(widget.albumName),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.files.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _picture(i),
            ),
          ),
          if (many)
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: widget.files.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: i == _index ? scheme.primary : Colors.transparent, width: 2),
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(6), child: _picture(i, fit: BoxFit.cover)),
                  ),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    key: _captionKey,
                    child: TextField(
                      // One field per item: its own text when switching.
                      key: ValueKey(_index),
                      controller: _captions[_index],
                      maxLength: 200,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: t.captionHint,
                        counterText: '',
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    heroTag: null,
                    tooltip: t.captureSend,
                    onPressed: _send,
                    child: const Icon(SmileIcons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
