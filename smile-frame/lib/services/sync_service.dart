import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import 'device_credentials_store.dart';
import 'media_cache_store.dart';
import 'media_cache_sync.dart';
import 'pairing_service.dart';

class DevicePolicyInfo {
  DevicePolicyInfo({
    required this.displayMode,
    required this.slideshowIntervalSeconds,
    required this.channelSwitchEnabled,
    this.maxLocalCacheGb,
  });

  final String displayMode; // 'slideshow' | 'manual'
  final int slideshowIntervalSeconds;
  final bool channelSwitchEnabled;
  final double? maxLocalCacheGb;

  factory DevicePolicyInfo.fromJson(Map<String, dynamic> json) => DevicePolicyInfo(
        displayMode: json['display_mode'] as String? ?? 'slideshow',
        slideshowIntervalSeconds: json['slideshow_interval_seconds'] as int? ?? 8,
        channelSwitchEnabled: json['channel_switch_enabled'] as bool? ?? false,
        maxLocalCacheGb: (json['max_local_cache_gb'] as num?)?.toDouble(),
      );
}

class AssignedChannel {
  AssignedChannel({required this.channelId, required this.name, this.sortOrder});

  final String channelId;
  final String? name;
  final int? sortOrder;

  factory AssignedChannel.fromJson(Map<String, dynamic> json) => AssignedChannel(
        channelId: json['channel_id'] as String,
        name: json['name'] as String?,
        sortOrder: json['sort_order'] as int?,
      );
}

class SyncResult {
  SyncResult({
    required this.channelId,
    required this.entries,
    required this.policy,
    required this.assignedChannels,
    this.spaceName,
  });

  final String? channelId;
  final List<CachedMediaEntry> entries;
  final DevicePolicyInfo? policy;
  final List<AssignedChannel> assignedChannels;
  final String? spaceName;
}

/// Orchestrates one sync round: refresh the access token if it's close to
/// expiry, call get-media-batch, diff against the local cache, download
/// what's new, evict what's gone (and whatever's over the policy's byte
/// cap), persist the updated index. A failed network call falls back to
/// whatever is already cached -- offline tolerance (concept doc sect. 25).
class SyncService {
  SyncService({
    PairingService? pairingService,
    DeviceCredentialsStore? credentialsStore,
    MediaCacheStore? cacheStore,
    http.Client? httpClient,
  })  : _pairingService = pairingService ?? PairingService(),
        _credentialsStore = credentialsStore ?? DeviceCredentialsStore(),
        _cacheStore = cacheStore ?? MediaCacheStore(),
        _httpClient = httpClient ?? http.Client();

  final PairingService _pairingService;
  final DeviceCredentialsStore _credentialsStore;
  final MediaCacheStore _cacheStore;
  final http.Client _httpClient;

  Future<SyncResult> sync({String? fcmToken}) async {
    await _refreshIfNeeded();

    final accessToken = await _credentialsStore.accessToken;
    final local = await _cacheStore.readIndex();
    if (accessToken == null) {
      return SyncResult(channelId: null, entries: local, policy: null, assignedChannels: const []);
    }

    Map<String, dynamic>? firstPageData;
    final remoteItems = <RemoteMediaEntry>[];
    int? cursor;
    // Loops through get-media-batch's keyset pages until exhausted, so a
    // channel with more than one page's worth of assigned items still gets
    // synced in full, not just the first page.
    while (true) {
      http.Response response;
      try {
        response = await _httpClient.post(
          Uri.parse(BackendConfig.functionUrl('get-media-batch')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'access_token': accessToken,
            'fcm_token': ?fcmToken,
            'cursor': ?cursor,
          }),
        );
      } catch (_) {
        return SyncResult(channelId: null, entries: local, policy: null, assignedChannels: const []);
      }

      if (response.statusCode != 200) {
        return SyncResult(channelId: null, entries: local, policy: null, assignedChannels: const []);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      firstPageData ??= data;
      remoteItems.addAll(
        ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>().map((e) => RemoteMediaEntry(
              mediaItemId: e['media_item_id'] as String,
              mediaType: e['media_type'] as String,
              sortOrder: e['sort_order'] as int,
              displayUrl: e['display_url'] as String?,
            )),
      );
      cursor = data['next_cursor'] as int?;
      if (cursor == null) break;
    }
    final data = firstPageData;

    final diff = MediaCacheSync.diff(remoteItems, local);

    final newEntries = <CachedMediaEntry>[];
    for (final remote in diff.toDownload) {
      if (remote.displayUrl == null) continue;
      try {
        final downloadResponse = await _httpClient.get(Uri.parse(remote.displayUrl!));
        if (downloadResponse.statusCode != 200) continue;
        final fileName = '${remote.mediaItemId}.jpg';
        final file = await _cacheStore.fileFor(fileName);
        await file.writeAsBytes(downloadResponse.bodyBytes);
        newEntries.add(CachedMediaEntry(
          mediaItemId: remote.mediaItemId,
          mediaType: remote.mediaType,
          sortOrder: remote.sortOrder,
          fileName: fileName,
          fileSizeBytes: downloadResponse.bodyBytes.length,
          cachedAt: DateTime.now(),
        ));
      } catch (_) {
        // Skip this item this round; it's retried on the next sync since
        // it stays in toDownload until it succeeds.
      }
    }

    final deleteIds = diff.toDelete.map((e) => e.mediaItemId).toSet();
    for (final del in diff.toDelete) {
      await _cacheStore.deleteFile(del.fileName);
    }

    final remoteSortByMediaId = {for (final r in remoteItems) r.mediaItemId: r.sortOrder};
    final merged = [
      ...local.where((e) => !deleteIds.contains(e.mediaItemId)).map((e) {
        final newSort = remoteSortByMediaId[e.mediaItemId];
        return newSort != null ? e.copyWith(sortOrder: newSort) : e;
      }),
      ...newEntries,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final policyJson = data['policy'] as Map<String, dynamic>?;
    final policy = policyJson != null ? DevicePolicyInfo.fromJson(policyJson) : null;
    final maxBytes = policy?.maxLocalCacheGb != null ? (policy!.maxLocalCacheGb! * 1024 * 1024 * 1024).round() : null;

    final toEvict = MediaCacheSync.entriesToEvictForCap(merged, maxBytes);
    final evictIds = toEvict.map((e) => e.mediaItemId).toSet();
    for (final e in toEvict) {
      await _cacheStore.deleteFile(e.fileName);
    }
    final finalEntries = merged.where((e) => !evictIds.contains(e.mediaItemId)).toList();

    await _cacheStore.writeIndex(finalEntries);

    final assignedChannels = ((data['assigned_channels'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(AssignedChannel.fromJson)
        .toList();

    return SyncResult(
      channelId: data['channel_id'] as String?,
      entries: finalEntries,
      policy: policy,
      assignedChannels: assignedChannels,
      spaceName: data['space_name'] as String?,
    );
  }

  Future<void> _refreshIfNeeded() async {
    final expiresAt = await _credentialsStore.accessTokenExpiresAt;
    final deviceId = await _credentialsStore.deviceId;
    final refreshSecret = await _credentialsStore.refreshSecret;
    if (expiresAt == null || deviceId == null || refreshSecret == null) return;

    const totalTtl = Duration(hours: 1); // matches the backend's access-token TTL
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining > Duration(milliseconds: (totalTtl.inMilliseconds * 0.25).round())) return;

    try {
      final refreshed = await _pairingService.refreshToken(deviceId: deviceId, refreshSecret: refreshSecret);
      await _credentialsStore.saveRefreshedTokens(
        accessToken: refreshed.accessToken,
        accessTokenExpiresAt: refreshed.accessTokenExpiresAt,
        refreshSecret: refreshed.refreshSecret,
      );
    } catch (_) {
      // Keep using the still-valid old token; a transient refresh failure
      // shouldn't block this sync round.
    }
  }
}
