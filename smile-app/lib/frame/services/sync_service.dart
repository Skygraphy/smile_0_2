import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import 'frame_credentials_store.dart';
import 'media_cache_store.dart';
import 'media_cache_sync.dart';
import 'pairing_service.dart';

/// What the person in front of the Frame may do (migrations/0075): the
/// big buttons it shows. The app sets them, by a level or one by one.
class FrameControls {
  const FrameControls({
    this.next = false,
    this.back = false,
    this.pause = false,
    this.newest = false,
    this.favorite = false,
    this.favorites = false,
    this.overview = false,
    this.album = false,
    this.duration = false,
    this.playback = false,
    this.captions = false,
  });

  final bool next;
  final bool back;
  final bool pause;
  final bool newest;

  /// Mark a Lieblingsbild / play the Lieblingsbilder (migrations/0076).
  final bool favorite;
  final bool favorites;
  final bool overview;
  final bool album;
  final bool duration;
  final bool playback;

  /// The "Titel" button (migrations/0084, level 4).
  final bool captions;

  /// Level 1 "Nur zuschauen": touches are ignored.
  bool get any =>
      next || back || pause || newest || favorite || favorites || overview || album || duration || playback || captions;

  factory FrameControls.fromJson(Map<String, dynamic>? json) {
    bool on(String key) => json?[key] == true;
    return FrameControls(
      next: on('next'),
      back: on('back'),
      pause: on('pause'),
      newest: on('newest'),
      favorite: on('favorite'),
      favorites: on('favorites'),
      overview: on('overview'),
      album: on('album'),
      duration: on('duration'),
      playback: on('playback'),
      captions: on('captions'),
    );
  }
}

class FrameSettingsInfo {
  FrameSettingsInfo({
    required this.displayMode,
    required this.slideshowIntervalSeconds,
    required this.channelSwitchEnabled,
    this.videoSound = true,
    this.maxLocalCacheGb,
    this.controls,
    this.contentMode = 'album',
    this.recentCount = 20,
    this.playOrder = 'oldest',
    this.endBehavior = 'loop',
    this.showNewImmediately = true,
    this.showClock = false,
    this.showSender = true,
    this.quietFrom,
    this.quietTo,
    this.videoLength = 'full',
    this.fillMode = 'auto',
    this.slowZoom = true,
    this.rotateWithDevice = false,
    this.controlLevel,
    this.showCaptions = true,
  });

  final String displayMode; // 'slideshow' | 'manual'
  final int slideshowIntervalSeconds;
  final bool channelSwitchEnabled;

  /// Play videos with sound (per-Frame setting, migrations/0056). Absent
  /// from an older server response = true, the behavior before it existed.
  final bool videoSound;
  final double? maxLocalCacheGb;

  /// Null from a server older than migrations/0075: then what the Frame
  /// did before (overview, and album switching when allowed).
  final FrameControls? controls;

  /// 'album' | 'rotate' (all its albums in turn) | 'recent' (the newest
  /// [recentCount] of all its albums) | 'favorites' (its Lieblingsbilder).
  final String contentMode;
  final int recentCount;

  /// 'newest' | 'oldest' | 'shuffle'
  final String playOrder;

  /// 'loop' | 'overview' (shows the overview at the end)
  final String endBehavior;
  final bool showNewImmediately;
  final bool showClock;
  final bool showSender;

  /// Nachtruhe, "HH:MM[:SS]" in the Frame's local time; both null = off.
  final String? quietFrom;
  final String? quietTo;

  /// 'full' | 'photo' (a video only as long as a photo) -- migrations/0079.
  final String videoLength;

  /// 'fit' | 'auto' | 'fill' -- see SmileFillMode.
  final String fillMode;
  final bool slowZoom;

  /// Turn with the device even when its auto-rotate is off (2026-10-17).
  final bool rotateWithDevice;

  /// Bedienstufe 1-5, null = "Eigene Auswahl" (migrations/0075).
  final int? controlLevel;

  /// "Titel anzeigen" (migrations/0084).
  final bool showCaptions;

  FrameControls get effectiveControls =>
      controls ?? FrameControls(next: true, back: true, pause: true, overview: true, album: channelSwitchEnabled);

  factory FrameSettingsInfo.fromJson(Map<String, dynamic> json) => FrameSettingsInfo(
        displayMode: json['display_mode'] as String? ?? 'slideshow',
        slideshowIntervalSeconds: json['slideshow_interval_seconds'] as int? ?? 8,
        channelSwitchEnabled: json['channel_switch_enabled'] as bool? ?? false,
        videoSound: json['video_sound'] as bool? ?? true,
        maxLocalCacheGb: (json['max_local_cache_gb'] as num?)?.toDouble(),
        controls: json['controls'] is Map ? FrameControls.fromJson((json['controls'] as Map).cast<String, dynamic>()) : null,
        contentMode: json['content_mode'] as String? ?? 'album',
        recentCount: json['recent_count'] as int? ?? 20,
        playOrder: json['play_order'] as String? ?? 'oldest',
        endBehavior: json['end_behavior'] as String? ?? 'loop',
        showNewImmediately: json['show_new_immediately'] as bool? ?? true,
        showClock: json['show_clock'] as bool? ?? false,
        showSender: json['show_sender'] as bool? ?? true,
        quietFrom: json['quiet_from'] as String?,
        quietTo: json['quiet_to'] as String?,
        videoLength: json['video_length'] as String? ?? 'full',
        fillMode: json['fill_mode'] as String? ?? 'auto',
        slowZoom: json['slow_zoom'] as bool? ?? true,
        rotateWithDevice: json['rotate_with_device'] as bool? ?? false,
        controlLevel: json['control_level'] as int?,
        showCaptions: json['show_captions'] as bool? ?? true,
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
    this.allEntries = const [],
    this.favorites,
    required this.settings,
    required this.assignedChannels,
    this.spaceName,
    this.deactivated = false,
    this.unpaired = false,
    this.offlineExpired = false,
    this.offline = false,
  });

  /// The server reports this Frame as revoked (frame_not_active) -- the
  /// local cache has already been wiped; show nothing but a notice until
  /// the Space owner reactivates it.
  SyncResult.deactivated()
      : channelId = null,
        entries = const [],
        allEntries = const [],
        favorites = null,
        settings = null,
        assignedChannels = const [],
        spaceName = null,
        deactivated = true,
        unpaired = false,
        offlineExpired = false,
        offline = false;

  /// The Frame record no longer exists (its Space was deleted) -- cache AND
  /// credentials are gone; the app has to go back to pairing.
  SyncResult.unpaired()
      : channelId = null,
        entries = const [],
        allEntries = const [],
        favorites = null,
        settings = null,
        assignedChannels = const [],
        spaceName = null,
        deactivated = false,
        unpaired = true,
        offlineExpired = false,
        offline = false;

  /// No successful sync for longer than SyncService.maxOffline -- the
  /// photos are wiped until the Frame reaches the server again.
  SyncResult.offlineExpired()
      : channelId = null,
        entries = const [],
        allEntries = const [],
        favorites = null,
        settings = null,
        assignedChannels = const [],
        spaceName = null,
        deactivated = false,
        unpaired = false,
        offlineExpired = true,
        offline = false;

  final String? channelId;
  final List<CachedMediaEntry> entries;

  /// Every album's cached photos -- for "Aktuelles", "Mehrere im Wechsel"
  /// and a photo shown from the app's remote control (2026-10-14).
  final List<CachedMediaEntry> allEntries;

  /// The Frame's Lieblingsbilder (media ids, newest marked first); null
  /// when not known (an older server, nothing synced yet).
  final List<String>? favorites;
  final FrameSettingsInfo? settings;
  final List<AssignedChannel> assignedChannels;
  final String? spaceName;
  final bool deactivated;
  final bool unpaired;
  final bool offlineExpired;

  /// The server couldn't be reached: cached photos, and the settings and
  /// albums from the last successful sync. Switching albums needs the
  /// server, so it is off meanwhile.
  final bool offline;
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

  /// A Personal-Mode pick on the Frame (gated by `channel_switch_enabled`).
  /// Since migrations/0069 the server keeps the Frame's current album (the
  /// app can switch it too), so the pick is only kept until the next sync
  /// has reported it. Caller still has to trigger a `sync()` afterwards.
  Future<void> selectChannel(String channelId) => _credentialsStore.savePreferredChannelId(channelId);

  /// A setting changed on the Frame itself (display time, playback):
  /// sent with the next sync, which the caller triggers. The server only
  /// takes what the Frame's controls allow (get-media-batch).
  void changeSettings(Map<String, Object?> settings) => _pendingSettings.addAll(settings);
  final Map<String, Object?> _pendingSettings = {};

  /// A Lieblingsbild marked (true) or taken back (false) on the Frame: sent
  /// one per sync, which the caller triggers; more waiting run another.
  void markFavorite(String mediaItemId, bool on) {
    _pendingFavorites.remove(mediaItemId);
    _pendingFavorites[mediaItemId] = on;
  }

  final Map<String, bool> _pendingFavorites = {};

  /// The round played right now ("newest", "favorites", null): sent with the
  /// next sync, so the app can show it (migrations/0077).
  void reportRound(String? round) {
    _pendingRound = round;
    _roundPending = true;
  }

  String? _pendingRound;
  bool _roundPending = false;

  /// Marks not yet sent -- shown as they will be.
  Map<String, bool> get pendingFavorites => Map.unmodifiable(_pendingFavorites);

  static List<String>? _favoritesFrom(Map<String, dynamic>? data) => (data?['favorites'] as List?)?.cast<String>();

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
    // Keep what the last successful sync said (2026-10-09): offline, the
    // Frame used to forget its albums and settings -- album switching was
    // blocked and sound/display mode fell back to their defaults.
    final meta = await _readLastMeta();
    // All albums are cached (2026-10-09): offline, a pick on the Frame
    // shows that album at once; the server hears of it once it's back.
    final shown = await _credentialsStore.preferredChannelId ?? meta?['channel_id'] as String?;
    return SyncResult(
      channelId: shown,
      entries: _entriesOf(local, shown),
      allEntries: local,
      favorites: _favoritesFrom(meta),
      settings: _settingsFrom(meta),
      assignedChannels: _assignedFrom(meta),
      spaceName: meta?['space_name'] as String?,
      offline: true,
    );
  }

  /// The cached photos of [channelId] -- plus any cached before albums
  /// were told apart (no album yet; sorted out by the next online sync).
  static List<CachedMediaEntry> _entriesOf(List<CachedMediaEntry> all, String? channelId) =>
      all.where((e) => e.channelId == null || e.channelId == channelId).toList();

  /// What to show before the first sync of a session: the cached photos
  /// of the album shown last (or picked meanwhile).
  Future<List<CachedMediaEntry>> cachedShownEntries() async {
    final meta = await _readLastMeta();
    final shown = await _credentialsStore.preferredChannelId ?? meta?['channel_id'] as String?;
    return _entriesOf(await _cacheStore.readIndex(), shown);
  }

  Future<Map<String, dynamic>?> _readLastMeta() async {
    try {
      final raw = await _credentialsStore.lastSyncMeta;
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static FrameSettingsInfo? _settingsFrom(Map<String, dynamic>? data) {
    final json = data?['settings'] as Map<String, dynamic>?;
    return json == null ? null : FrameSettingsInfo.fromJson(json);
  }

  static List<AssignedChannel> _assignedFrom(Map<String, dynamic>? data) =>
      ((data?['assigned_channels'] as List?) ?? []).cast<Map<String, dynamic>>().map(AssignedChannel.fromJson).toList();

  Future<void> _deleteEntryFiles(CachedMediaEntry entry) async {
    await _cacheStore.deleteFile(entry.fileName);
    if (entry.posterFileName != null) await _cacheStore.deleteFile(entry.posterFileName!);
  }

  Future<SyncResult>? _running;

  /// Called as soon as the server's first answer is in -- settings, the
  /// shown album and its already cached photos -- before the other albums
  /// are fetched and anything is downloaded. A change from the app (sound,
  /// album switch) then shows within 2-3 seconds instead of after the whole
  /// sync (2026-10-09). The final result follows from sync() as usual.
  void Function(SyncResult early)? onEarlyResult;

  /// One sync at a time: downloading a long video can take minutes, and a
  /// timer tick or push arriving meanwhile must not start a second run
  /// writing the same files. But that run asked the server before the new
  /// change -- so it runs once more right after (several requests in the
  /// meantime count as one), and every caller gets the latest result.
  /// Before 2026-10-09 such a change (e.g. sound off) was only picked up
  /// by the next sync, up to 2 minutes later.
  Future<SyncResult> sync({String? fcmToken}) {
    if (_running != null) {
      _syncAgain = true;
      return _running!;
    }
    return _running = _syncUntilCurrent(fcmToken).whenComplete(() {
      _running = null;
    });
  }

  bool _syncAgain = false;

  Future<SyncResult> _syncUntilCurrent(String? fcmToken) async {
    while (true) {
      _syncAgain = false;
      final result = await _sync(fcmToken: fcmToken);
      // Unpaired or revoked: final -- another round would find no
      // credentials and hide it behind an empty "offline" result
      // (2026-10-16: the kitchen Frame stayed on "Noch keine Fotos").
      if (result.unpaired || result.deactivated) return result;
      if (!_syncAgain) return result;
    }
  }

  Future<SyncResult> _sync({String? fcmToken}) async {
    final refresh = await _refreshIfNeeded();
    if (refresh == _RefreshOutcome.frameNotFound) return _unpair();
    if (refresh == _RefreshOutcome.frameNotActive) return _deactivate();

    final accessToken = await _credentialsStore.accessToken;
    final local = await _cacheStore.readIndex();
    if (accessToken == null) return _offlineFallback(local);

    // A switch made on the Frame since the last sync (also an old build's
    // stored pick): reported once, then the server's choice applies.
    final pickedChannelId = await _credentialsStore.preferredChannelId;
    final settingsToSend = Map<String, Object?>.of(_pendingSettings);
    final favoriteToSend = _pendingFavorites.entries.firstOrNull;
    final roundPending = _roundPending;
    final roundToSend = _pendingRound;
    var page = await _fetchAllPages(
      accessToken: accessToken,
      fcmToken: fcmToken,
      selectChannelId: pickedChannelId,
      setSettings: settingsToSend,
      favorite: favoriteToSend,
      round: roundPending ? (value: roundToSend,) : null,
    );
    if (!page.failed && roundPending && _pendingRound == roundToSend) _roundPending = false;
    if (!page.failed && favoriteToSend != null) {
      if (_pendingFavorites[favoriteToSend.key] == favoriteToSend.value) _pendingFavorites.remove(favoriteToSend.key);
      if (_pendingFavorites.isNotEmpty) _syncAgain = true;
    }
    if (!page.failed && settingsToSend.isNotEmpty) {
      settingsToSend.forEach((key, value) {
        if (_pendingSettings[key] == value) _pendingSettings.remove(key);
      });
    }
    if (page.notAssignedToChosenChannel) {
      // The picked channel is no longer assigned to this Frame -- drop the
      // pick and take the server's choice.
      await _credentialsStore.clearPreferredChannelId();
      page = await _fetchAllPages(accessToken: accessToken, fcmToken: fcmToken, selectChannelId: null);
    } else if (pickedChannelId != null && !page.failed) {
      await _credentialsStore.clearPreferredChannelId();
    }
    if (page.frameNotFound) return _unpair();
    if (page.frameNotActive) return _deactivate();
    if (page.failed) return _offlineFallback(local);
    await _credentialsStore.saveLastSyncOkAt(DateTime.now());
    final data = page.firstPageData!;
    final currentChannelId = data['channel_id'] as String?;
    final assignedChannels = _assignedFrom(data);
    // The shown album's titles (and senders) from this first answer already
    // -- a changed title used to wait until every album was synced
    // (2026-10-18).
    final firstById = {for (final r in page.items) r.mediaItemId: r};
    final early = [
      for (final e in local)
        if (firstById[e.mediaItemId] case final remote?) e.refreshedFrom(remote) else e,
    ];
    onEarlyResult?.call(SyncResult(
      channelId: currentChannelId,
      entries: early.where((e) => e.channelId == currentChannelId).toList(),
      allEntries: early,
      favorites: _favoritesFrom(data),
      settings: _settingsFrom(data),
      assignedChannels: assignedChannels,
      spaceName: data['space_name'] as String?,
    ));

    // Every other album of this Frame too, so it can switch between them
    // offline (2026-10-09). An album that couldn't be fetched this round
    // keeps its cached photos until the next one.
    final remoteItems = [...page.items];
    final fetchedChannels = <String>{?currentChannelId};
    // All at once, not one after the other: a sync used to take several
    // seconds this way, and a change from the app waited behind it.
    final others = assignedChannels.where((album) => album.channelId != currentChannelId).toList();
    final otherPages = await Future.wait(others.map((album) => _fetchAllPages(
          accessToken: accessToken,
          fcmToken: null,
          selectChannelId: null,
          fetchChannelId: album.channelId,
        )));
    for (final (index, other) in otherPages.indexed) {
      if (other.failed || other.firstPageData == null) continue;
      remoteItems.addAll(other.items);
      fetchedChannels.add(others[index].channelId);
    }
    final assignedIds = assignedChannels.map((c) => c.channelId).toSet();

    final diff = MediaCacheSync.diff(remoteItems, local);
    // Gone from the server -- unless its album just couldn't be fetched.
    final toDelete = diff.toDelete
        .where((e) => !(e.channelId != null && assignedIds.contains(e.channelId) && !fetchedChannels.contains(e.channelId)))
        .toList();
    // The shown album first: it's what is on screen.
    final toDownload = [...diff.toDownload]
      ..sort((a, b) => (a.channelId == currentChannelId ? 0 : 1).compareTo(b.channelId == currentChannelId ? 0 : 1));

    final newEntries = <CachedMediaEntry>[];
    for (final remote in toDownload) {
      // A newer change is waiting (sync() was called again): see to it
      // first; what's left here is downloaded next round.
      if (_syncAgain) break;
      if (remote.displayUrl == null) continue;
      try {
        // Streamed straight into the encrypted cache -- an hour-long video
        // (decision 2026-10-01) never has to fit in memory.
        final response =
            await _httpClient.send(http.Request('GET', Uri.parse(remote.displayUrl!))).timeout(BackendConfig.requestTimeout);
        if (response.statusCode != 200) {
          await response.stream.drain<void>();
          continue;
        }
        final isVideo = remote.mediaType == 'video';
        final fileName = '${remote.mediaItemId}.${isVideo ? 'mp4' : 'jpg'}';
        final size = await _cacheStore.writeMediaStream(
          fileName,
          response.stream.timeout(BackendConfig.downloadStallTimeout),
        );
        String? posterFileName;
        if (isVideo && remote.posterUrl != null) {
          final poster = await _httpClient.get(Uri.parse(remote.posterUrl!)).timeout(BackendConfig.requestTimeout);
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
          channelId: remote.channelId,
          senderName: remote.senderName,
          caption: remote.caption,
        ));
        // A photo of the shown album is there: on screen at once, not only
        // after every album is downloaded (2026-10-16: a newly connected
        // Frame said "noch keine Fotos" for a minute).
        if (remote.channelId == currentChannelId) {
          onEarlyResult?.call(SyncResult(
            channelId: currentChannelId,
            entries: [...local, ...newEntries].where((e) => e.channelId == currentChannelId).toList(),
            allEntries: [...local, ...newEntries],
            settings: _settingsFrom(data),
            assignedChannels: assignedChannels,
            spaceName: data['space_name'] as String?,
            favorites: _favoritesFrom(data),
          ));
        }
      } catch (_) {
        // Skip this item this round; it's retried on the next sync since
        // it stays in toDownload until it succeeds.
      }
    }

    final deleteIds = toDelete.map((e) => e.mediaItemId).toSet();
    for (final del in toDelete) {
      await _deleteEntryFiles(del);
    }

    final remoteByMediaId = {for (final r in remoteItems) r.mediaItemId: r};
    final merged = [
      ...local.where((e) => !deleteIds.contains(e.mediaItemId)).map((e) {
        final remote = remoteByMediaId[e.mediaItemId];
        return remote != null
            ? e.refreshedFrom(remote)
            : e;
      }),
      ...newEntries,
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final settings = _settingsFrom(data);
    final maxBytes = settings?.maxLocalCacheGb != null ? (settings!.maxLocalCacheGb! * 1024 * 1024 * 1024).round() : null;

    final toEvict = MediaCacheSync.entriesToEvictForCap(merged, maxBytes, keepChannelId: currentChannelId);
    final evictIds = toEvict.map((e) => e.mediaItemId).toSet();
    for (final e in toEvict) {
      await _deleteEntryFiles(e);
    }
    final finalEntries = merged.where((e) => !evictIds.contains(e.mediaItemId)).toList();

    await _cacheStore.writeIndex(finalEntries);

    await _credentialsStore.saveLastSyncMeta(jsonEncode({
      'channel_id': data['channel_id'],
      'settings': data['settings'],
      'assigned_channels': data['assigned_channels'],
      'space_name': data['space_name'],
      'favorites': data['favorites'],
    }));

    return SyncResult(
      channelId: currentChannelId,
      entries: finalEntries.where((e) => e.channelId == currentChannelId).toList(),
      allEntries: finalEntries,
      favorites: _favoritesFrom(data),
      settings: settings,
      assignedChannels: assignedChannels,
      spaceName: data['space_name'] as String?,
    );
  }

  /// Loops through get-media-batch's keyset pages until exhausted, so a
  /// channel with more than one page's worth of assigned items still gets
  /// synced in full, not just the first page. [selectChannelId] is a
  /// Personal-Mode pick to report (first page only); otherwise the server
  /// decides (its stored current album, see migrations/0069). Later pages
  /// ask for the album the first page answered with.
  Future<_PageFetchResult> _fetchAllPages({
    required String accessToken,
    required String? fcmToken,
    required String? selectChannelId,
    String? fetchChannelId,
    Map<String, Object?> setSettings = const {},
    MapEntry<String, bool>? favorite,
    ({String? value})? round,
  }) async {
    String? channelId;
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
            if (cursor == null) 'select_channel_id': ?selectChannelId,
            if (cursor == null) 'fetch_channel_id': ?fetchChannelId,
            if (cursor == null && setSettings.isNotEmpty) 'set_settings': setSettings,
            if (cursor == null && favorite != null) 'favorite': {'media_item_id': favorite.key, 'on': favorite.value},
            if (cursor == null && round != null) 'playing_round': round.value,
            if (cursor != null) 'channel_id': ?channelId,
            'cursor': ?cursor,
          }),
        ).timeout(BackendConfig.requestTimeout);
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
        if (selectChannelId != null && data?['error'] == 'frame_not_assigned_to_channel') {
          return _PageFetchResult.notAssigned();
        }
      }
      if (response.statusCode != 200) {
        return _PageFetchResult.failed();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      firstPageData ??= data;
      channelId ??= data['channel_id'] as String?;
      remoteItems.addAll(
        ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>().map((e) => RemoteMediaEntry(
              mediaItemId: e['media_item_id'] as String,
              mediaType: e['media_type'] as String,
              sortOrder: e['sort_order'] as int,
              displayUrl: e['display_url'] as String?,
              posterUrl: e['poster_url'] as String?,
              channelId: data['channel_id'] as String?,
              senderName: e['sender_name'] as String?,
              caption: e['caption'] as String?,
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
      // Locked out for good (2026-10-15: the kitchen Frame showed only its
      // cache for days): its secret is no longer known to the server. Back
      // to the start, so it can be connected again -- but only if no other
      // sync (the background one) has rotated the secret meanwhile, and its
      // access is over anyway.
      if ((e.code == 'invalid_refresh_secret' || e.code == 'no_credentials') &&
          await _credentialsStore.refreshSecret == refreshSecret &&
          expiresAt.isBefore(DateTime.now())) {
        return _RefreshOutcome.frameNotFound;
      }
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
