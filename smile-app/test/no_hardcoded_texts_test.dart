import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every text a person reads lives in the language files (smile_de.arb,
/// 2026-11-10) -- so Smile can get more languages. This fails as soon as a
/// German text is written straight into the code again.
void main() {
  // Character tables and test data, not texts for people.
  const allowed = {
    'contacts_invite_screen.dart',
    'profile_service.dart',
    'handle_edit_screen.dart',
    'test_media.dart',
  };
  final patterns = [
    // Text('Speichern'), labelText: 'E-Mail', failureText: '…'
    RegExp(r"""(Text|labelText:|hintText:|tooltip:|failureText:|label:)\s*\(?\s*'[^'$]*[A-Za-zÄÖÜäöü]{3}"""),
    // Anything with an umlaut or ß.
    RegExp(r"'[^']*[äöüÄÖÜß][^']*'"),
    // Common German words in a string.
    RegExp(r"'[^'$]*\b(nicht|bitte|Bitte|gerade|Gestern|Heute|kein|keine|wurde|fehlgeschlagen)\b[^']*'"),
  ];

  test('no German text written straight into lib/', () {
    final found = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (allowed.any((name) => file.path.replaceAll('\\', '/').endsWith('/$name'))) continue;
      for (final (i, line) in file.readAsLinesSync().indexed) {
        final code = line.trimLeft();
        if (code.startsWith('//') || code.contains('debugPrint(')) continue;
        // The brand and addresses are the same in every language.
        if (code.contains("'Smile'") || code.contains('smileapp.app') || code.contains('https://')) continue;
        if (patterns.any((p) => p.hasMatch(code))) found.add('${file.path}:${i + 1}: ${code.trim()}');
      }
    }
    expect(found, isEmpty, reason: 'Put these into smile_de.arb:\n${found.join('\n')}');
  });
}
