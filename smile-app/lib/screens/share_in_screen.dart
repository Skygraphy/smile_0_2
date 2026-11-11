import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/channel_picker_service.dart';
import '../services/media_service.dart';
import '../services/sync_bus.dart';
import '../services/upload_queue.dart';
import '../services/video_limit.dart';
import '../widgets/album_covers.dart';
import '../widgets/friendly_error.dart';
import '../widgets/local_display.dart';
import 'channel_feed_screen.dart';
import 'send_preview_screen.dart';

/// Shared to Smile from another app (2026-11-09): which album? Then the
/// usual preview with a title per item, into the queue, and the album
/// opens -- the same way as the camera icon (QuickCaptureChannelPickerScreen).
class ShareInScreen extends StatefulWidget {
  ShareInScreen({super.key, required this.files, ChannelPickerService? channelPickerService})
      : channelPickerService = channelPickerService ?? ChannelPickerService();

  final List<XFile> files;
  final ChannelPickerService channelPickerService;

  @override
  State<ShareInScreen> createState() => _ShareInScreenState();
}

class _ShareInScreenState extends State<ShareInScreen> with SyncReload {
  static const _videoExtensions = {'mp4', 'mov', 'm4v', '3gp', '3gpp', 'webm', 'mkv'};

  List<UploadableChannel>? _channels;
  String? _errorMessage;
  bool _sending = false;
  Map<String, ChannelWithActivity> _covers = const {};
  late final List<Future<Uint8List?>> _pictures = [
    for (final f in widget.files) _isVideo(f) ? MediaService.videoPosterBytes(File(f.path)) : f.readAsBytes(),
  ];

  static bool _isVideo(XFile f) => _videoExtensions.contains(f.path.split('.').last.toLowerCase());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() => _load();

  Future<void> _load() async {
    unawaited(loadAlbumCovers(widget.channelPickerService).then((c) {
      if (mounted) setState(() => _covers = c);
    }));
    try {
      final channels = await widget.channelPickerService.listMyUploadableChannels();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _channels ??= const [];
        _errorMessage = SmileTexts.of(context).albumsLoadError(errorReason(context, e));
      });
    }
  }

  Future<void> _sendTo(UploadableChannel channel) async {
    final t = SmileTexts.of(context);
    var files = widget.files;
    // Videos at most as long as allowed (2026-11-05): the longer ones stay here.
    final max = await VideoLimit.forAlbum(channel.channelId);
    final keep = <XFile>[];
    for (final f in files) {
      if (!await VideoLimit.tooLong(f, max)) keep.add(f);
    }
    if (keep.length < files.length) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.videoTooLongTitle),
          content: Text(t.videoTooLongText(max.inMinutes)),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.ok))],
        ),
      );
      files = keep;
      if (files.isEmpty) return;
    }
    if (!mounted) return;
    final captions = await Navigator.of(context).push<List<String?>>(
      MaterialPageRoute(builder: (_) => SendPreviewScreen(files: files, albumName: channel.channelName)),
    );
    if (captions == null || !mounted) return;
    setState(() => _sending = true);
    await UploadQueue.instance.enqueue(channel.channelId, files, captions: captions);
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ChannelFeedScreen(channelId: channel.channelId, channelName: channel.channelName)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final channels = _channels;
    final videos = widget.files.where(_isVideo).length;
    final photos = widget.files.length - videos;
    final count = [if (photos > 0) t.sharedPhotos(photos), if (videos > 0) t.sharedVideos(videos)].join(' · ');
    return Scaffold(
      appBar: AppBar(title: SmileFitText(t.sendTo)),
      body: Column(
        children: [
          // What was shared: a strip of small pictures and how many.
          SizedBox(
            height: 72,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    itemCount: widget.files.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: FutureBuilder<Uint8List?>(
                          future: _pictures[i],
                          builder: (context, snap) => Stack(
                            fit: StackFit.expand,
                            children: [
                              if (snap.data != null)
                                Image.memory(snap.data!, fit: BoxFit.cover, cacheWidth: 168)
                              else
                                ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                              if (_isVideo(widget.files[i])) const Center(child: Icon(SmileIcons.play, size: 22, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(count, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: channels == null
                ? const Center(child: CircularProgressIndicator())
                : channels.isEmpty && _errorMessage == null
                    ? SmileEmptyState(icon: SmileIcons.album, title: t.sendToNoAlbum)
                    : ListView(
                        children: [
                          for (final channel in channels)
                            SmileObjectTile(
                              leading: albumCover(channel.channelId, channel.channelName, _covers),
                              title: albumNameOf(channel.channelId, channel.channelName),
                              subtitleIcon: SmileIcons.space,
                              subtitle: channel.spaceName,
                              onTap: _sending ? null : () => _sendTo(channel),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
