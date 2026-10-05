import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/sync_bus.dart';
import '../services/trash_service.dart';

/// Deleted Spaces and Channels stay here for 30 days before they are gone
/// for good (supabase/migrations/0048_trash.sql) -- restoring brings back
/// everything exactly as it was: members, shares, Frames, photos.
class TrashScreen extends StatefulWidget {
  TrashScreen({super.key, TrashService? trashService}) : trashService = trashService ?? TrashService();

  final TrashService trashService;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SyncReload {
  List<TrashItem>? _items;
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
      final items = await widget.trashService.listTrash();
      if (!mounted) return;
      setState(() {
        _items = items;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items ??= const [];
        _errorMessage = SmileTexts.of(context).trashLoadError('$e');
      });
    }
  }

  Future<void> _restore(TrashItem item) async {
    final t = SmileTexts.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.trashService.restore(item);
      await _load();
      messenger.showSnackBar(SnackBar(content: Text(t.restored(item.name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(t.actionFailed('$e'))));
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(SmileIcons.back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(t.trashTitle),
      ),
      body: items == null
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
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 140),
                      child: SmileEmptyState(icon: SmileIcons.trash, title: t.trashEmpty),
                    ),
                  for (final item in items)
                    SmileObjectTile(
                      leading: SmileObjectIcon(icon: item.isSpace ? SmileIcons.space : SmileIcons.album),
                      title: item.name,
                      subtitle: [
                        if (item.spaceName != null) t.trashSpaceIn(item.spaceName!),
                        if (item.deletedByName != null) t.trashDeletedBy(item.deletedByName!),
                        t.trashGoneOn(_date(item.purgeAfter)),
                      ].join(' · '),
                  subtitleMaxLines: 2,
                      trailing: IconButton(
                        icon: Icon(SmileIcons.restore, color: Theme.of(context).colorScheme.primary),
                        tooltip: t.actionRestore,
                        onPressed: () => _restore(item),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
