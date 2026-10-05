import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import 'frame_credentials_store.dart';
import 'media_cache_store.dart';
import 'media_cache_sync.dart';
import 'pairing_service.dart';

class FrameSettingsInfo {
  FrameSettingsInfo({
    required this.displayMode,
    required this.slideshowIntervalSeconds,
    required this.channelSwitchEnabled,
    this.videoSound = true,
    this.maxLocalCacheGb,
  });

  final String displayMode; // 'slideshow' | 'manual'
  final int slideshowIntervalSeconds;
  final bool channelSwitchEnabled;

  /// Play videos with sound (per-Frame setting, migrations/0056). Absent
  /// from an older server response = true, the behavior before it existed.
  final bool videoSound;
  final double? maxLocalCacheGb;

  factory FrameSettingsInfo.fromJson(Map<String, dynamic> json) => FrameSettingsInfo(
        displayMode: json['display_mode'] as String? ?? 'slideshow',
        slideshowIntervalSeconds: json['slideshow_interval_seconds'] as int? ?? 8,
        channelSwitchEnabled: json['channel_switch_enabled'] as bool? ?? false,
        videoSound: json['video_sound'] as bool? ?? true,
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
    required this.settings,
    required this.assignedChannels,
    this.spaceName,
    this.deactivated = false,
    this.unpaired = false,
    this.offlineExpired = false,
  });

  /// The server reports this Frame as revoked (frame_not_active) -- the
  /// local cache has already been wiped; show nothing but a notice until
  /// the Space owner reactivates it.
  SyncResult.deactivated()
      : channelId = null,
        entries = const [],
        settings = null,
        assignedChannels = const [],
        spaceName = null,
        deactivated = true,
        unpaired = false,
        offlineExpired = false;

  /// The Frame record no longer exists (its Space was deleted) -- cache AND
  /// credentials are gone; the app has to go back to pairing.
  SyncResult.unpaired()
      : channelId = null,
        entries = const [],
        settings = null,
        assignedChannels = const [],
        spaceName = null,
        deactivated = false,
        unpaired = true,
        offlineExpired = false;

  /// No successful sync for longer than SyncService.maxOffline -- the
  /// photos are wiped until the Frame reaches the server again.
  SyncResult.offlineExpired()
      : channelId = null,
        entries = const [],
        settings = null,
        assignedChannels = const [],
        spaceName = null,
        deactivated = false,
        unpaired = false,
        offlineExpired = true;

  final String? channelId;
  final List<CachedMediaEntry> entries;
  final FrameSettingsInfo? settings;
  final List<AssignedChannel> assignedChannels;
  final String? spaceName;
  final bool deactivated;
  final bool unpaired;
  final bool offlineExpired;
}

/// Orchestrates one sync round: refresh the access token if it's close to
/// expiry, call get-media-batch, diff against the local cache, download
/// what's new, evict what's gone (and whatever's over the settings' byte
/// cap), persist the updated index. A failed network call falls back to
/// whatever is already cached -- offline tolerance.
class SyncService {
  SyncService({
    PairingService? pairingService,
    FrameCredentialsStore? credentialsStore,
    MediaCacheStore? cacheStore,
    http.Client? httpClient,
  })  : _pairingService = pairingService ?? PairingService(),
        _credentialsStore = credentialsStore ?? FrameCredentialsStore(),
        _cacheStore = cacheStore ?? MediaCacheStore(),
        _httpClient = httpClient ?? http.Client();

  final PairingService _pairingService;
  final FrameCredentialsStore _credentialsStore;
  final MediaCacheStore _cacheStore;
  final http.Client _httpClient;

  /// Persists the Personal-Mode-picked channel (see frame_settings_screen.dart
  /// on the Smile-App side for how a Frame gets assigned to more than one
  /// channel, and the `channel_switch_enabled` setting gate). Caller still
  /// has to trigger a `sync()` afterwards to actually pick up the new
  /// channel's content.
  Future<void> selectChannel(String channelId) => _credentialsStore.savePreferredChannelId(channelId);

  /// How long a Frame keeps showing its photos without reaching the
  /// server (architecture review 2026-09-29, weakness 7). Without this, a
  /// revoked -- or stolen -- Frame kept offline showed them forever, since
  /// it never heard that it was revoked. Long enough for a holiday-length
  /// WLAN outage; the photos come back by themselves once it is online.
  static const maxOffline = Duration(days: 7);

  /// True once the offline limit has passed -- the screen then shows no
  /// cached photos even before the first sync attempt of a session.
  Future<bool> isOfflineExpired() async {
    final lastOk = await _credentialsStore.lastSyncOkAt;
    return lastOk != null && DateTime.now().difference(lastOk) > maxOffline;
  }

  Future<SyncResult> _offlineFallback(List<CachedMediaEntry> local) async {
    if (await isOfflineExpired()) {
      await _wipeCache();
      return SyncResult.offlineExpired();
    }
    return SyncResult(channelId: null, entries: local, settings: null, assignedChannels: const []);
  }

  Future<void> _deleteEntryFiles(CachedMediaEntry entry) async {
    await _cacheStore.deleteFile(entry.fileName);
    if (entry.posterFileName != null) await _cacheStore.deleteFile(entry.posterFileName!);
  }

  Future<SyncResult>? _running;

  /// One sync at a time: downloading a long video can take minutes, and a
  /// timer tick or push arriving meanwhile must not start a second run
  /// writing the same files -- it simply gets the running one's result.
  Future<SyncResult> sync({String? fcmToken}) {
    return _running ??= _sync(fcmToken: fcmToken).whenComplete(() => _running = null);
  }

  Future<SyncResult> _sync({String? fcmToken}) async {
    final refresh = await _refreshIfNeeded();
    if (refresh == _RefreshOutcome.frameNotFound) return _unpair();
    if (refresh == _RefreshOutcome.frameNotActive) return _deactivate();

    final accessToken = await _credentialsStore.accessToken;
    final local = await _cacheStore.readIndex();
    if (accessToken == null) return _offlineFallback(local);

    final preferredChannelId = await _credentialsStore.preferredChannelId;
    var page = await _fetchAllPages(accessToken: accessToken, fcmToken: fcmToken, channelIdOverride: preferredChannelId);
    if (page.notAssignedToChosenChannel) {
      // The channel this Frame was switched to (Personal Mode) is no
      // longer assigned to it -- fall back to the server default instead
      // of getting permanently stuck requesting a channel that's gone.
      await _credentialsStore.clearPreferredChannelId();
      page = await _fetchAllPages(accessToken: accessToken, fcmToken: fcmToken, channelIdOverride: null);
    }
    if (page.frameNotFound) return _unpair();
    if (page.frameNotActive) return _deactivate();
    if (page.failed) return _offlineFallback(local);
    await _credentialsStore.saveLastSyncOkAt(DateTime.now());
    final data = page.firstPageData!;
    final remoteItems = page.items;

    final diff = MediaCacheSync.diff(remoteItems, local);

    final newEntries = <CachedMediaEntry>[];
    for (final remote in diff.toDownload) {
      if (remote.displayUrl == null) continue;
      try {
        // Streamed straight into the encrypted cache -- an hour-long video
        // (decision 2026-10-01) never has to fit in memory.
        final response = await _httpClient.send(http.Request('GET', Uri.parse(remote.displayUrl!)));
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          continue;
        }
        final isVideo = remote.mediaType == 'video';
        final fileName = '${remote.mediaItemId}.${isVideo ? 'mp4' : 'jpg'}';
        final size = await _cacheStore.writeMediaStream(fileName, response.stream);
        String? posterFileName;
        if (isVideo && remote.posterUrl != null) {
          final poster = await _httpClient.get(Uri.parse(remote.posterUrl!));
          if (poster.statusCode == 200) {
            posterFileName = '${remote.mediaItemId}_poster.jpg';
            await _cacheStore.writeMedia(posterFileName, poster.bodyBytes);
          }
        }
        newEntries.add(CachedMediaEntry(
          mediaItemId: remote.mediaItemId,
          mediaType: remote.mediaType,
          sortOrder: remote.sortOrder,
          fileName: fileName,
          fileSizeBytes: size,
          cachedAt: DateTime.now(),
          posterFileName: posterFileName,
        ));
      } catch (_) {
        // Skip this item this round; it's retried on the next sync since
        // it stays in toDownload until it succeeds.
      }
    }

    final deleteIds = diff.toDelete.map((e) => e.mediaItemId).toSet();
    for (final del in diff.toDelete) {
      await _deleteEntryFiles(del);
    }

    final remoteSortByMediaId = {for (final r in remoteItems) r.mediaItemId: r.sortOrder};
    final merged = [
      ...local.where((e) => !deleteIds.contains(e.mediaItemId)).map((e) {
        final newSort = remoteSortByMediaId[e.mediaItemId];
        return newSort != null ? e.copyWith(sortOrder: newSort) : e;
      }),
      ...newEntries,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final settingsJson = data['settings'] as Map<String, dynamic>?;
    final settings = settingsJson != null ? FrameSettingsInfo.fromJson(settingsJson) : null;
    final maxBytes = settings?.maxLocalCacheGb != null ? (settings!.maxLocalCacheGb! * 1024 * 1024 * 1024).round() : null;

    final toEvict = MediaCacheSync.entriesToEvictForCap(merged, maxBytes);
    final evictIds = toEvict.map((e) => e.mediaItemId).toSet();
    for (final e in toEvict) {
      await _deleteEntryFiles(e);
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
      settings: settings,
      assignedChannels: assignedChannels,
      spaceName: data['space_name'] as String?,
    );
  }

  /// Loops through get-media-batch's keyset pages until exhausted, so a
  /// channel with more than one page's worth of assigned items still gets
  /// synced in full, not just the first page. [channelIdOverride] is the
  /// Personal-Mode-picked channel (see FrameCredentialsStore), if any --
  /// omitted, the server falls back to its own default (first-assigned).
  Future<_PageFetchResult> _fetchAllPages({
    required String accessToken,
    required String? fcmToken,
    required String? channelIdOverride,
  }) async {
    Map<String, dynamic>? firstPageData;
    final remoteItems = <RemoteMediaEntry>[];
    int? cursor;
    while (true) {
      http.Response response;
      try {
        response = await _httpClient.post(
          Uri.parse(BackendConfig.functionUrl('get-media-batch')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'access_token': accessToken,
            'fcm_token': ?fcmToken,
            'channel_id': ?channelIdOverride,
            'cursor': ?cursor,
          }),
        );
      } catch (_) {
        return _PageFetchResult.failed();
      }

      if (response.statusCode == 403) {
        Map<String, dynamic>? data;
        try {
          data = jsonDecode(response.body) as Map<String, dynamic>?;
        } catch (_) {}
        if (data?['error'] == 'frame_not_found') return _PageFetchResult.notFound();
        if (data?['error'] == 'frame_not_active') return _PageFetchResult.notActive();
        if (channelIdOverride != null && data?['error'] == 'frame_not_assigned_to_channel') {
          return _PageFetchResult.notAssigned();
        }
      }
      if (response.statusCode != 200) {
        return _PageFetchResult.failed();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      firstPageData ??= data;
      remoteItems.addAll(
        ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>().map((e) => RemoteMediaEntry(
              mediaItemId: e['media_item_id'] as String,
              mediaType: e['media_type'] as String,
              sortOrder: e['sort_order'] as int,
              displayUrl: e['display_url'] as String?,
              posterUrl: e['poster_url'] as String?,
            )),
      );
      cursor = data['next_cursor'] as int?;
      if (cursor == null) break;
    }
    return _PageFetchResult(firstPageData: firstPageData, items: remoteItems);
  }

  /// Revoked from the Smile-App ("Frame widerrufen"): the promise there is
  /// that the Frame loses access to the photos immediately -- so falling
  /// back to the offline cache (right for a mere network failure) would be
  /// exactly wrong here. Wipe every cached file; credentials are kept so a
  /// later "Wieder aktivieren" resumes without re-pairing.
  Future<SyncResult> _deactivate() async {
    await _wipeCache();
    return SyncResult.deactivated();
  }

  Future<SyncResult> _unpair() async {
    await _wipeCache();
    await _credentialsStore.clear();
    return SyncResult.unpaired();
  }

  Future<void> _wipeCache() async {
    for (final entry in await _cacheStore.readIndex()) {
      await _deleteEntryFiles(entry);
    }
    await _cacheStore.writeIndex(const []);
  }

  Future<_RefreshOutcome> _refreshIfNeeded() async {
    final expiresAt = await _credentialsStore.accessTokenExpiresAt;
    final frameId = await _credentialsStore.frameId;
    final refreshSecret = await _credentialsStore.refreshSecret;
    if (expiresAt == null || frameId == null || refreshSecret == null) return _RefreshOutcome.skipped;

    const totalTtl = Duration(hours: 1); // matches the backend's access-token TTL
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining > Duration(milliseconds: (totalTtl.inMilliseconds * 0.25).round())) return _RefreshOutcome.skipped;

    try {
      final refreshed = await _pairingService.refreshToken(frameId: frameId, refreshSecret: refreshSecret);
      await _credentialsStore.saveRefreshedTokens(
        accessToken: refreshed.accessToken,
        accessTokenExpiresAt: refreshed.accessTokenExpiresAt,
        refreshSecret: refreshed.refreshSecret,
      );
      return _RefreshOutcome.refreshed;
    } on PairingException catch (e) {
      // A revoked Frame can't refresh either -- and once its access token
      // has expired, get-media-batch can only say "invalid token", so this
      // is the one place that still learns *why*.
      if (e.code == 'frame_not_found') return _RefreshOutcome.frameNotFound;
      if (e.code == 'frame_not_active') return _RefreshOutcome.frameNotActive;
      return _RefreshOutcome.failed;
    } catch (_) {
      // Keep using the still-valid old token; a transient refresh failure
      // shouldn't block this sync round.
      return _RefreshOutcome.failed;
    }
  }
}

enum _RefreshOutcome { skipped, refreshed, failed, frameNotActive, frameNotFound }

class _PageFetchResult {
  _PageFetchResult({this.firstPageData, this.items = const []})
      : failed = false,
        notAssignedToChosenChannel = false,
        frameNotActive = false,
        frameNotFound = false;

  _PageFetchResult.failed()
      : firstPageData = null,
        items = const [],
        failed = true,
        notAssignedToChosenChannel = false,
        frameNotActive = false,
        frameNotFound = false;

  _PageFetchResult.notAssigned()
      : firstPageData = null,
        items = const [],
        failed = false,
        notAssignedToChosenChannel = true,
        frameNotActive = false,
        frameNotFound = false;

  _PageFetchResult.notActive()
      : firstPageData = null,
        items = const [],
        failed = false,
        notAssignedToChosenChannel = false,
        frameNotActive = true,
        frameNotFound = false;

  _PageFetchResult.notFound()
      : firstPageData = null,
        items = const [],
        failed = false,
        notAssignedToChosenChannel = false,
        frameNotActive = false,
        frameNotFound = true;

  final Map<String, dynamic>? firstPageData;
  final List<RemoteMediaEntry> items;
  final bool failed;
  final bool notAssignedToChosenChannel;
  final bool frameNotActive;
  final bool frameNotFound;
}
