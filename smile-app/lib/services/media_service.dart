import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'local_changes.dart';
import 'media_shrink.dart';
import 'offline.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';

import '../main.dart';
import 'edge_functions.dart';
import 'resumable_upload.dart';

class MediaItem {
  MediaItem({
    required this.id,
    required this.mediaType,
    required this.displayUrl,
    required this.createdAt,
    required this.processingStatus,
    required this.senderId,
    this.thumbnailUrl,
    this.previewDataUrl,
    this.caption,
    this.senderDisplayName,
    this.senderAvatarUrl,
    this.width,
    this.height,
  });

  final String id;
  final String mediaType;
  final String? displayUrl;
  final String? thumbnailUrl;
  final String? previewDataUrl;
  final String? caption;
  final String processingStatus; // 'uploaded' | 'processing' | 'ready'
  final DateTime createdAt;
  final String senderId;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  // Original pixel dimensions, if known (populated once processing
  // finishes) -- lets the feed show a photo at its own aspect ratio
  // instead of always cropping to a square.
  final int? width;
  final int? height;

  bool get isReady => processingStatus == 'ready';
  bool get isVideo => mediaType == 'video';

  String get senderLabel => senderDisplayName ?? senderId;

  double? get aspectRatio => (width != null && height != null && height! > 0) ? width! / height! : null;

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        mediaType: json['media_type'] as String,
        displayUrl: json['display_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        previewDataUrl: json['preview_data_url'] as String?,
        caption: json['caption'] as String?,
        processingStatus: json['processing_status'] as String? ?? 'ready',
        createdAt: DateTime.parse(json['created_at'] as String),
        senderId: json['sender_id'] as String,
        senderDisplayName: json['sender_display_name'] as String?,
        senderAvatarUrl: json['sender_avatar_url'] as String?,
        width: json['width'] as int?,
        height: json['height'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'media_type': mediaType,
        'display_url': displayUrl,
        'thumbnail_url': thumbnailUrl,
        'preview_data_url': previewDataUrl,
        'caption': caption,
        'processing_status': processingStatus,
        'created_at': createdAt.toIso8601String(),
        'sender_id': senderId,
        'sender_display_name': senderDisplayName,
        'sender_avatar_url': senderAvatarUrl,
        'width': width,
        'height': height,
      };
}

/// Outcome of a delete-media call (delete/hide/unhide) -- bulk-capable, so
/// a mix of eligible and ineligible ids in one call still applies to what
/// it can; [deniedIds] reports the rest instead of failing the whole call.
/// A photo made ready on the phone (MediaService.preparePhoto).
class PreparedPhoto {
  const PreparedPhoto({required this.display, required this.thumbnail, this.size, this.preview});

  final Uint8List display;
  final Uint8List thumbnail;
  final (int, int)? size;
  final String? preview;
}

/// A video made ready on the phone (MediaService.prepareVideo): [file] is
/// the converted copy, or the original if the phone couldn't convert it.
class PreparedVideo {
  const PreparedVideo({
    required this.file,
    required this.mimeType,
    this.shrunk,
    this.poster,
    this.frame,
    this.previewDataUrl,
  });

  final File file;
  final String mimeType;
  /// Set only when it was converted AND has its poster: then video and
  /// poster go straight to where they are served from.
  final ShrunkVideo? shrunk;
  final Uint8List? poster;
  /// A still from the start of the original, as taken (what the album
  /// shows while it waits).
  final Uint8List? frame;
  final String? previewDataUrl;
}

class MediaActionResult {
  MediaActionResult({required this.appliedIds, required this.deniedIds});

  final List<String> appliedIds;
  final List<String> deniedIds;

  factory MediaActionResult.fromJson(Map<String, dynamic> json) => MediaActionResult(
        appliedIds: (json['applied'] as List).cast<String>(),
        deniedIds: (json['denied'] as List).cast<String>(),
      );
}

/// Upload (two-step, matches supabase/functions/create-upload +
/// complete-upload) and channel-feed fetch (get-signed-media-urls). Bytes
/// never touch a client-writable path -- create-upload returns a signed,
/// single-use upload token; reads go through signed 1h URLs, never a raw
/// bucket reference.
class MediaService {
  /// Loops through get-signed-media-urls' keyset pages until exhausted --
  /// the channel-feed grid shows the full history, not just the first page.
  Future<List<MediaItem>> fetchReadyMedia(String channelId) => _fetchMedia(channelId, onlyHidden: false);

  /// The "Ausgeblendet" view: only the caller's own hidden-for-me items in
  /// this channel (see delete-media's "hide" action). Still real, fully
  /// processed photos -- just personally filtered out of the normal feed.
  Future<List<MediaItem>> fetchHiddenMedia(String channelId) => _fetchMedia(channelId, onlyHidden: true);

  Future<List<MediaItem>> _fetchMedia(String channelId, {required bool onlyHidden}) async {
    final items = <MediaItem>[];
    String? cursor;
    while (true) {
      final response = await invokeEdge(
        'get-signed-media-urls',
        body: {
          'channel_id': channelId,
          'cursor': ?cursor,
          'only_hidden': onlyHidden,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final page = (data['items'] as List).cast<Map<String, dynamic>>();
      items.addAll(page.map(MediaItem.fromJson));
      cursor = data['next_cursor'] as String?;
      if (cursor == null) break;
    }
    return items;
  }

  /// A tiny, low-quality JPEG (few KB at most) encoded as a data URI --
  /// shown as an instant blurry placeholder (WhatsApp-style) in other
  /// members' feeds the moment the row is created, well before the real
  /// upload + server-side resize/thumbnail pipeline finishes. Resized this
  /// small, compression is near-instant and doesn't delay the real upload.
  Future<String?> _buildPreviewDataUrl(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 40,
        minHeight: 40,
        quality: 25,
        format: CompressFormat.jpeg,
      );
      return 'data:image/jpeg;base64,${base64Encode(compressed)}';
    } catch (_) {
      return null; // Best-effort -- a missing preview just means no placeholder, not a failed upload.
    }
  }

  /// A photo made ready for the album on the phone -- no connection needed
  /// (2026-10-11, UploadQueue): shrunk (MediaShrink), its thumbnail, its
  /// size and the tiny preview. Null if the phone can't (unusual format);
  /// then it goes the old way through the server.
  Future<PreparedPhoto?> preparePhoto(Uint8List original) async {
    final display = await MediaShrink.photo(original);
    if (display == null) return null;
    final thumbnail = await MediaShrink.thumbnail(display);
    if (thumbnail == null) return null;
    return PreparedPhoto(
      display: display,
      thumbnail: thumbnail,
      size: await MediaShrink.sizeOf(display),
      preview: await _buildPreviewDataUrl(thumbnail),
    );
  }

  /// Prepared photos straight from the phone (2026-10-10, migrations/0071):
  /// no Edge Function in between -- those cost ~1-1.6 s per call. Each photo
  /// brings its own id ([newUuid], kept by the UploadQueue so a second try
  /// can't make a second photo); the files go directly to where they are
  /// served from (four photos at a time), then ONE request inserts all rows
  /// as ready -- the database checks the files and announces them itself.
  ///
  /// Returns one entry per photo: null when it worked, else the error.
  Future<List<Object?>> sendPreparedPhotos({
    required String channelId,
    required List<({String id, PreparedPhoto photo})> photos,
    void Function(int attempt, int maxAttempts)? onRetrying,
  }) async {
    final clock = Stopwatch()..start();
    final userId = supabase.auth.currentUser!.id;
    final errors = List<Object?>.filled(photos.length, null);
    String displayPath(int i) => '$channelId/${photos[i].id}_display.jpg';
    String thumbPath(int i) => '$channelId/${photos[i].id}_thumb.jpg';

    // The files: four photos at a time, each photo with its thumbnail.
    final uploaded = <int>[];
    var next = 0;
    Future<void> worker() async {
      while (next < photos.length) {
        final i = next++;
        try {
          await Future.wait([
            _uploadOwn('media-display', displayPath(i), photos[i].photo.display, onRetrying),
            _uploadOwn('media-thumbnails', thumbPath(i), photos[i].photo.thumbnail, onRetrying),
          ]);
          uploaded.add(i);
        } catch (e) {
          errors[i] = e;
        }
      }
    }

    await Future.wait(List.generate(photos.length < 4 ? photos.length : 4, (_) => worker()));
    uploaded.sort();
    debugPrint('SmilePhoto: uploaded in ${clock.elapsedMilliseconds} ms');

    // One request puts them all in the album, in the order they were picked.
    if (uploaded.isNotEmpty) {
      try {
        await _withRetry(
          () async {
            try {
              await supabase.from('media_items').insert([
                for (final i in uploaded)
                  {
                    'id': photos[i].id,
                    'channel_id': channelId,
                    'sender_id': userId,
                    'media_type': 'photo',
                    'mime_type': 'image/jpeg',
                    'storage_path_original': displayPath(i),
                    'storage_path_display': displayPath(i),
                    'storage_path_thumbnail': thumbPath(i),
                    'processing_status': 'ready',
                    'file_size_bytes': photos[i].photo.display.length,
                    'width': ?photos[i].photo.size?.$1,
                    'height': ?photos[i].photo.size?.$2,
                    'preview_data_url': ?photos[i].photo.preview,
                  },
              ]);
            } on PostgrestException catch (e) {
              // A retry after the first attempt went through but its answer
              // was lost: the rows are there.
              if (e.code != '23505') rethrow;
            }
          },
          onRetry: onRetrying,
        );
        LocalChanges.saved(tablesChanged({'media_items', 'channels'}, channelIds: {channelId}));
      } catch (e) {
        for (final i in uploaded) {
          errors[i] = e;
        }
        // Refused: take the files back again (no leftovers). Not when the
        // connection broke -- the rows may be in after all, and the queue
        // tries again with the same ids anyway.
        if (!Offline.isConnectionError(e)) {
          try {
            await supabase.storage.from('media-display').remove([for (final i in uploaded) displayPath(i)]);
            await supabase.storage.from('media-thumbnails').remove([for (final i in uploaded) thumbPath(i)]);
          } catch (_) {}
        }
      }
    }
    debugPrint('SmilePhoto: ${uploaded.length} ready in ${clock.elapsedMilliseconds} ms');
    return errors;
  }

  /// One of the caller's own files into a media bucket (migrations/0071's
  /// policy). A retry that finds the file already there counts as done.
  Future<void> _uploadOwn(
    String bucket,
    String path,
    Uint8List data,
    void Function(int attempt, int maxAttempts)? onRetrying,
  ) =>
      _withRetry(
        () async {
          try {
            await supabase.storage.from(bucket).uploadBinary(path, data, fileOptions: const FileOptions(contentType: 'image/jpeg'));
          } on StorageException catch (e) {
            if (e.statusCode != '409' && !e.message.toLowerCase().contains('exists')) rethrow;
          }
        },
        onRetry: onRetrying,
      );

  /// A random (version 4) UUID -- the phone names its photos itself.
  static String newUuid() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// The old way through the server (create-upload/complete-upload) --
  /// for photos the phone couldn't prepare.
  /// Several photos at once, like WhatsApp (2026-10-10). Every Edge Function
  /// call costs ~1 s regardless of size, so the whole selection is
  /// registered in ONE create-upload call and marked ready in ONE
  /// complete-upload call; in between, the files go up in parallel straight
  /// to where they are served from. Each photo is made ready on the phone
  /// first (MediaShrink: ~250 KB plus its thumbnail).
  ///
  /// [onMediaItemCreated] (index, id) as soon as the ids are known. Returns
  /// one entry per photo: null when it worked, else the error -- a failed
  /// photo is removed again and doesn't hold up the others.
  Future<List<Object?>> uploadPhotosViaServer({
    required String channelId,
    required List<({Uint8List bytes, String fileExtension, String mimeType})> photos,
    void Function(int index, String mediaItemId)? onMediaItemCreated,
    void Function(int index)? onReady,
    void Function(int attempt, int maxAttempts)? onRetrying,
  }) async {
    final clock = Stopwatch()..start();
    final errors = List<Object?>.filled(photos.length, null);
    final previews = await Future.wait(photos.map((p) => _buildPreviewDataUrl(p.bytes)));

    // Registering with the server runs while the photos are prepared.
    final created = _withRetry(
      () => _createUploads(channelId, [
        for (var i = 0; i < photos.length; i++)
          {
            'media_type': 'photo',
            'mime_type': 'image/jpeg',
            'file_extension': 'jpg',
            'file_size_bytes': photos[i].bytes.length,
            'preview_data_url': ?previews[i],
            'client_encoded': true,
          },
      ]),
      onRetry: onRetrying,
    )..ignore(); // awaited below; this only keeps an early failure from counting as unhandled

    final prepared = <({Uint8List? shrunk, Uint8List? thumbnail, (int, int)? size})>[];
    for (final photo in photos) {
      final shrunk = await MediaShrink.photo(photo.bytes);
      prepared.add((
        shrunk: shrunk,
        thumbnail: shrunk == null ? null : await MediaShrink.thumbnail(shrunk),
        size: shrunk == null ? null : await MediaShrink.sizeOf(shrunk),
      ));
    }
    debugPrint('SmilePhoto: ${photos.length} prepared in ${clock.elapsedMilliseconds} ms');

    final slots = await created;
    debugPrint('SmilePhoto: registered in ${clock.elapsedMilliseconds} ms');
    for (var i = 0; i < slots.length; i++) {
      onMediaItemCreated?.call(i, slots[i]['media_item_id'] as String);
    }

    // The files: up to four photos at a time, each with its thumbnail.
    final direct = List<bool>.filled(photos.length, false);
    var next = 0;
    Future<void> worker() async {
      while (next < photos.length) {
        final i = next++;
        final slot = slots[i];
        final p = prepared[i];
        final displayPath = slot['display_path'] as String?;
        final displayToken = slot['display_token'] as String?;
        final thumbPath = slot['thumb_path'] as String?;
        final thumbToken = slot['thumb_token'] as String?;
        try {
          if (p.shrunk != null &&
              p.thumbnail != null &&
              displayPath != null &&
              displayToken != null &&
              thumbPath != null &&
              thumbToken != null) {
            await Future.wait([
              _put('media-display', displayPath, displayToken, p.shrunk!, 'image/jpeg', onRetrying),
              _put('media-thumbnails', thumbPath, thumbToken, p.thumbnail!, 'image/jpeg', onRetrying),
            ]);
            direct[i] = true;
          } else {
            // Not prepared (unusual format): the server makes both, as before.
            await _put(
              'media-originals',
              slot['storage_path'] as String,
              slot['token'] as String,
              photos[i].bytes,
              photos[i].mimeType,
              onRetrying,
            );
            await _withRetry(
              () => _completeUpload(slot['media_item_id'] as String, fileSizeBytes: photos[i].bytes.length),
              onRetry: onRetrying,
            );
            onReady?.call(i);
          }
        } catch (e) {
          errors[i] = e;
        }
      }
    }

    await Future.wait(List.generate(photos.length < 4 ? photos.length : 4, (_) => worker()));
    debugPrint('SmilePhoto: uploaded in ${clock.elapsedMilliseconds} ms');

    final readyNow = [for (var i = 0; i < photos.length; i++) if (direct[i] && errors[i] == null) i];
    if (readyNow.isNotEmpty) {
      try {
        final statuses = await _withRetry(
          () => _completeUploads([
            for (final i in readyNow)
              {
                'media_item_id': slots[i]['media_item_id'],
                'width': ?prepared[i].size?.$1,
                'height': ?prepared[i].size?.$2,
                'file_size_bytes': prepared[i].shrunk!.length,
              },
          ]),
          onRetry: onRetrying,
        );
        for (final i in readyNow) {
          if (statuses[slots[i]['media_item_id']] == 'ready') {
            onReady?.call(i);
          } else {
            errors[i] = MediaServiceException('complete_upload_failed');
          }
        }
      } catch (e) {
        for (final i in readyNow) {
          errors[i] = e;
        }
      }
    }
    debugPrint('SmilePhoto: ${photos.length} ready in ${clock.elapsedMilliseconds} ms');

    // A photo that didn't make it must not stay behind as a ghost in the
    // album: create-upload already made its row. Best-effort.
    final failedIds = [for (var i = 0; i < photos.length; i++) if (errors[i] != null) slots[i]['media_item_id'] as String];
    if (failedIds.isNotEmpty) {
      try {
        await _applyAction(failedIds, 'delete');
      } catch (_) {}
    }
    if (errors.any((e) => e == null)) {
      LocalChanges.saved(tablesChanged({'media_items', 'channels'}, channelIds: {channelId}));
    }
    return errors;
  }

  /// create-upload for several files at once (in the order given).
  Future<List<Map<String, dynamic>>> _createUploads(String channelId, List<Map<String, dynamic>> items) async {
    final response = await invokeEdge('create-upload', body: {'channel_id': channelId, 'items': items});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MediaServiceException(data['error'] as String);
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }

  /// complete-upload for several prepared files at once: id -> status.
  Future<Map<String, String>> _completeUploads(List<Map<String, dynamic>> items) async {
    final response = await invokeEdge('complete-upload', body: {'items': items});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MediaServiceException(data['error'] as String);
    return {
      for (final r in (data['items'] as List).cast<Map<String, dynamic>>())
        r['media_item_id'] as String: r['status'] as String,
    };
  }

  /// A video made ready on the phone -- no connection needed (2026-10-11,
  /// UploadQueue): re-encoded like WhatsApp (MediaShrink, 2026-10-09: ~15
  /// MB per minute instead of 100-700 MB) plus its poster frame. If the
  /// phone can't, the original goes up later and the server shrinks it.
  Future<PreparedVideo> prepareVideo(
    File original, {
    required String mimeType,
    void Function(int percent)? onPreparing,
    // Its preview is known (before converting starts).
    void Function(String? previewDataUrl)? onFramed,
  }) async {
    final frame = await videoPosterBytes(original);
    final previewDataUrl = frame == null ? null : await _buildPreviewDataUrl(frame);
    onFramed?.call(previewDataUrl);
    final shrunk = await MediaShrink.video(original, onProgress: onPreparing);
    // Its own poster frame goes up with it, so the server can take both as
    // they are (complete-upload, client_encoded). The frame already taken
    // from the original is the same picture.
    final posterFrame = shrunk == null ? null : (frame ?? await videoPosterBytes(shrunk.file));
    final poster = posterFrame == null ? null : await MediaShrink.poster(posterFrame);
    return PreparedVideo(
      file: shrunk?.file ?? original,
      mimeType: shrunk != null ? 'video/mp4' : mimeType,
      shrunk: poster == null ? null : shrunk,
      poster: poster,
      frame: frame,
      previewDataUrl: previewDataUrl,
    );
  }

  /// Registers a video with the server (create-upload) -- its row, and the
  /// instant blurry preview for the others, exist from here on.
  Future<Map<String, dynamic>> createVideoUpload({
    required String channelId,
    required int fileSizeBytes,
    String? previewDataUrl,
    void Function(int attempt, int maxAttempts)? onRetrying,
  }) =>
      _withRetry(
        () => _createUpload(
          channelId: channelId,
          mediaType: 'video',
          mimeType: 'video/mp4',
          fileExtension: 'mp4',
          fileSizeBytes: fileSizeBytes,
          previewDataUrl: previewDataUrl,
          clientEncoded: true,
        ),
        onRetry: onRetrying,
      );

  /// Sends a prepared video; [createData] if it was already registered
  /// (the queue does that while the phone converts -- one round trip
  /// less). Returns its media id. A video the server refused or that
  /// couldn't be finished is removed again (no ghost rows).
  Future<String> sendPreparedVideo({
    required String channelId,
    required PreparedVideo video,
    Map<String, dynamic>? createData,
    void Function(String mediaItemId)? onMediaItemCreated,
    void Function(int attempt, int maxAttempts)? onRetrying,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    final size = video.file.lengthSync();
    final created = createData ??
        await createVideoUpload(
          channelId: channelId,
          fileSizeBytes: size,
          previewDataUrl: video.previewDataUrl,
          onRetrying: onRetrying,
        );
    onProgress?.call(0, size);
    await _uploadVideoFile(
      channelId: channelId,
      createData: created,
      upload: video.file,
      shrunk: video.shrunk,
      poster: video.poster,
      mimeType: video.mimeType,
      onMediaItemCreated: onMediaItemCreated,
      onRetrying: onRetrying,
      onProgress: onProgress,
    );
    return created['media_item_id'] as String;
  }

  /// Removes a video's row again -- one registered by an earlier try that
  /// never finished (best effort).
  Future<void> dropUnfinished(String mediaItemId) async {
    try {
      await _applyAction([mediaItemId], 'delete');
    } catch (_) {}
  }

  Future<void> _uploadVideoFile({
    required String channelId,
    required Map<String, dynamic> createData,
    required File upload,
    ShrunkVideo? shrunk,
    Uint8List? poster,
    required String mimeType,
    void Function(String mediaItemId)? onMediaItemCreated,
    void Function(int attempt, int maxAttempts)? onRetrying,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    final clock = Stopwatch()..start();
    final size = upload.lengthSync();
    final mediaItemId = createData['media_item_id'] as String;
    onMediaItemCreated?.call(mediaItemId);

    try {
      // Converted here: video and poster go straight to where they are
      // served from, at once, and the server only marks it ready
      // (2026-10-10). Otherwise the original goes to the worker as before.
      final displayPath = createData['display_path'] as String?;
      final displayToken = createData['display_token'] as String?;
      final thumbPath = createData['thumb_path'] as String?;
      final thumbToken = createData['thumb_token'] as String?;
      final direct = shrunk != null &&
          poster != null &&
          displayPath != null &&
          displayToken != null &&
          thumbPath != null &&
          thumbToken != null;
      final bucket = direct ? 'media-display' : 'media-originals';
      final path = direct ? displayPath : createData['storage_path'] as String;
      final token = direct ? displayToken : createData['token'] as String;
      // A converted video is small: one request instead of the chunked,
      // resumable protocol meant for huge originals (2026-10-09).
      Future<void> sendVideo() async {
        if (size > _singleRequestVideoBytes) {
          await ResumableUpload().upload(
            file: upload,
            bucket: bucket,
            objectName: path,
            token: token,
            contentType: mimeType,
            onProgress: onProgress,
            onRetrying: onRetrying,
          );
          return;
        }
        final bytes = await upload.readAsBytes();
        await _put(bucket, path, token, bytes, mimeType, onRetrying);
        onProgress?.call(size, size);
      }

      await Future.wait([
        sendVideo(),
        if (direct) _put('media-thumbnails', thumbPath, thumbToken, poster, 'image/jpeg', onRetrying),
      ]);
      debugPrint('SmileUpload: uploaded $size bytes, ${clock.elapsedMilliseconds} ms');
      await _withRetry(
        () => _completeUpload(mediaItemId, clientEncoded: direct ? shrunk : null, fileSizeBytes: size),
        onRetry: onRetrying,
      );
      debugPrint('SmileUpload: complete-upload ${clock.elapsedMilliseconds} ms');
    } catch (e) {
      // Same cleanup rule as uploadPhoto: never leave a ghost row behind.
      try {
        await _applyAction([mediaItemId], 'delete');
      } catch (_) {}
      rethrow;
    }
    LocalChanges.saved(tablesChanged({'media_items', 'channels'}, channelIds: {channelId}));
  }

  /// One file to a signed upload slot, with the usual retries.
  Future<void> _put(
    String bucket,
    String path,
    String token,
    Uint8List data,
    String mimeType,
    void Function(int attempt, int maxAttempts)? onRetrying,
  ) =>
      _withRetry(
        () => supabase.storage.from(bucket).uploadBinaryToSignedUrl(path, token, data, FileOptions(contentType: mimeType)),
        onRetry: onRetrying,
      );

  /// Up to this size a video goes up in one request (converted videos are
  /// ~20 MB per minute); larger ones resumably in chunks.
  static const _singleRequestVideoBytes = 50 * 1024 * 1024;

  /// A still frame from the start of a local video (JPEG bytes), for the
  /// placeholder while it uploads. Best-effort: null if it can't be read.
  static Future<Uint8List?> videoPosterBytes(File file) async {
    try {
      // Never waits forever (2026-10-12).
      return await FcNativeVideoThumbnail()
          .saveThumbnailToBytes(srcFile: file.path, width: 1280, height: 1280, format: 'jpeg', quality: 85)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _createUpload({
    required String channelId,
    String mediaType = 'photo',
    required String mimeType,
    required String fileExtension,
    required int fileSizeBytes,
    String? previewDataUrl,
    bool clientEncoded = false,
  }) async {
    final response = await invokeEdge('create-upload', body: {
      if (clientEncoded) 'client_encoded': true,
      'channel_id': channelId,
      'media_type': mediaType,
      'mime_type': mimeType,
      'file_extension': fileExtension,
      'file_size_bytes': fileSizeBytes,
      'preview_data_url': ?previewDataUrl,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MediaServiceException(data['error'] as String);
    return data;
  }

  Future<void> _completeUpload(
    String mediaItemId, {
    ShrunkVideo? clientEncoded,
    ({int? width, int? height})? photo,
    int? fileSizeBytes,
  }) async {
    final response = await invokeEdge('complete-upload', body: {
      'media_item_id': mediaItemId,
      'file_size_bytes': ?fileSizeBytes,
      if (photo != null) ...{
        'client_encoded': true,
        'direct': true,
        'width': ?photo.width,
        'height': ?photo.height,
      },
      if (clientEncoded != null) ...{
        'client_encoded': true,
        'direct': true,
        'width': ?clientEncoded.width,
        'height': ?clientEncoded.height,
        'duration_seconds': ?clientEncoded.durationSeconds,
      },
    });
    final data = response.data as Map<String, dynamic>;
    const acceptedStatuses = {'ready', 'pending_processing', 'processing'};
    if (!acceptedStatuses.contains(data['status'])) {
      throw MediaServiceException(data['error'] as String? ?? 'complete_upload_failed');
    }
  }

  static const _retryDelays = [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 10)];

  /// Retries a network step up to `_retryDelays.length + 1` times, but never
  /// retries a [MediaServiceException] -- that's a real, server-reported
  /// error (e.g. "not_a_contributor"), not a transient network fault, so
  /// retrying it would just delay an unavoidable failure.
  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    void Function(int attempt, int maxAttempts)? onRetry,
  }) async {
    final maxAttempts = _retryDelays.length + 1;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } on MediaServiceException {
        rethrow;
      } catch (_) {
        if (attempt == maxAttempts) rethrow;
        onRetry?.call(attempt, maxAttempts);
        await Future<void>.delayed(_retryDelays[attempt - 1]);
      }
    }
    throw StateError('unreachable');
  }

  /// Destructive and permanent: only the sender or a channel admin/staff
  /// member may do this (server-enforced). Bulk-capable for multi-select --
  /// see [MediaActionResult.deniedIds] for ids that weren't permitted.
  Future<MediaActionResult> deletePhotos(List<String> mediaItemIds) => _applyAction(mediaItemIds, 'delete');

  /// Non-destructive and personal: any member of the photo's channel may
  /// hide/re-show it for just their own Smile-App view. Bulk-capable, same
  /// multi-select flow as [deletePhotos] -- driven by an eye icon next to
  /// the trash icon once a selection exists, not a permanent per-tile icon.
  Future<MediaActionResult> hidePhotos(List<String> mediaItemIds) => _applyAction(mediaItemIds, 'hide');
  Future<MediaActionResult> unhidePhotos(List<String> mediaItemIds) => _applyAction(mediaItemIds, 'unhide');

  Future<MediaActionResult> _applyAction(List<String> mediaItemIds, String action) async {
    final response = await invokeEdge('delete-media', body: {
      'media_item_ids': mediaItemIds,
      'action': action,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw MediaServiceException(data['error'] as String);
    }
    return MediaActionResult.fromJson(data);
  }
}

class MediaServiceException implements Exception {
  MediaServiceException(this.code);

  final String code;

  @override
  String toString() => 'MediaServiceException($code)';
}
