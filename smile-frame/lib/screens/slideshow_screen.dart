import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/command_executor.dart';
import '../services/compliance_service.dart';
import '../services/kiosk_lockdown.dart';
import '../services/media_cache_store.dart';
import '../services/media_cache_sync.dart';
import '../services/push_service.dart';
import '../services/push_sync_signal.dart';
import '../services/sync_service.dart';

/// The Frame's actual display (concept doc sect. 19): 'slideshow' mode
/// auto-advances on a timer, 'manual' mode advances on tap -- driven
/// entirely by device_policies.display_mode, never a local setting. Renders
/// only from the local cache; syncing (get-media-batch, download, evict) is
/// a separate periodic concern layered on top, so the display never blocks
/// on network and stays up fully offline once something is cached.
class SlideshowScreen extends StatefulWidget {
  SlideshowScreen({
    super.key,
    SyncService? syncService,
    MediaCacheStore? cacheStore,
    KioskLockdown? kioskLockdown,
    ComplianceService? complianceService,
    CommandExecutor? commandExecutor,
    PushService? pushService,
  })  : syncService = syncService ?? SyncService(),
        cacheStore = cacheStore ?? MediaCacheStore(),
        kioskLockdown = kioskLockdown ?? KioskLockdown(),
        complianceService = complianceService ?? ComplianceService(),
        pushService = pushService ?? PushService() {
    this.commandExecutor = commandExecutor ??
        CommandExecutor(
          syncService: this.syncService,
          cacheStore: this.cacheStore,
          complianceService: this.complianceService,
          kioskLockdown: this.kioskLockdown,
        );
  }

  final SyncService syncService;
  final MediaCacheStore cacheStore;
  final KioskLockdown kioskLockdown;
  final ComplianceService complianceService;
  final PushService pushService;
  late final CommandExecutor commandExecutor;

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> with WidgetsBindingObserver {
  static const _syncInterval = Duration(minutes: 2);

  List<CachedMediaEntry> _entries = [];
  DevicePolicyInfo? _policy;
  String? _cacheDirPath;
  String? _spaceName;
  String? _channelName;
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
      _policy = result.policy;
      _loadedOnce = true;
      if (result.spaceName != null) _spaceName = result.spaceName;
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
    unawaited(_runComplianceCheck());
  }

  // ComplianceWorker-equivalent while foregrounded (concept doc sect. 27-28):
  // submits a heartbeat and executes anything the backend queued. The
  // WorkManager-backed background loop that covers the app-not-foregrounded
  // case is a separate, later hardening pass.
  Future<void> _runComplianceCheck() async {
    final commands = await widget.complianceService.submitHeartbeat();
    for (final command in commands) {
      await widget.commandExecutor.execute(command);
    }
  }

  void _restartAdvanceTimerIfNeeded() {
    _advanceTimer?.cancel();
    if (_policy?.displayMode != 'manual' && _entries.length > 1) {
      final seconds = _policy?.slideshowIntervalSeconds ?? 8;
      _advanceTimer = Timer.periodic(Duration(seconds: seconds), (_) => _advance(1));
    }
  }

  void _advance(int delta) {
    if (_entries.isEmpty) return;
    setState(() => _currentIndex = (_currentIndex + delta) % _entries.length);
  }

  void _handleTap(TapDownDetails details, double width) {
    if (_policy?.displayMode != 'manual') return;
    if (details.globalPosition.dx < width / 2) {
      _advance(-1);
    } else {
      _advance(1);
    }
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
    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: smileAccentColor, width: 1.5),
          ),
          child: RichText(
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
        ),
      ),
    );
  }
}
