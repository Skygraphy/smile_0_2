import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_design_system/smile_design_system.dart';

void main() {
  // Names in bold instead of „…“ (2026-10-17).
  test('names become bold spans, the rest stays plain', () {
    final spans = smileNameSpans('Küche zeigt jetzt Zirkus.', ['Küche', 'Zirkus']).cast<TextSpan>();
    expect(spans.map((s) => s.text).toList(), ['Küche', ' zeigt jetzt ', 'Zirkus', '.']);
    expect(spans.map((s) => s.style?.fontWeight).toList(), [FontWeight.w600, null, FontWeight.w600, null]);
  });

  test('longest name wins, empty names are ignored', () {
    final spans = smileNameSpans('Album Urlaub 2026 löschen?', ['Urlaub', 'Urlaub 2026', '', null]).cast<TextSpan>();
    expect(spans.map((s) => s.text).toList(), ['Album ', 'Urlaub 2026', ' löschen?']);
    expect(smileNameSpans('Nichts', const []).cast<TextSpan>().single.text, 'Nichts');
  });
}
