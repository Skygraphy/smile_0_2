import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/channel_picker_service.dart';
import '../services/media_service.dart';
import 'channel_feed_screen.dart';

/// The step after the header camera icon (spaces_screen.dart) captures a
/// photo -- mirrors WhatsApp's own "camera icon -> pick who to send it to"
/// flow. Uploads straight from here (no separate confirm/caption step, to
/// keep this a true one-tap "quick share") and lands on that channel's
/// feed so the sender sees their own photo land, same as WhatsApp opening
/// the chat after sending.
class QuickCaptureChannelPickerScreen extends StatefulWidget {
  QuickCaptureChannelPickerScreen({
    super.key,
    required this.bytes,
    required this.fileExtension,
    required this.mimeType,
    ChannelPickerService? channelPickerService,
    MediaService? mediaService,
  })  : channelPickerService = channelPickerService ?? ChannelPickerService(),
        mediaService = mediaService ?? MediaService();

  final Uint8List bytes;
  final String fileExtension;
  final String mimeType;
  final ChannelPickerService channelPickerService;
  final MediaService mediaService;

  @override
  State<QuickCaptureChannelPickerScreen> createState() => _QuickCaptureChannelPickerScreenState();
}

class _QuickCaptureChannelPickerScreenState extends State<QuickCaptureChannelPickerScreen> {
  List<UploadableChannel>? _channels;
  String? _errorMessage;
  UploadableChannel? _uploadingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        _errorMessage = 'Channels konnten nicht geladen werden: $e';
      });
    }
  }

  Future<void> _sendTo(UploadableChannel channel) async {
    setState(() {
      _uploadingTo = channel;
      _errorMessage = null;
    });
    try {
      await widget.mediaService.uploadPhoto(
        channelId: channel.channelId,
        bytes: widget.bytes,
        fileExtension: widget.fileExtension,
        mimeType: widget.mimeType,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChannelFeedScreen(channelId: channel.channelId, channelName: channel.channelName),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingTo = null;
        _errorMessage = 'Senden fehlgeschlagen: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    return Scaffold(
      appBar: AppBar(title: const Text('Senden an…')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(widget.bytes, fit: BoxFit.cover, width: double.infinity),
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
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Du bist noch in keinem Channel, in dem du Fotos teilen kannst.'),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final channel in channels)
                            ListTile(
                              leading: const Icon(Icons.photo_library_outlined),
                              title: Text(channel.channelName),
                              subtitle: Text(channel.spaceLabel),
                              trailing: _uploadingTo == channel
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
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
