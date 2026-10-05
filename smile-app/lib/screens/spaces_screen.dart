import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import '../services/space_service.dart';
import '../services/sync_bus.dart';
import '../widgets/top_bar_actions.dart';
import 'space_info_screen.dart';

/// The Spaces tab of HomeShell: every Space the caller manages (Admin or
/// Co-Admin -- spaces_select only returns those), each with its role and
/// how many albums and Frames it has. Tapping opens its info page, where
/// everything else lives.
class SpacesScreen extends StatefulWidget {
  SpacesScreen({super.key, SpaceService? spaceService}) : spaceService = spaceService ?? SpaceService();

  final SpaceService spaceService;

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpaceRow {
  _SpaceRow({required this.id, required this.name, required this.isAdmin, required this.albums, required this.frames});

  final String id;
  final String name;
  final bool isAdmin;
  final int albums;
  final int frames;
}

class _SpacesScreenState extends State<SpacesScreen> with SyncReload {
  List<_SpaceRow>? _spaces;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onSync() => _load();

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        supabase.from('spaces').select('id, name, owner_id').order('created_at'),
        supabase.from('channels').select('space_id'),
        supabase.from('frames').select('space_id'),
      ]);
      Map<String, int> countBySpace(List rows) {
        final counts = <String, int>{};
        for (final row in rows.cast<Map<String, dynamic>>()) {
          final id = row['space_id'] as String;
          counts[id] = (counts[id] ?? 0) + 1;
        }
        return counts;
      }

      final albumCounts = countBySpace(results[1] as List);
      final frameCounts = countBySpace(results[2] as List);
      final me = supabase.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        _spaces = (results[0] as List).cast<Map<String, dynamic>>().map((row) {
          final id = row['id'] as String;
          return _SpaceRow(
            id: id,
            name: row['name'] as String,
            isAdmin: row['owner_id'] == me,
            albums: albumCounts[id] ?? 0,
            frames: frameCounts[id] ?? 0,
          );
        }).toList();
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Without this, a network/permission failure left _spaces null
      // forever -- a permanent spinner with no explanation.
      setState(() {
        _spaces ??= const [];
        _errorMessage = SmileTexts.of(context).spacesLoadError('$e');
      });
    }
  }

  Future<void> _createSpace() async {
    final t = SmileTexts.of(context);
    final name = await showSmileNameDialog(context, title: t.createSpace, confirmLabel: t.create, hint: t.createSpaceHint);
    if (name == null) return;
    try {
      await widget.spaceService.createSpace(name);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = t.actionFailed('$e'));
    }
  }

  Future<void> _open(_SpaceRow space) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SpaceInfoScreen(spaceId: space.id, spaceName: space.name)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final spaces = _spaces;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(t.spaces), actions: smileTopBarActions()),
      floatingActionButton: spaces == null || spaces.isEmpty
          ? null
          : FloatingActionButton(tooltip: t.createSpace, onPressed: _createSpace, child: const Icon(SmileIcons.add)),
      body: spaces == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (spaces.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 120),
                      child: SmileEmptyState(
                        icon: SmileIcons.space,
                        title: t.spacesEmptyTitle,
                        message: t.spacesEmptyMessage,
                        actionLabel: t.createSpace,
                        actionIcon: SmileIcons.add,
                        onAction: _createSpace,
                      ),
                    ),
                  for (final space in spaces)
                    SmileObjectTile(
                      leading: const SmileObjectIcon(icon: SmileIcons.space),
                      title: space.name,
                      subtitleIcon: space.isAdmin ? SmileIcons.admin : SmileIcons.coAdmin,
                      subtitle: [
                        space.isAdmin ? t.roleAdmin : t.roleCoAdmin,
                        t.albumCount(space.albums),
                        t.frameCount(space.frames),
                      ].join(' · '),
                      trailing: Icon(SmileIcons.chevron, size: 16, color: muted),
                      onTap: () => _open(space),
                    ),
                ],
              ),
            ),
    );
  }
}
