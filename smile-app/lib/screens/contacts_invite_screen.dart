import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' show PermissionStatus;
import 'package:share_plus/share_plus.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/contacts_match.dart';
import '../services/invite_service.dart';
import '../widgets/friendly_error.dart';

/// "Aus Kontakten" (decided 2026-10-17, stage 1), like WhatsApp: the phone
/// book, with who already has Smile on top (invited with one tap) and
/// everyone else below (an SMS / WhatsApp / email with the invite link,
/// sent from the own phone).
class ContactsInviteScreen extends StatefulWidget {
  const ContactsInviteScreen({
    super.key,
    required this.title,
    required this.onPerson,
    this.whyNot,
    this.message,
  });

  final String title;

  /// Invites someone who has Smile (the screen closes first).
  final Future<void> Function(KnownPerson person) onPerson;

  /// Why someone can't be invited here ("Schon im Album"), or null.
  final String? Function(KnownPerson person)? whyNot;

  /// The invite text with its link, for people without Smile. Null: only
  /// people with Smile can be invited (Co-Admin).
  final Future<String> Function()? message;

  @override
  State<ContactsInviteScreen> createState() => _ContactsInviteScreenState();
}

enum _Stage { checking, explain, denied, loading, ready }

class _ContactsInviteScreenState extends State<ContactsInviteScreen> {
  _Stage _stage = _Stage.checking;
  List<PhoneContact> _contacts = const [];
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final status = await ContactsMatch.permission();
    if (!mounted) return;
    if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
      await _load();
    } else {
      setState(() => _stage = _Stage.explain);
    }
  }

  Future<void> _ask() async {
    final status = await ContactsMatch.askPermission();
    if (!mounted) return;
    if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
      await _load();
    } else {
      setState(() => _stage = _Stage.denied);
    }
  }

  Future<void> _load() async {
    setState(() {
      _stage = _Stage.loading;
      _error = null;
    });
    try {
      final contacts = await ContactsMatch.load();
      if (mounted) setState(() => _contacts = contacts);
    } catch (e) {
      if (mounted) setState(() => _error = SmileTexts.of(context).actionFailed(errorReason(context, e)));
    } finally {
      if (mounted) setState(() => _stage = _Stage.ready);
    }
  }

  Future<void> _openSettings() async {
    await ContactsMatch.openSettings();
    // Back from the settings: maybe allowed now.
    if (mounted && await ContactsMatch.permission() == PermissionStatus.granted) await _load();
  }

  void _invitePerson(KnownPerson person) {
    Navigator.of(context).pop();
    widget.onPerson(person);
  }

  Future<void> _inviteContact(PhoneContact contact) async {
    final message = widget.message;
    if (message == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContactInviteSheet(contact: contact, message: message()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.fromContacts)),
      body: switch (_stage) {
        _Stage.checking || _Stage.loading => const Center(child: CircularProgressIndicator()),
        _Stage.explain => _explain(context),
        _Stage.denied => _denied(context),
        _Stage.ready => _list(context),
      },
    );
  }

  Widget _explain(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget point(String text) => Padding(
          padding: const EdgeInsets.only(bottom: SmileSpacing.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(SmileIcons.check, size: 18, color: scheme.primary),
              const SizedBox(width: SmileSpacing.s),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
            ],
          ),
        );
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            SmileSpacing.xl, SmileSpacing.l, SmileSpacing.xl, SmileSpacing.l + MediaQuery.paddingOf(context).bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: scheme.primary.withValues(alpha: 0.16),
                child: Icon(SmileIcons.contacts, size: 34, color: scheme.primary),
              ),
              const SizedBox(height: SmileSpacing.m),
              Text(t.contactsPermTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: SmileSpacing.s),
              Text(t.contactsPermText,
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
              const SizedBox(height: SmileSpacing.l),
              point(t.contactsPermPoint1),
              point(t.contactsPermPoint2),
              point(t.contactsPermPoint3),
              const SizedBox(height: SmileSpacing.l),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _ask, child: Text(t.contactsContinue))),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.notNow)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _denied(BuildContext context) {
    final t = SmileTexts.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SmileSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(SmileIcons.contacts, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: SmileSpacing.m),
            Text(t.contactsDenied, textAlign: TextAlign.center),
            const SizedBox(height: SmileSpacing.l),
            FilledButton(onPressed: _openSettings, child: Text(t.openSettings)),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final q = _query;
    bool matches(PhoneContact c) =>
        q.isEmpty ||
        c.name.toLowerCase().contains(q) ||
        (c.smile?.name.toLowerCase().contains(q) ?? false) ||
        c.phones.any((p) => p.number.replaceAll(' ', '').contains(q.replaceAll(' ', ''))) ||
        c.emails.any((e) => e.toLowerCase().contains(q));
    final shown = _contacts.where(matches).toList();
    // One row per Smile person, even if several contacts point to them.
    final seen = <String>{};
    final inSmile = [for (final c in shown) if (c.smile != null && seen.add(c.smile!.userId)) c];
    final others = widget.message == null ? const <PhoneContact>[] : shown.where((c) => c.smile == null).toList();

    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.m, SmileSpacing.l, SmileSpacing.xs),
          child: Text(text.toUpperCase(),
              style: TextStyle(fontSize: 12, letterSpacing: 0.7, fontWeight: FontWeight.w600, color: muted)),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(SmileSpacing.m, SmileSpacing.s, SmileSpacing.m, SmileSpacing.xs),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              prefixIcon: const Icon(SmileIcons.search),
              hintText: t.searchContact,
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(SmileRadius.m), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(SmileSpacing.m),
            child: Text(_error!, style: TextStyle(color: scheme.error)),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: SmileSpacing.l + MediaQuery.paddingOf(context).bottom),
            children: [
              if (inSmile.isNotEmpty) label(t.inSmile),
              for (final c in inSmile)
                if (widget.whyNot?.call(c.smile!) case final reason?)
                  Opacity(
                    opacity: 0.5,
                    child: SmileObjectTile(
                      leading: SmileAvatar(name: c.smile!.name, avatarUrl: c.smile!.avatarUrl, size: 40),
                      title: c.name,
                      subtitle: reason,
                    ),
                  )
                else
                  SmileObjectTile(
                    leading: SmileAvatar(name: c.smile!.name, avatarUrl: c.smile!.avatarUrl, size: 40),
                    title: c.name,
                    subtitle: t.inSmileAs(c.smile!.name),
                    trailing: Text(t.contactInvite,
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    onTap: () => _invitePerson(c.smile!),
                  ),
              if (widget.message == null)
                Padding(
                  padding: const EdgeInsets.all(SmileSpacing.l),
                  child: Text(t.contactsOnlySmileHint, style: TextStyle(color: muted, fontSize: 13)),
                ),
              if (others.isNotEmpty) label(t.notInSmile),
              for (final c in others)
                SmileObjectTile(
                  leading: SmileAvatar(name: c.name, size: 40),
                  title: c.name,
                  subtitle: c.phones.isNotEmpty ? c.phones.first.number : c.emails.first,
                  trailing: Text(t.contactInvite, style: TextStyle(color: muted, fontSize: 13)),
                  onTap: () => _inviteContact(c),
                ),
              if (inSmile.isEmpty && others.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(SmileSpacing.l),
                  child: Text(t.noContacts, style: TextStyle(color: muted)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Einladung zu Smile senden", like WhatsApp's SMS invite: an editable
/// text with the link, sent by SMS, WhatsApp or email from the own phone.
class _ContactInviteSheet extends StatefulWidget {
  const _ContactInviteSheet({required this.contact, required this.message});

  final PhoneContact contact;
  final Future<String> message;

  @override
  State<_ContactInviteSheet> createState() => _ContactInviteSheetState();
}

class _ContactInviteSheetState extends State<_ContactInviteSheet> {
  final _text = TextEditingController();
  bool _ready = false;
  String? _error;
  late ContactPhone? _phone = _preferredPhone();

  ContactPhone? _preferredPhone() {
    final phones = widget.contact.phones;
    if (phones.isEmpty) return null;
    return phones.firstWhere((p) => p.kind == 'mobile', orElse: () => phones.first);
  }

  @override
  void initState() {
    super.initState();
    widget.message.then((text) {
      if (!mounted) return;
      setState(() {
        _text.text = text;
        _ready = true;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _error = SmileTexts.of(context).actionFailed(errorReason(context, e)));
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// The country of this phone ("de_AT" -> 43), for numbers stored
  /// without one.
  String? get _countryCode {
    const codes = {'AT': '43', 'DE': '49', 'CH': '41', 'IT': '39', 'LI': '423', 'NL': '31', 'FR': '33'};
    final parts = Platform.localeName.split(RegExp('[_-]'));
    return parts.length > 1 ? codes[parts[1].toUpperCase()] : null;
  }

  Future<void> _launch(Uri uri) async {
    final navigator = Navigator.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      // No app for it: the normal share menu with the same text.
      await SharePlus.instance.share(ShareParams(text: _text.text));
    }
    if (mounted) navigator.pop();
  }

  void _sms() {
    final number = _phone!.number.replaceAll(RegExp(r'[^0-9+]'), '');
    _launch(Uri.parse('sms:$number?body=${Uri.encodeComponent(_text.text)}'));
  }

  void _whatsApp() {
    final number = ContactsMatch.whatsAppNumber(_phone!, countryCode: _countryCode);
    if (number == null) {
      // No sure country code: WhatsApp asks whom to send it to.
      _launch(Uri.parse('whatsapp://send?text=${Uri.encodeComponent(_text.text)}'));
    } else {
      _launch(Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(_text.text)}'));
    }
  }

  void _email() {
    _launch(Uri.parse(
        'mailto:${widget.contact.emails.first}?subject=${Uri.encodeComponent('Smile')}&body=${Uri.encodeComponent(_text.text)}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final contact = widget.contact;
    String kindLabel(String? kind) => switch (kind) {
          'mobile' => t.phoneMobile,
          'home' => t.phoneHome,
          'work' => t.phoneWork,
          _ => '',
        };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.l + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.contactInviteTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: SmileSpacing.s),
            Text(t.contactInviteText(contact.name), textAlign: TextAlign.center, style: TextStyle(color: muted)),
            const SizedBox(height: SmileSpacing.m),
            Center(child: SmileAvatar(name: contact.name, size: 56)),
            const SizedBox(height: SmileSpacing.xs),
            Text(contact.name, textAlign: TextAlign.center),
            if (contact.phones.length > 1) ...[
              const SizedBox(height: SmileSpacing.m),
              RadioGroup<ContactPhone>(
                groupValue: _phone,
                onChanged: (p) => setState(() => _phone = p),
                child: Column(
                  children: [
                    for (final p in contact.phones)
                      RadioListTile<ContactPhone>(
                        value: p,
                        dense: true,
                        title: Text(p.number),
                        subtitle: kindLabel(p.kind).isEmpty ? null : Text(kindLabel(p.kind)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: SmileSpacing.m),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error))
            else
              TextField(
                controller: _text,
                enabled: _ready,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: t.contactMessageLabel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(SmileRadius.m)),
                  suffixIcon: _ready
                      ? null
                      : const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                ),
              ),
            const SizedBox(height: SmileSpacing.l),
            if (_phone != null) ...[
              FilledButton(onPressed: _ready ? _sms : null, child: Text(t.sendSms)),
              const SizedBox(height: SmileSpacing.s),
              FilledButton.tonal(onPressed: _ready ? _whatsApp : null, child: Text(t.sendWhatsApp)),
            ] else
              FilledButton(onPressed: _ready ? _email : null, child: Text(t.sendEmail)),
            if (_phone != null && contact.emails.isNotEmpty) ...[
              const SizedBox(height: SmileSpacing.s),
              FilledButton.tonal(onPressed: _ready ? _email : null, child: Text(t.sendEmail)),
            ],
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.notNow)),
          ],
        ),
      ),
    );
  }
}
