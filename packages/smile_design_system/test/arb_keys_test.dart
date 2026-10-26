import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A key written twice in the ARB file silently keeps only the last text
/// (Fund 33, 2026-10-26: "Jetzt zeigen" on the Frame page read "Zeigen").
void main() {
  test('no text key twice in smile_de.arb', () {
    final lines = File('lib/src/l10n/smile_de.arb').readAsLinesSync();
    final keys = <String, int>{};
    final twice = <String>[];
    for (final line in lines) {
      final m = RegExp(r'^  "([^"]+)":').firstMatch(line);
      if (m == null) continue;
      if (keys.containsKey(m[1])) twice.add(m[1]!);
      keys[m[1]!] = 1;
    }
    expect(twice, isEmpty);
  });
}
