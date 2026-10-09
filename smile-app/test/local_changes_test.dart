import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smile_app/services/local_changes.dart';
import 'package:smile_app/services/sync_bus.dart';

// Own changes show at once and are matched with the server (2026-10-09).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final changes = LocalChanges.instance;
  const key = 'album.name:test';
  final affects = tablesChanged({'channels'}, channelIds: {'test'});

  test('shows the change while saving, keeps it when saved, and tells every screen', () async {
    final commit = Completer<void>();
    final events = <SyncEvent>[];
    final sub = SyncBus.stream.listen(events.add);

    final run = changes.run(overrides: {key: 'Neuer Name'}, commit: () => commit.future, affects: affects);
    expect(changes.text(key), 'Neuer Name', reason: 'visible before the server answered');
    expect(events, isEmpty, reason: 'nothing to reload before it is saved');

    commit.complete();
    expect(await run, isTrue);
    expect(changes.text(key), 'Neuer Name', reason: 'kept until the reloads have landed');
    await Future<void>.delayed(Duration.zero);
    expect(events.single.channelIds, {'test'});
    await sub.cancel();
    changes.drop([key]);
  });

  test('takes the change back when the server refuses', () async {
    final saved = await changes.run(
      overrides: {key: 'Abgelehnt'},
      commit: () async => throw Exception('no rights'),
      affects: affects,
    );
    expect(saved, isFalse);
    expect(changes.text(key), isNull);
  });

  test('a newer change of the same thing is not undone by an older one failing', () async {
    final older = Completer<void>();
    final first = changes.run(overrides: {key: 'Erster'}, commit: () => older.future, affects: affects);
    final second = changes.run(overrides: {key: 'Zweiter'}, commit: () async {}, affects: affects);
    expect(await second, isTrue);
    older.completeError(Exception('timeout'));
    expect(await first, isFalse);
    expect(changes.text(key), 'Zweiter');
    changes.drop([key]);
  });
}
