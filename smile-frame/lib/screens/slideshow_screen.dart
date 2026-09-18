import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/heartbeat_service.dart';
import '../services/media_cache_store.dart';
import '../services/media_cache_sync.dart';
import '../services/push_service.dart';
import '../services/push_sync_signal.dart';
import '../services/sync_service.dart';

/// The Frame's actual display: 'slideshow' mode auto-advances on a timer,
/// 'manual' mode advances on tap -- driven entirely by the Frame's own
/// display_mode row (migrations/0031_architecture_reset.sql), never a
/// local setting. Renders only from the local cache; syncing
/// (get-media-batch, download, evict) is a separate periodic concern
/// layered on top, so the display never blocks on network and stays up
/// fully offline once something is cached.
class SlideshowScreen extends StatefulWidget {
  SlideshowScreen({
    super.key,
    SyncService? syncService,
    MediaCacheStore? cacheStore,
    HeartbeatService? heartbeatService,
    PushService? pushService,
  })  : syncService = syncService ?? SyncService(),
        cacheStore = cacheStore ?? MediaCacheStore(),
        heartbeatService = heartbeatService ?? HeartbeatService(),
        pushService = pushService ?? PushService();

  final SyncService syncService;
  final MediaCacheStore cacheStore;
  final HeartbeatService heartbeatService;
  final PushService pushService;

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> with WidgetsBindingObserver {
  static const _syncInterval = Duration(minutes: 2);

  List<CachedMediaEntry> _entries = [];
  FrameSettingsInfo? _settings;
  String? _cacheDirPath;
  String? _spaceName;
  String? _channelName;
  String? _currentChannelId;
  List<AssignedChannel> _assignedChannels = [];
  String? _fcmToken;
  int _currentIndex = 0;
  Timer? _syncTimer;
  Timer? _advanceTimer;
  bool _loadedOnce = false;
  // Tile-grid overview toggle: reuses the same `_entries`/`_cacheDirPath`
  // this screen already syncs and caches, so it updates live the instant a
  // push-triggered `_sync()` lands -- no separate data path needed. Meant
  // to become a real browsing view later, not just a dev convenience.
  bool _showGrid = false;

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
    _fcmToken = await widget.pushService.getToken();
    await _loadFromCacheImmediately();
    unawaited(_sync());
    _syncTimer = Timer.periodic(_syncInterval, (_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushSyncSignal.onSyncRequested = null;
    _syncTimer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFromCacheImmediately() async {
    // Show whatever's already on disk before the first network round-trip
    // completes -- offline-first, no blank screen while waiting on sync.
    final cached = await widget.cacheStore.readIndex();
    if (!mounted || cached.isEmpty) return;
    setState(() {
      _entries = cached..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _loadedOnce = true;
    });
  }

  Future<void> _sync() async {
    final result = await widget.syncService.sync(fcmToken: _fcmToken);
    if (!mounted) return;
    setState(() {
      _entries = result.entries;
      _settings = result.settings;
      _loadedOnce = true;
      if (result.spaceName != null) _spaceName = result.spaceName;
      _currentChannelId = result.channelId;
      _assignedChannels = result.assignedChannels;
      final currentChannel = result.assignedChannels
          .where((c) => c.channelId == result.channelId)
          .map((c) => c.name)
          .firstOrNull;
      if (currentChannel != null) _channelName = currentChannel;
      if (_entries.isEmpty) {
        _currentIndex = 0;
      } else if (_currentIndex >= _entries.length) {
        _currentIndex = 0;
      }
    });
    _restartAdvanceTimerIfNeeded();
    unawaited(widget.heartbeatService.submitHeartbeat(fcmToken: _fcmToken));
  }

  void _restartAdvanceTimerIfNeeded() {
    _advanceTimer?.cancel();
    if (_settings?.displayMode != 'manual' && _entries.length > 1) {
      final seconds = _settings?.slideshowIntervalSeconds ?? 8;
      _advanceTimer = Timer.periodic(Duration(seconds: seconds), (_) => _advance(1));
    }
  }

  void _advance(int delta) {
    if (_entries.isEmpty) return;
    setState(() => _currentIndex = (_currentIndex + delta) % _entries.length);
  }

  void _handleTap(TapDownDetails details, double width) {
    if (_settings?.displayMode != 'manual') return;
    if (details.globalPosition.dx < width / 2) {
      _advance(-1);
    } else {
      _advance(1);
    }
  }

  // Personal Mode only -- an Assisted Mode Frame (channelSwitchEnabled ==
  // false, the default) never shows this at all, and a Frame with only one
  // assigned channel has nothing to switch to.
  bool get _canSwitchChannel => (_settings?.channelSwitchEnabled ?? false) && _assignedChannels.length > 1;

  Future<void> _pickChannel() async {
    final sorted = [..._assignedChannels]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final channel in sorted)
              ListTile(
                title: Text(
                  channel.name ?? channel.channelId,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: channel.channelId == _currentChannelId
                    ? const Icon(Icons.check, color: smileAccentColor)
                    : null,
                onTap: () => Navigator.of(context).pop(channel.channelId),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _currentChannelId) return;
    await widget.syncService.selectChannel(picked);
    await _sync();
  }

  void _toggleGrid() => setState(() => _showGrid = !_showGrid);

  void _openInSlideshow(int index) {
    setState(() {
      _currentIndex = index;
      _showGrid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final Widget body;
    if (_entries.isEmpty || _cacheDirPath == null) {
      body = const Center(
        child: Text('Noch keine Fotos', style: TextStyle(color: Colors.white70)),
      );
    } else if (_showGrid) {
      body = _buildGrid();
    } else {
      final entry = _entries[_currentIndex % _entries.length];
      final file = File('$_cacheDirPath/${entry.fileName}');
      body = GestureDetector(
        onTapDown: (details) => _handleTap(details, MediaQuery.of(context).size.width),
        child: SizedBox.expand(child: Image.file(file, fit: BoxFit.contain)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          body,
          _buildSpaceChannelLabel(),
          _buildGridToggle(),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final file = File('$_cacheDirPath/${entry.fileName}');
        return GestureDetector(
          key: ValueKey(entry.mediaItemId),
          onTap: () => _openInSlideshow(index),
          child: Image.file(file, fit: BoxFit.cover),
        );
      },
    );
  }

  Widget _buildGridToggle() {
    return Positioned(
      left: 16,
      bottom: 16,
      child: SafeArea(
        child: GestureDetector(
          onTap: _toggleGrid,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: smileAccentColor, width: 1.5),
            ),
            child: Icon(_showGrid ? Icons.slideshow : Icons.grid_view, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildSpaceChannelLabel() {
    if (_spaceName == null && _channelName == null) return const SizedBox.shrink();
    final switchable = _canSwitchChannel;
    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        child: GestureDetector(
          onTap: switchable ? _pickChannel : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: smileAccentColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 22, color: Colors.white70),
                    children: [
                      if (_spaceName != null) TextSpan(text: _spaceName),
                      if (_spaceName != null && _channelName != null) const TextSpan(text: '  ·  '),
                      if (_channelName != null)
                        TextSpan(
                          text: _channelName,
                          style: const TextStyle(color: smileAccentColor, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                if (switchable) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.unfold_more, color: smileAccentColor, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
