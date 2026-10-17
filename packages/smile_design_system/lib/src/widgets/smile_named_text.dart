import 'package:flutter/material.dart';

/// Names in a sentence in bold instead of „…“ (decided 2026-10-17):
/// "Album **Urlaub 2026** löschen?". The texts themselves carry no marks;
/// the caller says which parts are names, so a text that isn't passed
/// through here simply reads plain, never with stray marks.
class SmileNamedText extends StatelessWidget {
  const SmileNamedText(
    this.text, {
    super.key,
    this.names = const [],
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final Iterable<String?> names;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: smileNameSpans(text, names)),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
}

/// [text] split into plain and bold spans: every occurrence of one of
/// [names] is bold (the longest name wins where two overlap).
List<InlineSpan> smileNameSpans(String text, Iterable<String?> names) {
  final wanted = {for (final n in names) if (n != null && n.trim().isNotEmpty) n}.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (wanted.isEmpty) return [TextSpan(text: text)];
  const bold = TextStyle(fontWeight: FontWeight.w600);
  final spans = <InlineSpan>[];
  var i = 0;
  var plainFrom = 0;
  while (i < text.length) {
    String? hit;
    for (final n in wanted) {
      if (text.startsWith(n, i)) {
        hit = n;
        break;
      }
    }
    if (hit == null) {
      i++;
      continue;
    }
    if (i > plainFrom) spans.add(TextSpan(text: text.substring(plainFrom, i)));
    spans.add(TextSpan(text: hit, style: bold));
    i += hit.length;
    plainFrom = i;
  }
  if (plainFrom < text.length) spans.add(TextSpan(text: text.substring(plainFrom)));
  return spans;
}
