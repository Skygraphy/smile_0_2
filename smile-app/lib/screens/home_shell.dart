import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import 'channels_home_screen.dart';
import 'settings_screen.dart';
import 'spaces_screen.dart';

/// The signed-in app's frame: a bottom bar with Alben / Spaces / Profil
/// (navigation decision A, 2026-10-05). Invitations and the trash are
/// not a tab -- they sit behind the Neuigkeiten icon in each tab's top
/// bar. An IndexedStack keeps every tab alive, so switching back keeps
/// the scroll position and nothing reloads needlessly.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _albums = 0;

  int _index = _albums;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ChannelsHomeScreen(),
          SpacesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
            icon: const Icon(SmileIcons.album),
            selectedIcon: const Icon(SmileIcons.albumFilled),
            label: t.albums,
          ),
          NavigationDestination(
            icon: const Icon(SmileIcons.space),
            selectedIcon: const Icon(SmileIcons.spaceFilled),
            label: t.spaces,
          ),
          NavigationDestination(
            icon: const Icon(SmileIcons.person),
            selectedIcon: const Icon(SmileIcons.personFilled),
            label: t.profile,
          ),
        ],
      ),
    );
  }
}
