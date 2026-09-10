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
    this.deletedAt,
  });

  final String id;
  final String mediaType;
  final String? displayUrl;
  final String? thumbnailUrl;
  final String? previewDataUrl;
  final String? caption;
  final String processingStatus; // 'uploaded' | 'processing' | 'ready'
  final DateTime createdAt;
  // Only ever non-null for the person who deleted it "for everyone" --
  // get-signed-media-urls hides such rows from everyone else entirely, so
  // seeing this set at all means "I deleted this, show my own tombstone".
  final DateTime? deletedAt;

  bool get isReady => processingStatus == 'ready';
  bool get isDeleted => deletedAt != null;

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        mediaType: json['media_type'] as String,
        displayUrl: json['display_url'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        previewDataUrl: json['preview_data_url'] as String?,
        caption: json['caption'] as String?,
        processingStatus: json['processing_status'] as String? ?? 'ready',
        createdAt: DateTime.parse(json['created_at'] as String),
        deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
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
        'deleted_at': deletedAt?.toIso8601String(),
      };
}

/// Which of the two delete flavors (see migrations/0018_media_delete.sql)
/// a delete-media call applies.
enum MediaDeleteScope {
  forMe('for_me'),
  forEveryone('for_everyone');

  const MediaDeleteScope(this.wireValue);
  final String wireValue;
}

class MediaDeleteResult {
  MediaDeleteResult({required this.deletedIds, required this.deniedIds});

  final List<String> deletedIds;
  final List<String> deniedIds;

  factory MediaDeleteResult.fromJson(Map<String, dynamic> json) => MediaDeleteResult(
        deletedIds: (json['deleted'] as List).cast<String>(),
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
  Future<List<MediaItem>> fetchReadyMedia(String channelId) async {
    final items = <MediaItem>[];
    String? cursor;
    while (true) {
      final response = await supabase.functions.invoke(
        'get-signed-media-urls',
        body: {
          'channel_id': channelId,
          'cursor': ?cursor,
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
  /// finish just to learn the id.
  Future<void> uploadPhoto({
    required String channelId,
    required Uint8List bytes,
    required String fileExtension,
    required String mimeType,
    void Function(String mediaItemId)? onMediaItemCreated,
  }) async {
    final previewDataUrl = await _buildPreviewDataUrl(bytes);

    final createResponse = await supabase.functions.invoke('create-upload', body: {
      'channel_id': channelId,
      'media_type': 'photo',
      'mime_type': mimeType,
      'file_extension': fileExtension,
      'file_size_bytes': bytes.length,
      'preview_data_url': ?previewDataUrl,
    });
    final createData = createResponse.data as Map<String, dynamic>;
    if (createData['error'] != null) {
      throw MediaServiceException(createData['error'] as String);
    }
    final storagePath = createData['storage_path'] as String;
    final token = createData['token'] as String;
    final mediaItemId = createData['media_item_id'] as String;
    onMediaItemCreated?.call(mediaItemId);

    await supabase.storage.from('media-originals').uploadBinaryToSignedUrl(
          storagePath,
          token,
          bytes,
          FileOptions(contentType: mimeType),
        );

    final completeResponse = await supabase.functions.invoke(
      'complete-upload',
      body: {'media_item_id': mediaItemId},
    );
    final completeData = completeResponse.data as Map<String, dynamic>;
    const acceptedStatuses = {'ready', 'pending_processing', 'processing'};
    if (!acceptedStatuses.contains(completeData['status'])) {
      throw MediaServiceException(completeData['error'] as String? ?? 'complete_upload_failed');
    }
  }

  /// Bulk-capable (multi-select) delete. Each id is checked and applied
  /// independently server-side (see supabase/functions/delete-media), so a
  /// mix of eligible and ineligible ids in one call still deletes what it
  /// can -- [MediaDeleteResult.deniedIds] reports the rest.
  Future<MediaDeleteResult> deleteMedia({
    required List<String> mediaItemIds,
    required MediaDeleteScope scope,
  }) async {
    final response = await supabase.functions.invoke('delete-media', body: {
      'media_item_ids': mediaItemIds,
      'scope': scope.wireValue,
    });
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw MediaServiceException(data['error'] as String);
    }
    return MediaDeleteResult.fromJson(data);
  }
}

class MediaServiceException implements Exception {
  MediaServiceException(this.code);

  final String code;

  @override
  String toString() => 'MediaServiceException($code)';
}
