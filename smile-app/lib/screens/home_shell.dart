import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_service.dart';
import '../services/offline.dart';
import '../services/sync_bus.dart';
import '../services/invite_links.dart';
import 'channels_home_screen.dart';
import 'person_screen.dart';
import 'scan_code_screen.dart';
import 'frames_screen.dart';
import 'spaces_screen.dart';

enum _Tab { albums, frames, spaces }

/// The signed-in app's frame: a bottom bar with Alben / Frames / Spaces
/// (navigation decision A, 2026-10-05; "Frames" added 2026-10-11 -- only
/// for someone who manages a Frame; the Profil tab went into every tab's
/// ⋮ menu as "Einstellungen" 2026-10-13, like WhatsApp). Invitations and the trash are
/// not a tab -- they sit behind the Neuigkeiten icon in each tab's top
/// bar. An IndexedStack keeps every tab alive, so switching back keeps
/// the scroll position and nothing reloads needlessly.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SyncReload {
  _Tab _selected = _Tab.albums;
  bool _hasFrames = false;

  @override
  void initState() {
    super.initState();
    // What was known last time, so the tab doesn't pop in after a moment.
    unawaited(Offline.read(_hasFramesKey).then((v) {
      if (mounted && v == 'true' && !_hasFrames) setState(() => _hasFrames = true);
    }));
    unawaited(_checkFrames());
    // An invite from a link waits for the sign-in -- taken here (2026-10-17).
    InviteLinks.pending.addListener(_takeInvite);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeInvite());
  }

  @override
  void dispose() {
    InviteLinks.pending.removeListener(_takeInvite);
    super.dispose();
  }

  bool _takingInvite = false;

  Future<void> _takeInvite() async {
    final link = InviteLinks.pending.value;
    if (link == null || _takingInvite || !mounted) return;
    _takingInvite = true;
    await InviteLinks.clear();
    // A card goes straight to the person -- no camera page in between
    // (2026-10-17: it made opening a card slow).
    if (mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => link.handle != null ? PersonScreen(handle: link.handle!) : ScanCodeScreen(initial: link),
      ));
    }
    _takingInvite = false;
  }

  static const _hasFramesKey = 'home_has_frames';

  @override
  bool isSyncRelevant(SyncEvent event) =>
      event.tables.contains('frames') || event.tables.contains('spaces') || event.tables.contains('space_co_owners');

  @override
  Future<void> onSync() => _checkFrames();

  /// A Frame added or the last one gone shows/hides the tab.
  Future<void> _checkFrames() async {
    try {
      final frames = await FrameService().listMyFrames();
      unawaited(Offline.write(_hasFramesKey, '${frames.isNotEmpty}'));
      if (mounted && frames.isNotEmpty != _hasFrames) setState(() => _hasFrames = frames.isNotEmpty);
    } catch (_) {
      // Offline: keep what was shown.
    }
  }

  List<_Tab> get _tabs => [_Tab.albums, if (_hasFrames) _Tab.frames, _Tab.spaces];

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final tabs = _tabs;
    final selected = tabs.contains(_selected) ? _selected : _Tab.albums;
    return Scaffold(
      body: IndexedStack(
        index: tabs.indexOf(selected),
        children: [
          for (final tab in tabs)
            switch (tab) {
              _Tab.albums => ChannelsHomeScreen(key: const ValueKey(_Tab.albums)),
              _Tab.frames => const FramesScreen(key: ValueKey(_Tab.frames)),
              _Tab.spaces => SpacesScreen(key: const ValueKey(_Tab.spaces)),
            },
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.indexOf(selected),
        onDestinationSelected: (index) => setState(() => _selected = tabs[index]),
        destinations: [
          for (final tab in tabs)
            switch (tab) {
              _Tab.albums => NavigationDestination(
                  icon: const Icon(SmileIcons.album),
                  selectedIcon: const Icon(SmileIcons.albumFilled),
                  label: t.albums,
                ),
              _Tab.frames => NavigationDestination(
                  icon: const Icon(SmileIcons.frame),
                  selectedIcon: const Icon(SmileIcons.frameFilled),
                  label: t.frames,
                ),
              _Tab.spaces => NavigationDestination(
                  icon: const Icon(SmileIcons.space),
                  selectedIcon: const Icon(SmileIcons.spaceFilled),
                  label: t.spaces,
                ),
            },
        ],
      ),
    );
  }
}
