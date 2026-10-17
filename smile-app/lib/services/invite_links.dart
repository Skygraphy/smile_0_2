import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An invite from a link or QR code: the code, and whether it was shown in
/// person (QR -- in at once) or came by message (the admins decide).
class InviteLink {
  const InviteLink(this.code, {required this.inPerson}) : handle = null;

  /// A person's card (smileapp.app/@name, 2026-10-17): open them to invite.
  const InviteLink.person(String this.handle)
      : code = '',
        inPerson = true;

  final String code;
  final bool inPerson;
  final String? handle;
}

/// Invites as real links (decided 2026-10-17, domain smileapp.app): the
/// same address works with Smile installed (it opens the app) and without
/// (a web page with the store; the code rides along through the install).
class InviteLinks {
  InviteLinks._();

  static const host = 'smileapp.app';

  /// [inPerson]: shown as a QR code -- whoever scans it is in at once.
  static String forCode(String code, {required bool inPerson}) =>
      'https://$host/i/$code${inPerson ? '?s=1' : ''}';

  /// A person's card: smileapp.app/@name.
  static String forHandle(String handle) => 'https://$host/@$handle';

  static final _handleShape = RegExp(r'^[a-z0-9][a-z0-9._]{1,22}[a-z0-9_]$');

  /// A link, an old "smile:invite:" QR code, or the store's referrer.
  static InviteLink? parse(String raw) {
    final text = raw.trim();
    final old = RegExp(r'^smile:invite:([A-Za-z0-9-]{6,7})$', caseSensitive: false).firstMatch(text);
    if (old != null) return InviteLink(_clean(old.group(1)!), inPerson: true);
    final referrer = RegExp(r'(?:^|&)invite=([A-Za-z0-9-]{6,7})').firstMatch(text);
    final personReferrer = RegExp(r'(?:^|&)person=([A-Za-z0-9._]{3,24})').firstMatch(text);
    if (personReferrer != null && !text.contains('://')) {
      final handle = personReferrer.group(1)!.toLowerCase();
      return _handleShape.hasMatch(handle) ? InviteLink.person(handle) : null;
    }
    if (referrer != null && !text.contains('://')) {
      return InviteLink(_clean(referrer.group(1)!), inPerson: RegExp(r'(?:^|&)s=1').hasMatch(text));
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.host.endsWith(host)) return null;
    final person = RegExp(r'^/@([A-Za-z0-9._]{3,24})/?$').firstMatch(Uri.decodeComponent(uri.path));
    if (person != null) {
      final handle = person.group(1)!.toLowerCase();
      return _handleShape.hasMatch(handle) ? InviteLink.person(handle) : null;
    }
    final match = RegExp(r'^/i/([A-Za-z0-9-]{6,7})/?$').firstMatch(uri.path);
    if (match == null) return null;
    return InviteLink(_clean(match.group(1)!), inPerson: uri.queryParameters['s'] == '1');
  }

  static String _clean(String code) => code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  /// An invite waiting to be redeemed (opened before sign-in, or brought
  /// along by the store) -- HomeShell takes it as soon as someone is in.
  static final pending = ValueNotifier<InviteLink?>(null);

  static const _pendingKey = 'pending_invite';
  static const _referrerKey = 'install_referrer_checked';
  static bool _started = false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    await _loadPending();
    try {
      final links = AppLinks();
      final first = await links.getInitialLink();
      if (first != null) _take(first.toString());
      links.uriLinkStream.listen((uri) => _take(uri.toString()), onError: (Object _) {});
    } catch (_) {}
    unawaited(_checkInstallReferrer());
  }

  static void _take(String raw) {
    final link = parse(raw);
    if (link == null) return;
    pending.value = link;
    unawaited(_savePending(link));
  }

  /// Taken: not offered again.
  static Future<void> clear() async {
    pending.value = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_pendingKey);
    } catch (_) {}
  }

  /// Once after the installation: the code the store brought along.
  static Future<void> _checkInstallReferrer() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_referrerKey) ?? false) return;
      await prefs.setBool(_referrerKey, true);
      final details = await PlayInstallReferrer.installReferrer;
      final referrer = details.installReferrer;
      if (referrer != null && (referrer.contains('invite=') || referrer.contains('person='))) {
        _take(Uri.decodeComponent(referrer));
      }
    } catch (_) {
      // Not from the Play Store (e.g. installed by hand): nothing to take.
    }
  }

  static Future<void> _savePending(InviteLink link) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_pendingKey, '${link.handle != null ? '@${link.handle}' : link.code}|${link.inPerson ? 1 : 0}|${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {}
  }

  static Future<void> _loadPending() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_pendingKey);
      if (raw == null) return;
      final parts = raw.split('|');
      final saved = DateTime.fromMillisecondsSinceEpoch(int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0);
      // An invite is valid 24 hours: older ones are useless.
      if (DateTime.now().difference(saved) > const Duration(hours: 24)) {
        await clear();
        return;
      }
      pending.value = parts[0].startsWith('@')
          ? InviteLink.person(parts[0].substring(1))
          : InviteLink(parts[0], inPerson: parts.length > 1 && parts[1] == '1');
    } catch (_) {}
  }
}
