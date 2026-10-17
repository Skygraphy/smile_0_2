import 'package:flutter_test/flutter_test.dart';
import 'package:smile_app/services/contacts_match.dart';

void main() {
  test('email hash: trimmed, lowercased SHA-256 hex', () {
    // The well-known SHA-256 of "abc" -- the server hashes the same way
    // (migrations/0082: sha256(lower(trim(email)))).
    expect(ContactsMatch.hashEmail('  ABC '), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('WhatsApp numbers', () {
    expect(ContactsMatch.whatsAppNumber(const ContactPhone(number: '+43 664 123 45 67')), '436641234567');
    expect(ContactsMatch.whatsAppNumber(const ContactPhone(number: '0043 664 1234567')), '436641234567');
    expect(ContactsMatch.whatsAppNumber(const ContactPhone(number: '0664 1234567', normalized: '+436641234567')),
        '436641234567');
    expect(ContactsMatch.whatsAppNumber(const ContactPhone(number: '0664/1234567'), countryCode: '43'), '436641234567');
    expect(ContactsMatch.whatsAppNumber(const ContactPhone(number: '0664 1234567')), isNull);
  });
}
