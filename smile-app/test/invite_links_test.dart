import 'package:flutter_test/flutter_test.dart';
import 'package:smile_app/services/invite_links.dart';
import 'package:smile_app/services/profile_service.dart';

void main() {
  group('InviteLinks.parse', () {
    test('invite link, shown in person or sent', () {
      final qr = InviteLinks.parse('https://smileapp.app/i/K7P2QX?s=1')!;
      expect(qr.code, 'K7P2QX');
      expect(qr.inPerson, isTrue);
      expect(qr.handle, isNull);
      expect(InviteLinks.parse('https://smileapp.app/i/k7p-2qx')!.inPerson, isFalse);
    });

    test('a card link and its store referrer', () {
      expect(InviteLinks.parse('https://smileapp.app/@Ernst.Schiener')!.handle, 'ernst.schiener');
      expect(InviteLinks.parse('https://smileapp.app/%40ernst')!.handle, 'ernst');
      expect(InviteLinks.parse('person=roman_b')!.handle, 'roman_b');
      expect(InviteLinks.parse('https://smileapp.app/@ab'), isNull);
      expect(InviteLinks.parse('https://example.com/@ernst'), isNull);
      expect(InviteLinks.forHandle('ernst'), 'https://smileapp.app/@ernst');
    });
  });

  group('Smile names', () {
    test('shape', () {
      expect(isValidHandle('ernst.schiener'), isTrue);
      expect(isValidHandle('abc'), isTrue);
      for (final bad in ['ab', '.abc', 'abc.', 'a..b', 'Abc', 'smile', 'a b c', 'x' * 25]) {
        expect(isValidHandle(bad), isFalse, reason: bad);
      }
      expect(normalizeHandle(' @Ernst '), 'ernst');
    });

    test('proposal from the display name', () {
      expect(suggestHandle('Ernst Schiener'), 'ernst.schiener');
      expect(suggestHandle('Jürgen  Müßig'), 'juergen.muessig');
      expect(suggestHandle('Oma (Küche)'), 'oma.kueche');
    });
  });
}
