import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import 'video_quality.dart';

/// A video converted on the phone, with what the server would otherwise
/// have measured itself.
class ShrunkVideo {
  const ShrunkVideo({required this.file, this.width, this.height, this.durationSeconds});

  final File file;
  final int? width;
  final int? height;
  final double? durationSeconds;
}

/// Photos and videos are made smaller on the phone before they are
/// uploaded, like WhatsApp (decided 2026-10-09) -- to exactly what the
/// media-processing-service keeps anyway (media-processing-service/
/// index.js and video.js), so nothing visible is lost, only upload time.
class MediaShrink {
  MediaShrink._();

  /// Longer edge of an uploaded photo: sharp on the Frames (the P610 shows
  /// 2000 px) and small to send -- WhatsApp sends ~1600 px (2026-10-10).
  static const photoMaxEdge = 2048;

  /// The server's thumbnail size (THUMBNAIL_MAX_EDGE) -- the album grid.
  static const thumbnailMaxEdge = 400;

  static const _videoChannel = MethodChannel('smile/video_compress');

  /// A photo as JPEG with its longer edge at most [photoMaxEdge] (~300-600
  /// KB instead of 3-6 MB). Returns null if it can't be shrunk -- then the
  /// original is uploaded as before.
  static Future<Uint8List?> photo(Uint8List original) => _jpeg(original, photoMaxEdge, 80);

  /// The small picture of a photo for the album grid.
  static Future<Uint8List?> thumbnail(Uint8List photo) => _jpeg(photo, thumbnailMaxEdge, 80);

  /// Width and height of an image as shown.
  static Future<(int, int)?> sizeOf(Uint8List image) async {
    try {
      final descriptor = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(image));
      final size = (descriptor.width, descriptor.height);
      descriptor.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _jpeg(Uint8List original, int maxEdge, int quality) async {
    try {
      final descriptor = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(original));
      final longEdge = descriptor.width > descriptor.height ? descriptor.width : descriptor.height;
      final shortEdge = descriptor.width > descriptor.height ? descriptor.height : descriptor.width;
      descriptor.dispose();
      // flutter_image_compress keeps both sides at least min*: passing the
      // target SHORT edge for both works for any orientation.
      final targetShort = longEdge <= maxEdge ? shortEdge : (shortEdge * maxEdge / longEdge).round();
      final shrunk = await FlutterImageCompress.compressWithList(
        original,
        minWidth: targetShort,
        minHeight: targetShort,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return shrunk.isEmpty ? null : shrunk;
    } catch (_) {
      return null;
    }
  }

  /// A poster frame for the album, the grid and the Frame -- as sharp as the
  /// video itself (longer edge at most 1280 px; 400 px looked blurry in
  /// the album's bubbles), from a frame of the video.
  static Future<Uint8List?> poster(Uint8List frame) async {
    try {
      final descriptor = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(frame));
      final longEdge = descriptor.width > descriptor.height ? descriptor.width : descriptor.height;
      final shortEdge = descriptor.width > descriptor.height ? descriptor.height : descriptor.width;
      descriptor.dispose();
      final targetShort = longEdge <= 1280 ? shortEdge : (shortEdge * 1280 / longEdge).round();
      final jpeg = await FlutterImageCompress.compressWithList(
        frame,
        minWidth: targetShort,
        minHeight: targetShort,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      return jpeg.isEmpty ? null : jpeg;
    } catch (_) {
      return null;
    }
  }

  /// A video re-encoded on the phone (H.264, longer edge at most 1280 px,
  /// HDR to SDR -- VideoCompressor.kt). [onProgress] gets 0-100. Returns
  /// null if the phone can't do it -- then the original is uploaded.
  static Future<ShrunkVideo?> video(File original, {void Function(int percent)? onProgress}) async {
    final dir = await getTemporaryDirectory();
    final output = '${dir.path}/smile_upload_${DateTime.now().microsecondsSinceEpoch}.mp4';
    _videoChannel.setMethodCallHandler((call) async {
      if (call.method == 'progress') onProgress?.call(call.arguments as int);
    });
    try {
      // The person's "Videos senden" setting (2026-10-12).
      await VideoQuality.load();
      final quality = VideoQuality.current.value;
      final result = await _videoChannel.invokeMapMethod<String, Object?>(
        'compress',
        {'input': original.path, 'output': output, 'shortSide': quality.shortSide,
          'bitrate': quality.bitrate,
          'audioBitrate': quality.audioBitrate,
        },
      );
      final path = result?['path'] as String?;
      if (path == null) return null;
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) return null;
      int? positive(Object? v) => v is int && v > 0 ? v : null;
      final durationMs = positive(result?['durationMs']);
      return ShrunkVideo(
        file: file,
        width: positive(result?['width']),
        height: positive(result?['height']),
        durationSeconds: durationMs == null ? null : durationMs / 1000,
      );
    } catch (e) {
      debugPrint('SmileVideo: shrinking failed, uploading the original: $e');
      return null;
    } finally {
      _videoChannel.setMethodCallHandler(null);
    }
  }
}
