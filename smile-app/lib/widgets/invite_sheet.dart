import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/invite_service.dart';
import '../services/profile_service.dart';

/// "Einladen" like WhatsApp (decided 2026-10-11): first the people one
/// already knows in Smile (by name, with a search), then a QR code for
/// someone standing next to you, a code to send as a message, and email
/// as the last resort.
///
/// [people] is already filtered by the caller (e.g. without the album's
/// members). A person found by the exact Smile name (2026-10-17) always
/// shows; [whyNot] greys them out with the reason (e.g. "Schon im Album"). [onShareCode] null: no "Einladungslink teilen" (Co-Admin is
/// in person only).
Future<void> showInviteSheet(
  BuildContext context, {
  required String title,
  required Future<List<KnownPerson>> people,
  String? Function(KnownPerson person)? subtitle,
  String? Function(KnownPerson person)? whyNot,
  required Future<void> Function(KnownPerson person) onPerson,
  required VoidCallback onShowQr,
  VoidCallback? onShareCode,
  required VoidCallback onEmail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _InviteSheet(
      title: title,
      people: people,
      subtitle: subtitle,
      whyNot: whyNot,
      // The sheet closes first; the caller reports what happened.
      onPerson: (person) {
        Navigator.of(sheetContext).pop();
        onPerson(person);
      },
      onShowQr: () {
        Navigator.of(sheetContext).pop();
        onShowQr();
      },
      onShareCode: onShareCode == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              onShareCode();
            },
      onEmail: () {
        Navigator.of(sheetContext).pop();
        onEmail();
      },
    ),
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({
    required this.title,
    required this.people,
    required this.subtitle,
    required this.whyNot,
    required this.onPerson,
    required this.onShowQr,
    required this.onShareCode,
    required this.onEmail,
  });

  final String title;
  final Future<List<KnownPerson>> people;
  final String? Function(KnownPerson person)? subtitle;
  final String? Function(KnownPerson person)? whyNot;
  final void Function(KnownPerson person) onPerson;
  final VoidCallback onShowQr;
  final VoidCallback? onShareCode;
  final VoidCallback onEmail;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  String _query = '';
  Timer? _debounce;
  /// Found by the exact Smile name (the query without "@").
  KnownPerson? _byHandle;
  String? _byHandleFor;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
    _debounce?.cancel();
    final handle = normalizeHandle(value);
    if (!isValidHandle(handle)) {
      if (_byHandle != null) setState(() => _byHandle = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      KnownPerson? found;
      try {
        found = await InviteService().findByHandle(handle);
      } catch (_) {
        return;
      }
      if (!mounted || normalizeHandle(_query) != handle) return;
      setState(() {
        _byHandle = found;
        _byHandleFor = handle;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SmileSpacing.l, 0, SmileSpacing.l, SmileSpacing.s),
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.m),
              child: TextField(
                onChanged: _onQuery,
                decoration: InputDecoration(
                  prefixIcon: const Icon(SmileIcons.search),
                  hintText: t.searchNameOrHandle,
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(SmileRadius.m), borderSide: BorderSide.none),
                ),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<KnownPerson>>(
                future: widget.people,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(SmileSpacing.l),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final all = snapshot.data ?? const <KnownPerson>[];
                  final byHandle = _byHandleFor == normalizeHandle(_query) ? _byHandle : null;
                  final shown = [
                    ?byHandle,
                    for (final p in _query.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(_query)))
                      if (p.userId != byHandle?.userId) p,
                  ];
                  if (shown.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(SmileSpacing.l),
                      child: Text(_query.isEmpty ? t.noKnownPeople : t.noPersonFound, style: TextStyle(color: muted)),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final person in shown)
                        if (person.handle != null && widget.whyNot?.call(person) != null)
                          Opacity(
                            opacity: 0.5,
                            child: SmileObjectTile(
                              leading: SmileAvatar(name: person.name, avatarUrl: person.avatarUrl, size: 40),
                              title: person.name,
                              subtitle: '@${person.handle} · ${widget.whyNot!(person)}',
                            ),
                          )
                        else
                          SmileObjectTile(
                            leading: SmileAvatar(name: person.name, avatarUrl: person.avatarUrl, size: 40),
                            title: person.name,
                            subtitle: person.handle != null
                                ? '@${person.handle}'
                                : widget.subtitle?.call(person) ?? person.context,
                            onTap: () => widget.onPerson(person),
                          ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: SmileSpacing.l),
            SmileActionRow(icon: SmileIcons.inviteCode, label: t.showQrCode, onTap: widget.onShowQr),
            if (widget.onShareCode != null)
              SmileActionRow(icon: SmileIcons.shareOut, label: t.shareInviteLink, onTap: widget.onShareCode!),
            SmileActionRow(icon: SmileIcons.email, label: t.inviteByEmail, onTap: widget.onEmail),
            const SizedBox(height: SmileSpacing.m),
          ],
        ),
      ),
    );
  }
}
