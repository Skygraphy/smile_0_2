import '../main.dart';
import 'edge_functions.dart';

/// One Space or Channel in the 30-day trash (supabase/migrations/0048_trash.sql).
class TrashItem {
  TrashItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.purgeAfter,
    this.spaceName,
    this.deletedByName,
  });

  factory TrashItem.fromJson(String kind, Map<String, dynamic> json) => TrashItem(
        kind: kind,
        id: json['id'] as String,
        name: json['name'] as String,
        spaceName: json['space_name'] as String?,
        deletedByName: json['deleted_by_name'] as String?,
        purgeAfter: DateTime.parse(json['purge_after'] as String).toLocal(),
      );

  /// 'space' | 'channel'
  final String kind;
  final String id;
  final String name;
  final String? spaceName;
  final String? deletedByName;
  final DateTime purgeAfter;

  bool get isSpace => kind == 'space';
}

class TrashService {
  /// What the caller may restore: Spaces they are Administrator of, Channels
  /// of Spaces they manage -- see list-trash/index.ts.
  Future<List<TrashItem>> listTrash() async {
    final response = await invokeEdge('list-trash', body: const {});
    final data = response.data as Map<String, dynamic>;
    return [
      ...(data['spaces'] as List).cast<Map<String, dynamic>>().map((j) => TrashItem.fromJson('space', j)),
      ...(data['channels'] as List).cast<Map<String, dynamic>>().map((j) => TrashItem.fromJson('channel', j)),
    ]..sort((a, b) => a.purgeAfter.compareTo(b.purgeAfter));
  }

  Future<void> restore(TrashItem item) async {
    await supabase.functions.invoke('restore-space-or-channel', body: {'kind': item.kind, 'id': item.id});
  }
}
