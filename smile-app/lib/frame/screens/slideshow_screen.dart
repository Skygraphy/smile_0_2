import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/heartbeat_service.dart';
import '../services/media_cache_store.dart';
import '../services/media_cache_sync.dart';
import '../services/push_service.dart';
import '../services/push_sync_signal.dart';
import '../services/sync_service.dart';
import 'video_slide.dart';

/// The Frame's actual display. What it plays and how comes from the app
/// (the Frame's row, migrations/0031 and 0075): one album, all albums in
/// turn or the newest photos; order, display time, end of the round, clock,
/// sender, Nachtruhe. What the person in front of it may do is its control
/// level: a tap brings up big buttons for exactly that (2026-10-14) --
/// on level 1 ("Nur zuschauen") a tap does nothing. The app's remote
/// control reaches it as push commands (PushSyncSignal.onCommand).
///
/// Renders only from the local cache; syncing (get-media-batch, download,
/// evict) is a separate periodic concern layered on top, so the display
/// never blocks on network and stays up fully offline once something is
/// cached.
class SlideshowScreen extends StatefulWidget {
  SlideshowScreen({
    super.key,
    SyncService? syncService,
    MediaCacheStore? cacheStore,
    HeartbeatService? heartbeatService,
    PushService? pushService,
    this.onUnpaired,
  })  : syncService = syncService ?? SyncService(),
        cacheStore = cacheStore ?? MediaCacheStore(),
        heartbeatService = heartbeatService ?? HeartbeatService(),
        pushService = pushService ?? PushService();

  final SyncService syncService;
  final MediaCacheStore cacheStore;

  /// This Frame was deleted (its Space was deleted) -- credentials are
  /// already cleared; StartupGate re-checks and shows pairing again.
  final VoidCallback? onUnpaired;
  final HeartbeatService heartbeatService;
  final PushService pushService;

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> with WidgetsBindingObserver {
  static const _syncInterval = Duration(minutes: 2);
  static const _window = MethodChannel('smile/frame_window');

  /// The shown album's photos and every album's (for "Aktuelles", "Alle
  /// Alben im Wechsel" and a photo sent from the remote control).
  List<CachedMediaEntry> _albumEntries = [];
  List<CachedMediaEntry> _allEntries = [];

  /// What actually plays, in order -- built from the two above and the
  /// settings (_rebuildPlaylist).
  List<CachedMediaEntry> _playlist = [];
  FrameSettingsInfo? _settings;
  String? _cacheDirPath;
  String? _currentChannelId;
  List<AssignedChannel> _assignedChannels = [];
  String? _fcmToken;
  int _currentIndex = 0;
  Timer? _syncTimer;
  Timer? _advanceTimer;
  // Offline, the next attempt comes much sooner than the regular 2 minutes,
  // so album switching is back right after WLAN returns (2026-10-09).
  Timer? _offlineRetryTimer;
  static const _offlineRetryInterval = Duration(seconds: 10);
  bool _loadedOnce = false;
  // Revoked in the Smile-App -- the cache is already wiped (SyncService),
  // this just swaps the whole screen for a notice. Keeps syncing on the
  // usual timer/push, so "Wieder aktivieren" brings it straight back.
  bool _deactivated = false;
  // No server contact for longer than SyncService.maxOffline: photos are
  // wiped (see there); shown as a notice until the Frame is online again.
  bool _offlineExpired = false;
  // Decrypted photos (CacheCipher) -- a few kept in memory so paging back
  // and forth and the grid don't decrypt the same file over and over.
  final Map<String, Future<Uint8List?>> _decrypted = {};
  bool _showGrid = false;
  Timer? _gridTimeout;

  // --- Controls (2026-10-14) ------------------------------------------
  bool _paused = false;
  bool _barVisible = false;
  Timer? _hideBar;

  /// "Neueste": the newest 20 of all albums, newest first, for one round.
  bool _newestRound = false;

  /// A photo the remote control asked for that isn't in the playlist: shown
  /// until the next move.
  CachedMediaEntry? _spotlight;
  String? _pendingShowId;

  /// "Neu von Roman" over a photo that just arrived.
  String? _newFrom;
  Timer? _hideNewFrom;
  Set<String>? _knownIds;

  int _shuffleSeed = DateTime.now().millisecondsSinceEpoch;

  // --- Clock and Nachtruhe --------------------------------------------
  Timer? _minuteTimer;
  DateTime _now = DateTime.now();
  bool _quiet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersiveMode();
    // Auto-pin/Home-role-request on start and resume are deliberately
    // disabled during development (2026-09-07) -- see MainActivity.kt.
    // A data push nudges the already-running sync loop immediately,
    // bypassing the 2-minute foreground poll interval.
    PushSyncSignal.onSyncRequested = () => unawaited(_sync());
    PushSyncSignal.onCommand = _onCommand;
    widget.syncService.onEarlyResult = _applyEarly;
    _minuteTimer = Timer.periodic(const Duration(seconds: 15), (_) => _tickClock());
    _init();
  }

  // Hides the status bar and navigation-gesture hint -- this is a dedicated
  // display, not a regular tablet UI. Must be re-applied on resume: Android
  // can bring the system bars back on focus changes.
  void _enterImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersiveMode();
    }
  }

  Future<void> _init() async {
    _cacheDirPath = await widget.cacheStore.resolvedDirectoryPath();
    // Decrypted playback copies left behind by a crash mid-video.
    await widget.cacheStore.clearPlaybackFiles();
    _fcmToken = await widget.pushService.getToken();
    await _loadFromCacheImmediately();
    unawaited(_sync());
    _syncTimer = Timer.periodic(_syncInterval, (_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushSyncSignal.onSyncRequested = null;
    PushSyncSignal.onCommand = null;
    widget.syncService.onEarlyResult = null;
    _syncTimer?.cancel();
    _advanceTimer?.cancel();
    _offlineRetryTimer?.cancel();
    _hideBar?.cancel();
    _hideNewFrom?.cancel();
    _gridTimeout?.cancel();
    _minuteTimer?.cancel();
    if (_quiet) unawaited(_window.invokeMethod<void>('setDim', false).catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _loadFromCacheImmediately() async {
    // Show whatever's already on disk before the first network round-trip
    // completes -- offline-first, no blank screen while waiting on sync.
    if (await widget.syncService.isOfflineExpired()) {
      if (mounted) setState(() => _offlineExpired = true);
      return;
    }
    // Only the album shown last: the cache holds all of the Frame's albums.
    final cached = await widget.syncService.cachedShownEntries();
    if (!mounted || cached.isEmpty) return;
    setState(() {
      _albumEntries = cached..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _rebuildPlaylist();
      _loadedOnce = true;
    });
    _restartAdvanceTimer();
  }

  Future<void> _sync() async {
    final result = await widget.syncService.sync(fcmToken: _fcmToken);
    if (!mounted) return;
    if (result.unpaired) {
      widget.onUnpaired?.call();
      return;
    }
    _apply(result);
    unawaited(widget.heartbeatService.submitHeartbeat(fcmToken: _fcmToken));
  }

  /// The server's first answer, before the rest of the sync (SyncService.
  /// onEarlyResult): settings and album switches take effect right away.
  void _applyEarly(SyncResult early) {
    if (mounted) _apply(early);
  }

  void _apply(SyncResult result) {
    final all = result.allEntries.isNotEmpty ? result.allEntries : result.entries;
    final known = _knownIds;
    final arrived = known == null ? const <CachedMediaEntry>[] : all.where((e) => !known.contains(e.mediaItemId)).toList();
    // Another album (from the app or the Frame): it shows from its first
    // photo, and a running "Neueste" round ends (2026-10-14: the round kept
    // going and hid the switch).
    final albumChanged = _currentChannelId != null && result.channelId != null && result.channelId != _currentChannelId;
    setState(() {
      if (albumChanged) {
        _newestRound = false;
        _spotlight = null;
        _showGrid = false;
        _playlist = [];
        _currentIndex = 0;
        _slideNumber++;
      }
      _deactivated = result.deactivated;
      _offlineExpired = result.offlineExpired;
      _offlineRetryTimer?.cancel();
      if (result.offline) _offlineRetryTimer = Timer(_offlineRetryInterval, _sync);
      _albumEntries = result.entries;
      _allEntries = all;
      _settings = result.settings;
      _loadedOnce = true;
      _currentChannelId = result.channelId;
      _assignedChannels = result.assignedChannels;
      _rebuildPlaylist();
    });
    _knownIds = {...?known, for (final e in all) e.mediaItemId};
    _updateQuiet();
    _showArrived(arrived);
    final pending = _pendingShowId;
    if (pending != null) _showMedia(pending, retry: false);
    _restartAdvanceTimer();
  }

  // --- The playlist -----------------------------------------------------

  /// The settings' content and order -- keeping the photo on screen where
  /// it is when it is still part of it.
  void _rebuildPlaylist() {
    final keepId = _playlist.isEmpty ? null : _playlist[_currentIndex % _playlist.length].mediaItemId;
    final settings = _settings;
    final mode = _newestRound ? 'recent' : settings?.contentMode ?? 'album';
    final order = _newestRound ? 'newest' : settings?.playOrder ?? 'oldest';
    List<CachedMediaEntry> ordered(List<CachedMediaEntry> list) {
      final copy = [...list];
      switch (order) {
        case 'newest':
          copy.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
        case 'shuffle':
          copy
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))
            ..shuffle(Random(_shuffleSeed));
        default:
          copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      return copy;
    }

    final all = {for (final e in _allEntries) e.mediaItemId: e}.values.toList();
    switch (mode) {
      case 'recent':
        final count = _newestRound ? 20 : settings?.recentCount ?? 20;
        final newest = ([...all]..sort((a, b) => b.sortOrder.compareTo(a.sortOrder))).take(count).toList();
        _playlist = ordered(newest);
      case 'rotate':
        final albums = [..._assignedChannels]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
        _playlist = [
          for (final album in albums) ...ordered(all.where((e) => e.channelId == album.channelId).toList()),
        ];
        if (_playlist.isEmpty) _playlist = ordered(_albumEntries);
      default:
        _playlist = ordered(_albumEntries);
    }
    final keep = keepId == null ? -1 : _playlist.indexWhere((e) => e.mediaItemId == keepId);
    _currentIndex = keep >= 0 ? keep : (_currentIndex < _playlist.length ? _currentIndex : 0);
  }

  CachedMediaEntry? get _current =>
      _spotlight ?? (_playlist.isEmpty ? null : _playlist[_currentIndex % _playlist.length]);

  bool get _showingVideo => _current?.isVideo ?? false;

  FrameControls get _controls => _settings?.effectiveControls ?? const FrameControls();

  void _restartAdvanceTimer() {
    _advanceTimer?.cancel();
    // A video plays to its end and moves on by itself (VideoSlide); the
    // timer only paces photos. Paused, quiet or in the overview: nothing.
    if (_showingVideo || _paused || _quiet || _showGrid) return;
    if (_settings?.displayMode == 'manual') return;
    if (_playlist.length < 2 && _spotlight == null && _settings?.endBehavior != 'overview') return;
    final seconds = _settings?.slideshowIntervalSeconds ?? 8;
    // Never cut a video short (2026-10-09): a video reached any other way
    // than by this timer -- from the overview, after an album switch --
    // used to be skipped after at most one interval.
    _advanceTimer = Timer(Duration(seconds: seconds), () {
      if (!_showingVideo) _advance(1, automatic: true);
    });
  }

  // Bumped on every move, so even a single-video channel restarts its
  // video (same index, new slide) instead of freezing on the last frame.
  int _slideNumber = 0;

  void _advance(int delta, {bool automatic = false}) {
    if (_playlist.isEmpty) return;
    final fromSpotlight = _spotlight != null;
    final next = fromSpotlight && delta > 0 ? _currentIndex : _currentIndex + delta;
    final wrapped = automatic && next >= _playlist.length;
    setState(() {
      _spotlight = null;
      if (wrapped) {
        // The end of a round.
        if (_newestRound) {
          _newestRound = false;
          _rebuildPlaylist();
          _currentIndex = 0;
        } else if (_settings?.endBehavior == 'overview') {
          _currentIndex = 0;
          _openGrid();
        } else {
          if (_settings?.playOrder == 'shuffle') {
            _shuffleSeed++;
            _rebuildPlaylist();
          }
          _currentIndex = 0;
        }
      } else {
        _currentIndex = next % _playlist.length;
        if (_currentIndex < 0) _currentIndex += _playlist.length;
      }
      _slideNumber++;
    });
    _restartAdvanceTimer();
  }

  void _onVideoFinished() {
    if (_settings?.displayMode == 'manual' || _paused) return; // stays until moved on
    _advance(1, automatic: true);
  }

  // --- New photos and the remote control ----------------------------------

  /// Just arrived: the newest of them at once, with "Neu von …" (if set).
  void _showArrived(List<CachedMediaEntry> arrived) {
    if (arrived.isEmpty || _quiet || !(_settings?.showNewImmediately ?? true)) return;
    final inPlaylist = arrived.where((e) => _playlist.any((p) => p.mediaItemId == e.mediaItemId)).toList()
      ..sort((a, b) => b.sortOrder.compareTo(a.sortOrder));
    if (inPlaylist.isEmpty) return;
    final newest = inPlaylist.first;
    setState(() {
      _showGrid = false;
      _spotlight = null;
      _currentIndex = _playlist.indexWhere((e) => e.mediaItemId == newest.mediaItemId);
      _slideNumber++;
      _newFrom = newest.senderName;
    });
    _hideNewFrom?.cancel();
    if (_newFrom != null) {
      _hideNewFrom = Timer(const Duration(seconds: 12), () {
        if (mounted) setState(() => _newFrom = null);
      });
    }
    _restartAdvanceTimer();
  }

  void _onCommand(String command, Map<String, dynamic> data) {
    if (!mounted) return;
    switch (command) {
      case 'pause':
        _setPaused(true);
      case 'play':
        _setPaused(false);
      case 'next':
        _advance(1);
      case 'back':
        _advance(-1);
      case 'newest':
        _playNewest();
      case 'show':
        final id = data['media_item_id'];
        if (id is String) _showMedia(id, retry: true);
    }
  }

  void _setPaused(bool paused) {
    setState(() => _paused = paused);
    _restartAdvanceTimer();
  }

  void _playNewest() {
    setState(() {
      _newestRound = true;
      _showGrid = false;
      _spotlight = null;
      _rebuildPlaylist();
      _currentIndex = 0;
      _slideNumber++;
    });
    _restartAdvanceTimer();
  }

  /// "Jetzt am Frame zeigen" from the app: at once if it is cached, else
  /// right after the next sync has fetched it.
  void _showMedia(String mediaItemId, {required bool retry}) {
    final index = _playlist.indexWhere((e) => e.mediaItemId == mediaItemId);
    CachedMediaEntry? found;
    for (final e in _allEntries) {
      if (e.mediaItemId == mediaItemId) found = e;
    }
    if (index < 0 && found == null) {
      _pendingShowId = retry ? mediaItemId : null;
      if (retry) unawaited(_sync());
      return;
    }
    _pendingShowId = null;
    setState(() {
      _showGrid = false;
      if (index >= 0) {
        _spotlight = null;
        _currentIndex = index;
      } else {
        _spotlight = found;
      }
      _slideNumber++;
    });
    _restartAdvanceTimer();
  }

  // --- Clock and Nachtruhe ------------------------------------------------

  void _tickClock() {
    if (!mounted) return;
    final wasQuiet = _quiet;
    _updateQuiet();
    if ((_settings?.showClock ?? false) || wasQuiet != _quiet) setState(() => _now = DateTime.now());
  }

  static int? _minutesOf(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : h * 60 + m;
  }

  void _updateQuiet() {
    final from = _minutesOf(_settings?.quietFrom);
    final to = _minutesOf(_settings?.quietTo);
    final now = DateTime.now();
    final minute = now.hour * 60 + now.minute;
    final quiet = from != null && to != null && from != to &&
        (from < to ? minute >= from && minute < to : minute >= from || minute < to);
    if (quiet == _quiet) return;
    setState(() {
      _quiet = quiet;
      _barVisible = false;
      _slideNumber++;
    });
    unawaited(_window.invokeMethod<void>('setDim', quiet).catchError((Object _) {}));
    _restartAdvanceTimer();
  }

  // --- Big buttons --------------------------------------------------------

  void _onTap() {
    if (!_controls.any || _quiet) return;
    setState(() => _barVisible = !_barVisible);
    _keepBar();
  }

  void _keepBar() {
    _hideBar?.cancel();
    if (_barVisible) {
      _hideBar = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _barVisible = false);
      });
    }
  }

  void _openGrid() {
    _showGrid = true;
    _barVisible = false;
    _armGridTimeout();
  }

  /// Nobody touches the overview for 2 minutes: back to the slideshow (so a
  /// Frame on a low level never stays there).
  void _armGridTimeout() {
    _gridTimeout?.cancel();
    _gridTimeout = Timer(const Duration(minutes: 2), () {
      if (mounted && _showGrid) _closeGrid();
    });
  }

  void _closeGrid() {
    setState(() {
      _showGrid = false;
      _slideNumber++;
    });
    _gridTimeout?.cancel();
    _restartAdvanceTimer();
  }

  void _openInSlideshow(CachedMediaEntry entry) {
    setState(() {
      _spotlight = null;
      final index = _playlist.indexWhere((e) => e.mediaItemId == entry.mediaItemId);
      if (index >= 0) _currentIndex = index;
      _showGrid = false;
      _slideNumber++;
    });
    _gridTimeout?.cancel();
    _restartAdvanceTimer();
  }

  // Works offline too: every album is in the cache (2026-10-09).
  // Also while all albums play in turn or the newest: picking one shows
  // just that album (the server switches to "Ein Album", 2026-10-14).
  bool get _canSwitchAlbum => _controls.album && _assignedChannels.length > 1;

  Future<void> _pickChannel() async {
    _hideBar?.cancel();
    final sorted = [..._assignedChannels]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // Scrolls when there are more albums than fit (found 2026-10-10 with
      // 7 albums on the landscape P610: "bottom overflowed").
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(SmileTexts.of(context).chooseAlbum, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final channel in sorted)
                    ListTile(
                      minTileHeight: 72,
                      leading: const SmileObjectIcon(icon: SmileIcons.album, size: 48),
                      title: Text(channel.name ?? channel.channelId, style: const TextStyle(fontSize: 22)),
                      trailing: channel.channelId == _currentChannelId
                          ? const Icon(SmileIcons.accept, color: SmileTheme.primary, size: 32)
                          : null,
                      onTap: () => Navigator.of(context).pop(channel.channelId),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    _keepBar();
    final showsJustThat = (_settings?.contentMode ?? 'album') == 'album' && !_newestRound;
    if (picked == null || (picked == _currentChannelId && showsJustThat)) return;
    setState(() => _newestRound = false);
    await widget.syncService.selectChannel(picked);
    await _sync();
  }

  /// A setting changed on the Frame itself: sent with the next sync, which
  /// starts right away (the server only takes what the controls allow).
  void _changeSettings(Map<String, Object> settings) {
    widget.syncService.changeSettings(settings);
    unawaited(_sync());
  }

  Future<void> _pickDuration() async {
    _hideBar?.cancel();
    final t = SmileTexts.of(context);
    final current = _settings?.slideshowIntervalSeconds ?? 8;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.durationQuestion, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final seconds in const [5, 10, 20, 60])
                    _BigChoice(
                      label: seconds == 60 ? t.oneMinute : t.secondsValue(seconds),
                      selected: seconds == current,
                      onTap: () => Navigator.of(context).pop(seconds),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    _keepBar();
    if (picked != null && picked != current) _changeSettings({'slideshow_interval_seconds': picked});
  }

  Future<void> _openPlayback() async {
    _hideBar?.cancel();
    final t = SmileTexts.of(context);
    final s = _settings;
    var content = s?.contentMode ?? 'album';
    var order = s?.playOrder ?? 'oldest';
    var end = s?.endBehavior ?? 'loop';
    var sound = s?.videoSound ?? true;
    var clock = s?.showClock ?? false;
    var sender = s?.showSender ?? true;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          void set(String key, Object value, VoidCallback local) {
            setSheet(local);
            _changeSettings({key: value});
          }

          Widget section(String title, List<Widget> choices) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      Text(title, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                      const SizedBox(height: 10),
                    ],
                    Wrap(spacing: 12, runSpacing: 12, children: choices),
                  ],
                ),
              );

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.playbackTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  section(t.whatPlays, [
                    for (final (value, label) in [('album', t.contentAlbum), ('rotate', t.contentRotate), ('recent', t.contentRecent)])
                      _BigChoice(label: label, selected: content == value, onTap: () => set('content_mode', value, () => content = value)),
                  ]),
                  section(t.playOrder, [
                    for (final (value, label) in [('newest', t.orderNewest), ('oldest', t.orderOldest), ('shuffle', t.orderShuffle)])
                      _BigChoice(label: label, selected: order == value, onTap: () => set('play_order', value, () => order = value)),
                  ]),
                  section(t.atEnd, [
                    for (final (value, label) in [('loop', t.endLoop), ('overview', t.endOverview)])
                      _BigChoice(label: label, selected: end == value, onTap: () => set('end_behavior', value, () => end = value)),
                  ]),
                  section('', [
                    _BigChoice(label: t.videoSound, selected: sound, onTap: () => set('video_sound', !sound, () => sound = !sound)),
                    _BigChoice(label: t.bigClock, selected: clock, onTap: () => set('show_clock', !clock, () => clock = !clock)),
                    _BigChoice(
                      label: t.showSenderCaption,
                      selected: sender,
                      onTap: () => set('show_sender', !sender, () => sender = !sender),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
    _keepBar();
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final t = SmileTexts.of(context);
    if (_offlineExpired || _deactivated) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _offlineExpired ? t.frameOfflineTooLong : t.frameRevokedScreen,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 20),
            ),
          ),
        ),
      );
    }

    // Nachtruhe: dark, nothing plays (the display is dimmed as well).
    if (_quiet) return const Scaffold(backgroundColor: Colors.black, body: SizedBox.expand());

    final current = _current;
    final channelName = _channelName(current?.channelId ?? _currentChannelId);
    final Widget body;
    if (current == null || _cacheDirPath == null) {
      // Which album is empty, and where to change it (2026-10-12).
      body = channelName == null
          ? SmileEmptyState(icon: SmileIcons.album, title: t.frameNoPhotos)
          : SmileEmptyState(icon: SmileIcons.album, title: t.frameAlbumEmpty(channelName), message: t.frameAlbumEmptyHint);
    } else if (_showGrid) {
      body = _buildGrid(t);
    } else {
      // A soft cross-fade between all slides (2026-10-12: every change was
      // a hard cut -- most noticeable when a video started over).
      body = AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: SizedBox.expand(
          key: ValueKey(_slideNumber),
          child: current.isVideo
              ? VideoSlide(
                  key: ValueKey('${current.fileName}#$_slideNumber'),
                  entry: current,
                  cacheStore: widget.cacheStore,
                  onFinished: _onVideoFinished,
                  withSound: _settings?.videoSound ?? true,
                  paused: _paused,
                )
              : _photo(current, BoxFit.contain),
        ),
      );
    }

    final settings = _settings;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showGrid ? null : _onTap,
        child: Stack(
          children: [
            Positioned.fill(child: body),
            if (!_showGrid && current != null && (settings?.showSender ?? true))
              Positioned(left: 20, top: 20, child: _caption(channelName, current.senderName)),
            if (!_showGrid && (settings?.showClock ?? false)) Positioned(right: 20, top: 20, child: _clock()),
            if (!_showGrid && _newFrom != null)
              Positioned(top: 20, left: 0, right: 0, child: Center(child: _newFromPill(t.frameNewFrom(_newFrom!))))
            // So one can see what plays right now (2026-10-14).
            else if (!_showGrid && _newestRound)
              Positioned(top: 20, left: 0, right: 0, child: Center(child: _newestPill(t))),
            if (!_showGrid && _paused && !_barVisible)
              Positioned(bottom: 24, left: 0, right: 0, child: Center(child: _pausedPill(t))),
            if (!_showGrid)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_barVisible,
                  child: AnimatedOpacity(
                    opacity: _barVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: _bar(t),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _channelName(String? channelId) {
    for (final c in _assignedChannels) {
      if (c.channelId == channelId) return c.name;
    }
    return null;
  }

  Widget _caption(String? album, String? sender) {
    final text = [?album, ?sender].join('  ·  ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 20)),
    );
  }

  static const _weekdays = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
  static const _months = [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  /// Big and plain: time, weekday, date -- for someone who may not know
  /// which day it is.
  Widget _clock() {
    final now = _now;
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w600, height: 1.05,
                fontFeatures: [FontFeature.tabularFigures()]),
          ),
          Text(
            '${_weekdays[now.weekday - 1]}, ${now.day}. ${_months[now.month - 1]}',
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _newFromPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: SmileTheme.primary, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Color(0xFF1A0F0E), fontSize: 22, fontWeight: FontWeight.w600)),
      );

  Widget _newestPill(SmileTexts t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(SmileIcons.newest, color: SmileTheme.primary, size: 26),
            const SizedBox(width: 10),
            Text(t.allowNewest, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _pausedPill(SmileTexts t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(SmileIcons.pause, color: Colors.white70, size: 22),
            const SizedBox(width: 8),
            Text(t.ctrlPause, style: const TextStyle(color: Colors.white70, fontSize: 18)),
          ],
        ),
      );

  /// The big buttons this Frame's controls allow, in a fixed order.
  Widget _bar(SmileTexts t) {
    final c = _controls;
    void act(VoidCallback action) {
      action();
      _keepBar();
    }

    final buttons = <Widget>[
      if (c.back) _BigButton(icon: SmileIcons.previous, label: t.ctrlBack, onTap: () => act(() => _advance(-1))),
      if (c.pause)
        _BigButton(
          icon: _paused ? SmileIcons.playFilled : SmileIcons.pause,
          label: _paused ? t.ctrlPlay : t.ctrlPause,
          onTap: () => act(() => _setPaused(!_paused)),
        ),
      if (c.next) _BigButton(icon: SmileIcons.nextItem, label: t.ctrlNext, main: true, onTap: () => act(() => _advance(1))),
      if (c.newest) _BigButton(icon: SmileIcons.newest, label: t.ctrlNewest, onTap: () => act(_playNewest)),
      if (c.overview) _BigButton(icon: SmileIcons.overview, label: t.ctrlOverview, onTap: () => setState(_openGrid)),
      if (_canSwitchAlbum) _BigButton(icon: SmileIcons.switchAlbum, label: t.ctrlAlbum, onTap: _pickChannel),
      if (c.duration) _BigButton(icon: SmileIcons.timer, label: t.ctrlDuration, onTap: _pickDuration),
      if (c.playback) _BigButton(icon: SmileIcons.playback, label: t.settings, onTap: _openPlayback),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xC0000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 14, children: buttons),
      ),
    );
  }

  Future<Uint8List?> _bytesFor(String fileName) {
    final existing = _decrypted.remove(fileName);
    final future = existing ?? widget.cacheStore.readMedia(fileName);
    _decrypted[fileName] = future; // re-insert = most recently used
    while (_decrypted.length > 40) {
      _decrypted.remove(_decrypted.keys.first);
    }
    return future;
  }

  Widget _photo(CachedMediaEntry entry, BoxFit fit) {
    // A video shows its poster frame here (grid view); photos themselves.
    final imageFile = entry.isVideo ? entry.posterFileName : entry.fileName;
    if (imageFile == null) return const ColoredBox(color: Colors.black);
    return FutureBuilder<Uint8List?>(
      key: ValueKey(imageFile),
      future: _bytesFor(imageFile),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox.expand();
        return Image.memory(bytes, fit: fit, gaplessPlayback: true);
      },
    );
  }

  Widget _buildGrid(SmileTexts t) {
    final items = _playlist;
    return Listener(
      onPointerDown: (_) => _armGridTimeout(),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final entry = items[index];
                return GestureDetector(
                  key: ValueKey(entry.mediaItemId),
                  onTap: () => _openInSlideshow(entry),
                  child: entry.isVideo
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _photo(entry, BoxFit.cover),
                            const Center(child: Icon(SmileIcons.play, size: 40, color: Colors.white70)),
                          ],
                        )
                      : _photo(entry, BoxFit.cover),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 4),
              child: _BigButton(icon: SmileIcons.slideshow, label: t.frameBackToSlideshow, main: true, wide: true, onTap: _closeGrid),
            ),
          ),
        ],
      ),
    );
  }
}

/// A button for the Frame: big enough to hit without glasses, icon and word.
class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.label, required this.onTap, this.main = false, this.wide = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool main;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final fg = main ? const Color(0xFF1A0F0E) : Colors.white;
    return Material(
      color: main ? SmileTheme.primary : const Color(0xEB1C1A1A),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 112, minHeight: 104),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: wide
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 36, color: fg),
                    const SizedBox(width: 14),
                    Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: fg)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 40, color: fg),
                    const SizedBox(height: 8),
                    Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: fg)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One big choice in the Frame's sheets (display time, playback).
class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SmileTheme.primary : const Color(0xFF2A2626),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          child: Text(
            label,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: selected ? const Color(0xFF1A0F0E) : Colors.white),
          ),
        ),
      ),
    );
  }
}
