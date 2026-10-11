import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_design_system/smile_design_system.dart';
import '../widgets/friendly_error.dart';
import '../widgets/album_covers.dart';
import '../widgets/local_display.dart';

import '../services/channel_picker_service.dart';
import '../services/media_service.dart';
import '../services/upload_queue.dart';
import '../services/sync_bus.dart';
import 'channel_feed_screen.dart';

/// The step after the header camera icon (spaces_screen.dart) captures a
/// photo or video -- mirrors WhatsApp's own "camera icon -> pick who to send it to"
/// flow. Uploads straight from here (no separate confirm/caption step, to
/// keep this a true one-tap "quick share") and lands on that channel's
/// feed so the sender sees their own photo land, same as WhatsApp opening
/// the chat after sending.
class QuickCaptureChannelPickerScreen extends StatefulWidget {
  QuickCaptureChannelPickerScreen({
    super.key,
    required this.file,
    required this.isVideo,
    ChannelPickerService? channelPickerService,
    MediaService? mediaService,
  })  : channelPickerService = channelPickerService ?? ChannelPickerService(),
        mediaService = mediaService ?? MediaService();

  final XFile file;
  final bool isVideo;
  final ChannelPickerService channelPickerService;
  final MediaService mediaService;

  @override
  State<QuickCaptureChannelPickerScreen> createState() => _QuickCaptureChannelPickerScreenState();
}

class _QuickCaptureChannelPickerScreenState extends State<QuickCaptureChannelPickerScreen> with SyncReload {
  List<UploadableChannel>? _channels;
  String? _errorMessage;
  UploadableChannel? _uploadingTo;
  Map<String, ChannelWithActivity> _covers = const {};
  /// The photo itself, or a frame taken from the video.
  Uint8List? _preview;

  @override
  void initState() {
    super.initState();
    _load();
    (widget.isVideo ? MediaService.videoPosterBytes(File(widget.file.path)) : widget.file.readAsBytes()).then((bytes) {
      if (mounted) setState(() => _preview = bytes);
    });
  }

  @override
  Future<void> onSync() => _load();

  Future<void> _load() async {
    loadAlbumCovers(widget.channelPickerService).then((c) {
      if (mounted) setState(() => _covers = c);
    });
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

  /// Into the album at once, like WhatsApp (2026-10-11): the upload
  /// queue sends it -- right away, or with a clock once there is a
  /// connection again, even with Smile closed.
  Future<void> _sendTo(UploadableChannel channel) async {
    // A short tick when it's sent, like WhatsApp (2026-10-10).
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _uploadingTo = channel;
      _errorMessage = null;
    });
    await UploadQueue.instance.enqueue(channel.channelId, [widget.file]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChannelFeedScreen(channelId: channel.channelId, channelName: channel.channelName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    return Scaffold(
      appBar: AppBar(title: Text(SmileTexts.of(context).sendTo)),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _preview == null
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_preview!, fit: BoxFit.cover, width: double.infinity),
                          if (widget.isVideo)
                            const Center(child: Icon(SmileIcons.play, size: 56, color: Colors.white70)),
                        ],
                      ),
              ),
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
                : channels.isEmpty
                    ? SmileEmptyState(icon: SmileIcons.album, title: SmileTexts.of(context).sendToNoAlbum)
                    : ListView(
                        children: [
                          for (final channel in channels)
                            SmileObjectTile(
                              leading: albumCover(channel.channelId, channel.channelName, _covers),
                              title: albumNameOf(channel.channelId, channel.channelName),
                              subtitleIcon: SmileIcons.space,
                              subtitle: channel.spaceName,
                              trailing: _uploadingTo == channel
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : null,
                              onTap: _uploadingTo != null ? null : () => _sendTo(channel),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
