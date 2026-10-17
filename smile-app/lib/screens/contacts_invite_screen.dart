import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _scroll = ScrollController();
  /// The letter shown big while dragging along the A–Z rail.
  String? _dragLetter;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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

  // Fixed heights (2026-10-17, A–Z rail): a jump to a letter lands
  // exactly, also with hundreds of contacts, and the list stays lazy.
  static const _labelHeight = 36.0;
  static const _letterHeight = 32.0;
  static const _rowHeight = 64.0;
  static const _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#',
  ];

  /// "Öztürk" -> O, "Émile" -> E, "1A Installateur" -> #.
  static String _letterOf(String name) {
    const plain = {
      'Ä': 'A', 'Á': 'A', 'À': 'A', 'Â': 'A', 'Å': 'A', 'Ö': 'O', 'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Ø': 'O',
      'Ü': 'U', 'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', 'Í': 'I', 'Ì': 'I',
      'Î': 'I', 'Ï': 'I', 'Ç': 'C', 'Č': 'C', 'Ć': 'C', 'Š': 'S', 'Ś': 'S', 'Ž': 'Z', 'Ź': 'Z', 'Ñ': 'N',
    };
    if (name.isEmpty) return '#';
    final first = name.characters.first.toUpperCase();
    final letter = plain[first] ?? first;
    return RegExp('^[A-Z]\$').hasMatch(letter) ? letter : '#';
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
    final others = widget.message == null ? <PhoneContact>[] : shown.where((c) => c.smile == null).toList();

    // "Noch nicht in Smile" grouped A..Z, # last.
    final groups = <String, List<PhoneContact>>{};
    for (final c in others) {
      groups.putIfAbsent(_letterOf(c.name), () => []).add(c);
    }
    final useLetters = q.isEmpty && others.length > 12;

    // The flat list: (kind, payload) with a known height each.
    final items = <(String, Object?)>[];
    final letterOffsets = <String, double>{};
    var offset = 0.0;
    void add(String kind, Object? payload, double height) {
      items.add((kind, payload));
      offset += height;
    }

    if (inSmile.isNotEmpty) add('label', t.inSmile, _labelHeight);
    for (final c in inSmile) {
      add('smile', c, _rowHeight);
    }
    if (others.isNotEmpty) add('label', t.notInSmile, _labelHeight);
    if (useLetters) {
      for (final letter in _letters) {
        final group = groups[letter];
        if (group == null) continue;
        letterOffsets[letter] = offset;
        add('letter', letter, _letterHeight);
        for (final c in group) {
          add('other', c, _rowHeight);
        }
      }
    } else {
      for (final c in others) {
        add('other', c, _rowHeight);
      }
    }
    double heightOf(int i) => switch (items[i].$1) {
          'label' => _labelHeight,
          'letter' => _letterHeight,
          _ => _rowHeight,
        };

    Widget row({
      required Widget leading,
      required String title,
      required String subtitle,
      Widget? trailing,
      VoidCallback? onTap,
    }) =>
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: SmileSpacing.m),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                        Text(subtitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: muted)),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        );

    Widget letterHeader(String letter) => Container(
          height: _letterHeight,
          color: scheme.surface,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l),
          child: Text(letter, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.primary)),
        );

    Widget item(BuildContext context, int i) {
      final (kind, payload) = items[i];
      switch (kind) {
        case 'label':
          return SizedBox(
            height: _labelHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.m, SmileSpacing.l, 0),
              child: Text((payload as String).toUpperCase(),
                  style: TextStyle(fontSize: 12, letterSpacing: 0.7, fontWeight: FontWeight.w600, color: muted)),
            ),
          );
        case 'letter':
          return letterHeader(payload as String);
        case 'smile':
          final c = payload as PhoneContact;
          final person = c.smile!;
          final reason = widget.whyNot?.call(person);
          final tile = row(
            leading: SmileAvatar(name: person.name, avatarUrl: person.avatarUrl, size: 40),
            title: c.name,
            subtitle: reason ?? t.inSmileAs(person.name),
            trailing: reason != null
                ? null
                : Text(t.contactInvite, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            onTap: reason != null ? null : () => _invitePerson(person),
          );
          return reason != null ? Opacity(opacity: 0.5, child: tile) : tile;
        default:
          final c = payload as PhoneContact;
          return row(
            leading: SmileAvatar(name: c.name, size: 40),
            title: c.name,
            subtitle: c.phones.isNotEmpty ? c.phones.first.number : c.emails.first,
            trailing: Text(t.contactInvite, style: TextStyle(color: muted, fontSize: 13)),
            onTap: () => _inviteContact(c),
          );
      }
    }

    void jumpTo(String letter) {
      // An empty letter: the next one that has contacts.
      final from = _letters.indexOf(letter);
      final target = _letters.skip(from).firstWhere(letterOffsets.containsKey, orElse: () => '');
      if (target.isEmpty || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(letterOffsets[target]!.clamp(0.0, max));
    }

    void railAt(double y, double height) {
      final i = (y / height * _letters.length).floor().clamp(0, _letters.length - 1);
      final letter = _letters[i];
      if (letter != _dragLetter) {
        HapticFeedback.selectionClick();
        setState(() => _dragLetter = letter);
      }
      jumpTo(letter);
    }

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
        if (widget.message == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.s, SmileSpacing.l, 0),
            child: Text(t.contactsOnlySmileHint, style: TextStyle(color: muted, fontSize: 13)),
          ),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(SmileSpacing.l),
                  child: Align(alignment: Alignment.topLeft, child: Text(t.noContacts, style: TextStyle(color: muted))),
                )
              : Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: useLetters ? 24 : 0),
                      child: ListView.builder(
                        controller: _scroll,
                        padding: EdgeInsets.only(bottom: SmileSpacing.l + MediaQuery.paddingOf(context).bottom),
                        itemCount: items.length,
                        itemExtentBuilder: (i, _) => i < items.length ? heightOf(i) : null,
                        itemBuilder: item,
                      ),
                    ),
                    // The current letter stays on top while scrolling.
                    if (useLetters)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 24,
                        child: AnimatedBuilder(
                          animation: _scroll,
                          builder: (context, _) {
                            final at = _scroll.hasClients ? _scroll.offset : 0.0;
                            String? current;
                            for (final e in letterOffsets.entries) {
                              if (e.value <= at) current = e.key;
                            }
                            return current == null ? const SizedBox.shrink() : letterHeader(current);
                          },
                        ),
                      ),
                    // A–Z, like the Android phone book.
                    if (useLetters)
                      Positioned(
                        top: 4,
                        bottom: 4 + MediaQuery.paddingOf(context).bottom,
                        right: 2,
                        width: 22,
                        child: LayoutBuilder(
                          builder: (context, box) => GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => railAt(d.localPosition.dy, box.maxHeight),
                            onTapUp: (_) => setState(() => _dragLetter = null),
                            onVerticalDragStart: (d) => railAt(d.localPosition.dy, box.maxHeight),
                            onVerticalDragUpdate: (d) => railAt(d.localPosition.dy, box.maxHeight),
                            onVerticalDragEnd: (_) => setState(() => _dragLetter = null),
                            onVerticalDragCancel: () => setState(() => _dragLetter = null),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final letter in _letters)
                                  Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: letter == _dragLetter
                                          ? scheme.primary
                                          : muted.withValues(alpha: letterOffsets.containsKey(letter) ? 1 : 0.35),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // The big letter while dragging.
                    if (_dragLetter != null)
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(36)),
                          child: Text(_dragLetter!,
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: scheme.onPrimary)),
                        ),
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
