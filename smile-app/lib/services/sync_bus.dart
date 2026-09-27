import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';

/// One "something you can see changed" signal. [tables]/[channelIds]/
/// [spaceIds] are empty for [SyncEvent.everything] (app resumed -- any
/// number of pushes may have been missed while backgrounded).
class SyncEvent {
  const SyncEvent({required this.tables, required this.channelIds, required this.spaceIds});

  const SyncEvent.everything() : tables = const {}, channelIds = const {}, spaceIds = const {};

  /// The `type: 'sync'` data message sync-fanout sends -- see
  /// supabase/functions/sync-fanout/index.ts and the sync_notify() trigger
  /// in migrations/0041_fcm_sync.sql that decides who receives it.
  factory SyncEvent.fromPush(Map<String, dynamic> data) {
    Set<String> split(Object? v) => (v as String? ?? '').split(',').where((s) => s.isNotEmpty).toSet();
    return SyncEvent(tables: split(data['table']), channelIds: split(data['channel_ids']), spaceIds: split(data['space_ids']));
  }

  final Set<String> tables;
  final Set<String> channelIds;
  final Set<String> spaceIds;

  bool get isEverything => tables.isEmpty;

  SyncEvent merge(SyncEvent other) {
    if (isEverything || other.isEverything) return const SyncEvent.everything();
    return SyncEvent(
      tables: {...tables, ...other.tables},
      channelIds: {...channelIds, ...other.channelIds},
      spaceIds: {...spaceIds, ...other.spaceIds},
    );
  }
}

/// The app's ONLY cross-device update path: every change another device
/// (or the server) makes reaches this app as a silent FCM data message,
/// never via Supabase Realtime (dropped entirely, see
/// migrations/0041_fcm_sync.sql). main.dart feeds it; every screen that
/// shows server data listens through [SyncReload].
class SyncBus {
  SyncBus._();

  static final _controller = StreamController<SyncEvent>.broadcast();

  static Stream<SyncEvent> get stream => _controller.stream;

  static void emit(SyncEvent event) => _controller.add(event);
}

/// Mix into a screen's State to reload it whenever a relevant sync event
/// arrives. Bursts (a photo going uploaded -> processing -> ready, a
/// cascade across several tables) are debounced into one reload.
mixin SyncReload<T extends StatefulWidget> on State<T> {
  StreamSubscription<SyncEvent>? _syncSubscription;
  Timer? _syncDebounce;
  SyncEvent? _pendingSync;

  /// Reload this screen's data. Must keep showing the old data meanwhile
  /// (no spinner) -- this can fire at any moment while the user looks at it.
  Future<void> onSync();

  /// Narrow this down where a reload is expensive (the channel feed);
  /// cheap list screens just reload on anything.
  bool isSyncRelevant(SyncEvent event) => true;

  @override
  void initState() {
    super.initState();
    _syncSubscription = SyncBus.stream.listen((event) {
      _pendingSync = _pendingSync?.merge(event) ?? event;
      _syncDebounce?.cancel();
      _syncDebounce = Timer(const Duration(milliseconds: 400), () {
        final pending = _pendingSync;
        _pendingSync = null;
        if (!mounted || pending == null) return;
        if (pending.isEverything || isSyncRelevant(pending)) unawaited(onSync());
      });
    });
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    unawaited(_syncSubscription?.cancel());
    super.dispose();
  }
}

/// For screens about ONE Channel/Space/Frame: after a sync, if that row is
/// gone -- deleted, or the viewer lost access (removed as member, share
/// revoked, no longer co-owner) -- close everything back to the home screen
/// instead of leaving a dead screen with an error and stale cached photos.
/// Returns true if it closed. RLS decides "visible", so both cases look
/// the same here, hence the neutral wording.
Future<bool> closeIfGone(BuildContext context, {required String table, required String id}) async {
  final Map<String, dynamic>? row;
  try {
    row = await supabase.from(table).select('id').eq('id', id).maybeSingle();
  } catch (_) {
    return false; // network trouble is not "gone"
  }
  if (row != null || !context.mounted) return false;
  final navigator = Navigator.of(context);
  if (!navigator.canPop()) return false;
  navigator.popUntil((route) => route.isFirst);
  // Several screens of the same stack can detect this in the same sync --
  // one notice is enough.
  final now = DateTime.now();
  if (_lastGoneNotice == null || now.difference(_lastGoneNotice!) > const Duration(seconds: 3)) {
    _lastGoneNotice = now;
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Das ist nicht mehr verfügbar – gelöscht oder kein Zugriff mehr.')),
    );
  }
  return true;
}

DateTime? _lastGoneNotice;
