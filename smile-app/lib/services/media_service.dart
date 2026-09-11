import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class MediaItem {
  MediaItem({
    required this.id,
    required this.mediaType,
    required this.displayUrl,
    required this.createdAt,
    required this.processingStatus,
    this.thumbnailUrl,
    this.previewDataUrl,
    this.caption,
  });

  final String id;
  final String mediaType;
  final String? displayUrl;
  final String? thumbnailUrl;
  final String? previewDataUrl;
  final String? caption;
  final String processingStatus; // 'uploaded' | 'processing' | 'ready'
  final DateTime createdAt;

  bool get isReady => processingStatus == 'ready';

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        mediaType: json['media_type'] as String,
        displayUrl: json['display_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        previewDataUrl: json['preview_data_url'] as String?,
        caption: json['caption'] as String?,
        processingStatus: json['processing_status'] as String? ?? 'ready',
        createdAt: DateTime.parse(json['created_at'] as String),
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
      final response = await supabase.functions.invoke(
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

  /// Notifies [onChange] whenever a media_items row in [channelId] is
  /// inserted or updated -- lets other members' feeds pick up a new photo
  /// (even just-uploaded, still-processing ones, via their preview) or a
  /// processing completion without polling. Caller must dispose the
  /// returned channel (`supabase.removeChannel`) when done.
  RealtimeChannel subscribeToChannelMedia(String channelId, void Function() onChange) {
    final channel = supabase.channel('media_items_$channelId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'media_items',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'channel_id', value: channelId),
        callback: (_) => onChange(),
      )
      ..subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) => supabase.removeChannel(channel);

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
    final previewDataUrl = await _buildPreviewDataUrl(bytes);

    final createData = await _withRetry(
      () => _createUpload(
        channelId: channelId,
        mimeType: mimeType,
        fileExtension: fileExtension,
        fileSizeBytes: bytes.length,
        previewDataUrl: previewDataUrl,
      ),
      onRetry: onRetrying,
    );
    final storagePath = createData['storage_path'] as String;
    final token = createData['token'] as String;
    final mediaItemId = createData['media_item_id'] as String;
    onMediaItemCreated?.call(mediaItemId);

    try {
      await _withRetry(
        () => supabase.storage.from('media-originals').uploadBinaryToSignedUrl(
              storagePath,
              token,
              bytes,
              FileOptions(contentType: mimeType),
            ),
        onRetry: onRetrying,
      );
      await _withRetry(() => _completeUpload(mediaItemId), onRetry: onRetrying);
    } catch (e) {
      // create-upload already created the media_items row at this point --
      // giving up here without cleanup would leave it stuck at
      // processing_status 'uploaded' forever (get-signed-media-urls only
      // ever excludes 'failed'), a permanent blurry-preview ghost visible
      // to the whole channel. Best-effort delete it; the sender always has
      // delete rights on their own item.
      try {
        await _applyAction([mediaItemId], 'delete');
      } catch (_) {
        // Cleanup is best-effort -- the original upload failure is what matters.
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _createUpload({
    required String channelId,
    required String mimeType,
    required String fileExtension,
    required int fileSizeBytes,
    String? previewDataUrl,
  }) async {
    final response = await supabase.functions.invoke('create-upload', body: {
      'channel_id': channelId,
      'media_type': 'photo',
      'mime_type': mimeType,
      'file_extension': fileExtension,
      'file_size_bytes': fileSizeBytes,
      'preview_data_url': ?previewDataUrl,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw MediaServiceException(data['error'] as String);
    return data;
  }

  Future<void> _completeUpload(String mediaItemId) async {
    final response = await supabase.functions.invoke('complete-upload', body: {'media_item_id': mediaItemId});
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
    final response = await supabase.functions.invoke('delete-media', body: {
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
