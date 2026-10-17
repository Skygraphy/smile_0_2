import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../main.dart';
import 'avatar_upload.dart';
import 'invite_service.dart';

/// One phone number of a contact, as the phone book has it.
class ContactPhone {
  const ContactPhone({required this.number, this.normalized, this.kind});

  final String number;

  /// E.164 ("+436641234567") when the phone book knows it.
  final String? normalized;

  /// mobile / home / work, or null.
  final String? kind;
}

/// A phone-book entry, and the Smile account it belongs to (if any).
class PhoneContact {
  const PhoneContact({
    required this.id,
    required this.name,
    this.phones = const [],
    this.emails = const [],
    this.smile,
  });

  final String id;
  final String name;
  final List<ContactPhone> phones;
  final List<String> emails;

  /// Found in Smile by one of [emails] (stage 1: email only).
  final KnownPerson? smile;

  PhoneContact withSmile(KnownPerson person) =>
      PhoneContact(id: id, name: name, phones: phones, emails: emails, smile: person);
}

/// "Aus Kontakten" (decided 2026-10-17, stage 1): reads the phone book on
/// the phone and asks the server which of its email addresses belong to a
/// Smile account -- sending only SHA-256 hashes, never the addresses
/// themselves (migrations/0082 match_contact_emails).
class ContactsMatch {
  static Future<PermissionStatus> permission() => FlutterContacts.permissions.check(PermissionType.read);

  static Future<PermissionStatus> askPermission() => FlutterContacts.permissions.request(PermissionType.read);

  static Future<void> openSettings() => FlutterContacts.permissions.openSettings();

  static String hashEmail(String email) => sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();

  /// All contacts with a number or an email, sorted by name, each with its
  /// Smile account where one matched.
  static Future<List<PhoneContact>> load() async {
    final raw = await FlutterContacts.getAll(properties: {ContactProperty.phone, ContactProperty.email});
    final contacts = <PhoneContact>[];
    for (final c in raw) {
      final name = (c.displayName ?? '').trim();
      final emails = {for (final e in c.emails) if (e.address.trim().isNotEmpty) e.address.trim()}.toList();
      final phones = <ContactPhone>[];
      final seen = <String>{};
      for (final p in c.phones) {
        final digits = (p.normalizedNumber ?? p.number).replaceAll(RegExp(r'[^0-9+]'), '');
        if (digits.isEmpty || !seen.add(digits)) continue;
        phones.add(ContactPhone(
          number: p.number.trim(),
          normalized: p.normalizedNumber,
          kind: switch (p.label.label.name) {
            'mobile' || 'iPhone' => 'mobile',
            'home' => 'home',
            'work' || 'workMobile' => 'work',
            _ => null,
          },
        ));
      }
      if (name.isEmpty || (phones.isEmpty && emails.isEmpty)) continue;
      contacts.add(PhoneContact(id: c.id ?? name, name: name, phones: phones, emails: emails));
    }
    contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Which hash belongs to which contact.
    final byHash = <String, List<int>>{};
    for (var i = 0; i < contacts.length; i++) {
      for (final email in contacts[i].emails) {
        byHash.putIfAbsent(hashEmail(email), () => []).add(i);
      }
    }
    final hashes = byHash.keys.toList();
    for (var start = 0; start < hashes.length; start += 1000) {
      final chunk = hashes.sublist(start, (start + 1000).clamp(0, hashes.length));
      final rows = await supabase.rpc('match_contact_emails', params: {'hashes': chunk}) as List;
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final person = KnownPerson(
          userId: r['user_id'] as String,
          name: r['display_name'] as String,
          avatarUrl: avatarPathToUrl(r['avatar_path'] as String?),
          managesASpace: r['manages_a_space'] == true,
          handle: r['handle'] as String?,
        );
        for (final i in byHash[r['email_hash'] as String] ?? const <int>[]) {
          contacts[i] = contacts[i].withSmile(person);
        }
      }
    }
    return contacts;
  }

  /// Digits for wa.me ("436641234567"), or null when the number has no
  /// country code we can be sure of.
  static String? whatsAppNumber(ContactPhone phone, {String? countryCode}) {
    String clean(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
    final candidates = [if (phone.normalized != null) clean(phone.normalized!), clean(phone.number)];
    for (final n in candidates) {
      if (n.startsWith('+')) return n.substring(1);
      if (n.startsWith('00')) return n.substring(2);
    }
    final local = clean(phone.number);
    if (countryCode != null && local.startsWith('0') && local.length > 4) return '$countryCode${local.substring(1)}';
    return null;
  }
}
