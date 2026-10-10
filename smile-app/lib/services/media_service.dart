import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'local_changes.dart';
import 'media_shrink.dart';
import 'video_cache.dart';

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

  /// Returns the media_item_id as soon as it's known (right after
  /// create-upload responds) via [onMediaItemCreated], so the caller can
  /// reconcile an optimistic local preview with the real item once it shows
  /// up in a later feed fetch -- without waiting for the whole upload to
  /// finish just to learn the id. Each network step (create-upload, the
  /// storage PUT, complete-upload) is individually retried with backoff --
  /// a WiFi handover mid-upload otherwise kills whichever HTTP request was
  /// in flight and fails the whole thing outright, even though the network
  /// is back seconds later. [onRetrying] (attempt, maxAttempts) fires before
  /// each wait, so the caller can show a transient "retrying" state instead
  /// of a hard error while this is still happening.
  Future<void> uploadPhoto({
    required String channelId,
    required Uint8List bytes,
    required String fileExtension,
    required String mimeType,
    void Function(String mediaItemId)? onMediaItemCreated,
    void Function(int attempt, int maxAttempts)? onRetrying,
  }) async {
    final errors = await uploadPhotos(
      channelId: channelId,
      photos: [(bytes: bytes, fileExtension: fileExtension, mimeType: mimeType)],
      onMediaItemCreated: (_, id) => onMediaItemCreated?.call(id),
      onRetrying: onRetrying,
    );
    if (errors.single != null) throw errors.single!;
  }

  /// Several photos at once, straight from the phone (2026-10-10,
  /// migrations/0071): no Edge Function in between -- those cost ~1-1.6 s
  /// per call. The phone gives each photo its id, uploads the prepared
  /// photo and its thumbnail directly to where they are served from (four
  /// photos at a time), then inserts all rows as ready in ONE request; the
  /// database checks the files and announces them itself.
  ///
  /// Photos the phone can't prepare (unusual format) take the old way
  /// through the server. [onMediaItemCreated] (index, id) at once,
  /// [onReady] (index) when one is in the album. Returns one entry per
  /// photo: null when it worked, else the error.
  Future<List<Object?>> uploadPhotos({
    required String channelId,
    required List<({Uint8List bytes, String fileExtension, String mimeType})> photos,
    void Function(int index, String mediaItemId)? onMediaItemCreated,
    void Function(int index)? onReady,
    void Function(int attempt, int maxAttempts)? onRetrying,
    // A photo is ready on the phone; only the network part is left.
    void Function(int index)? onPrepared,
  }) async {
    final clock = Stopwatch()..start();
    final userId = supabase.auth.currentUser!.id;
    final errors = List<Object?>.filled(photos.length, null);

    final prepared = <({Uint8List? shrunk, Uint8List? thumbnail, (int, int)? size, String? preview})>[];
    for (final photo in photos) {
      final shrunk = await MediaShrink.photo(photo.bytes);
      final thumbnail = shrunk == null ? null : await MediaShrink.thumbnail(shrunk);
      prepared.add((
        shrunk: shrunk,
        thumbnail: thumbnail,
        size: shrunk == null ? null : await MediaShrink.sizeOf(shrunk),
        preview: await _buildPreviewDataUrl(thumbnail ?? photo.bytes),
      ));
      if (shrunk != null && thumbnail != null) onPrepared?.call(prepared.length - 1);
    }
    debugPrint('SmilePhoto: ${photos.length} prepared in ${clock.elapsedMilliseconds} ms');

    final direct = [for (var i = 0; i < photos.length; i++) if (prepared[i].shrunk != null && prepared[i].thumbnail != null) i];
    final ids = <int, String>{for (final i in direct) i: _newUuid()};
    for (final i in direct) {
      onMediaItemCreated?.call(i, ids[i]!);
    }
    String displayPath(int i) => '$channelId/${ids[i]}_display.jpg';
    String thumbPath(int i) => '$channelId/${ids[i]}_thumb.jpg';

    // The files: four photos at a time, each photo with its thumbnail.
    final uploaded = <int>[];
    var next = 0;
    Future<void> worker() async {
      while (next < direct.length) {
        final i = direct[next++];
        try {
          await Future.wait([
            _uploadOwn('media-display', displayPath(i), prepared[i].shrunk!, onRetrying),
            _uploadOwn('media-thumbnails', thumbPath(i), prepared[i].thumbnail!, onRetrying),
          ]);
          uploaded.add(i);
        } catch (e) {
          errors[i] = e;
        }
      }
    }

    await Future.wait(List.generate(direct.length < 4 ? direct.length : 4, (_) => worker()));
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
                    'id': ids[i],
                    'channel_id': channelId,
                    'sender_id': userId,
                    'media_type': 'photo',
                    'mime_type': 'image/jpeg',
                    'storage_path_original': displayPath(i),
                    'storage_path_display': displayPath(i),
                    'storage_path_thumbnail': thumbPath(i),
                    'processing_status': 'ready',
                    'file_size_bytes': prepared[i].shrunk!.length,
                    'width': ?prepared[i].size?.$1,
                    'height': ?prepared[i].size?.$2,
                    'preview_data_url': ?prepared[i].preview,
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
        for (final i in uploaded) {
          onReady?.call(i);
        }
      } catch (e) {
        for (final i in uploaded) {
          errors[i] = e;
        }
        // Not in the album: take the files back again (no leftovers).
        try {
          await supabase.storage.from('media-display').remove([for (final i in uploaded) displayPath(i)]);
          await supabase.storage.from('media-thumbnails').remove([for (final i in uploaded) thumbPath(i)]);
        } catch (_) {}
      }
    }
    debugPrint('SmilePhoto: ${uploaded.length} ready in ${clock.elapsedMilliseconds} ms');

    // Couldn't be prepared here: through the server, as before.
    final viaServer = [for (var i = 0; i < photos.length; i++) if (!direct.contains(i)) i];
    if (viaServer.isNotEmpty) {
      final serverErrors = await _uploadPhotosViaServer(
        channelId: channelId,
        photos: [for (final i in viaServer) photos[i]],
        onMediaItemCreated: (j, id) => onMediaItemCreated?.call(viaServer[j], id),
        onReady: (j) => onReady?.call(viaServer[j]),
        onRetrying: onRetrying,
      );
      for (final (j, error) in serverErrors.indexed) {
        errors[viaServer[j]] = error;
      }
    } else if (uploaded.isNotEmpty) {
      LocalChanges.saved(tablesChanged({'media_items', 'channels'}, channelIds: {channelId}));
    }
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
  static String _newUuid() {
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
  Future<List<Object?>> _uploadPhotosViaServer({
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

  /// A video of any length (decision 2026-10-01): same two-step flow as
  /// [uploadPhoto], but the bytes go up resumably in chunks straight from
  /// disk (ResumableUpload) -- a multi-GB file is never held in memory, and
  /// a dropped connection resumes instead of starting over. The feed
  /// placeholder is a frame taken from the video on the phone itself.
  Future<void> uploadVideo({
    required String channelId,
    required File file,
    required String fileExtension,
    required String mimeType,
    void Function(String mediaItemId)? onMediaItemCreated,
    void Function(int attempt, int maxAttempts)? onRetrying,
    void Function(int sentBytes, int totalBytes)? onProgress,
    void Function(int percent)? onPreparing,
    // Converted on the phone; only the network part is left.
    void Function()? onPrepared,
  }) async {
    final frame = await videoPosterBytes(file);
    final previewDataUrl = frame == null ? null : await _buildPreviewDataUrl(frame);
    final clock = Stopwatch()..start();
    // Registering with the server runs while the phone converts -- one
    // round trip less (2026-10-09). The real size follows in complete-upload.
    final created = _withRetry(
      () => _createUpload(
        channelId: channelId,
        mediaType: 'video',
        mimeType: 'video/mp4',
        fileExtension: 'mp4',
        fileSizeBytes: file.lengthSync(),
        previewDataUrl: previewDataUrl,
        clientEncoded: true,
      ),
      onRetry: onRetrying,
    )..ignore(); // awaited below; this only keeps an early failure from counting as unhandled
    // Re-encoded on the phone first, like WhatsApp (MediaShrink,
    // 2026-10-09): ~15 MB per minute instead of 100-700 MB. If the phone
    // can't, the original goes up and the server shrinks it as before.
    final shrunk = await MediaShrink.video(file, onProgress: onPreparing);
    if (shrunk != null) onPrepared?.call();
    debugPrint('SmileUpload: shrunk in ${clock.elapsedMilliseconds} ms');
    final upload = shrunk?.file ?? file;
    // Its own poster frame goes up with it, so the server can take both
    // as they are (complete-upload, client_encoded). The frame already
    // taken from the original is the same picture.
    final posterFrame = shrunk == null ? null : (frame ?? await videoPosterBytes(shrunk.file));
    final poster = posterFrame == null ? null : await MediaShrink.poster(posterFrame);
    // From here on it is uploading -- the status says so.
    onProgress?.call(0, upload.lengthSync());
    final uploadMime = shrunk != null ? 'video/mp4' : mimeType;
    String? mediaItemId;
    var uploaded = false;
    try {
      await _uploadVideoFile(
        channelId: channelId,
        createData: await created,
        upload: upload,
        shrunk: poster == null ? null : shrunk,
        poster: poster,
        mimeType: uploadMime,
        onMediaItemCreated: (id) {
          mediaItemId = id;
          onMediaItemCreated?.call(id);
        },
        onRetrying: onRetrying,
        onProgress: onProgress,
      );
      uploaded = true;
    } finally {
      // The converted copy is the video as it now is on the server: kept on
      // the phone, it plays at once and offline (VideoCache, 2026-10-10).
      if (shrunk != null) {
        final id = mediaItemId;
        if (uploaded && id != null) {
          await VideoCache.keep(id, shrunk.file);
        } else {
          try {
            await shrunk.file.delete();
          } catch (_) {}
        }
      }
    }
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
      return await FcNativeVideoThumbnail()
          .saveThumbnailToBytes(srcFile: file.path, width: 1280, height: 1280, format: 'jpeg', quality: 85);
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
