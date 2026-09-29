import 'package:flutter/material.dart';

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
        _errorMessage = 'Papierkorb konnte nicht geladen werden: $e';
      });
    }
  }

  Future<void> _restore(TrashItem item) async {
    try {
      await widget.trashService.restore(item);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('„${item.name}“ ist wiederhergestellt.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wiederherstellen fehlgeschlagen: $e')));
    }
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Papierkorb')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (items.isEmpty) const Text('Der Papierkorb ist leer.'),
                  for (final item in items)
                    Card(
                      child: ListTile(
                        leading: Icon(item.isSpace ? Icons.home_outlined : Icons.photo_library_outlined),
                        title: Text(item.isSpace ? 'Space „${item.name}“' : 'Channel „${item.name}“'),
                        subtitle: Text([
                          if (item.spaceName != null) 'in ${item.spaceName}',
                          if (item.deletedByName != null) 'gelöscht von ${item.deletedByName}',
                          'endgültig weg am ${_date(item.purgeAfter)}',
                        ].join(' · ')),
                        trailing: TextButton(onPressed: () => _restore(item), child: const Text('Wiederherstellen')),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
