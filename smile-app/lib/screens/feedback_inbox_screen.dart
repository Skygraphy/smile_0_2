import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/feedback_service.dart';

/// "Meldungen" (2026-11-20): what came in through Hilfe & Feedback -- only
/// for the operator (ops_alert_recipients). Open ones first, newest first.
class FeedbackInboxScreen extends StatefulWidget {
  const FeedbackInboxScreen({super.key, this.openReportId});

  /// From a push: opened right away.
  final String? openReportId;

  @override
  State<FeedbackInboxScreen> createState() => _FeedbackInboxScreenState();
}

class _FeedbackInboxScreenState extends State<FeedbackInboxScreen> {
  List<FeedbackReport>? _reports;
  bool _failed = false;
  bool _openedFromPush = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final list = await FeedbackService.instance.list();
      if (!mounted) return;
      setState(() {
        _reports = list;
        _failed = false;
      });
      final id = widget.openReportId;
      if (id != null && !_openedFromPush) {
        _openedFromPush = true;
        final r = list.where((r) => r.id == id).firstOrNull;
        if (r != null) unawaited(_open(r));
      }
    } catch (_) {
      if (mounted) setState(() => _failed = _reports == null);
    }
  }

  Future<void> _open(FeedbackReport r) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FeedbackDetailScreen(report: r)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reports = _reports;
    Widget body;
    if (reports == null) {
      body = _failed
          ? Center(child: Text(t.feedbackLoadFailed, style: TextStyle(color: scheme.onSurfaceVariant)))
          : const Center(child: CircularProgressIndicator());
    } else if (reports.isEmpty) {
      body = Center(child: Text(t.feedbackInboxEmpty, style: TextStyle(color: scheme.onSurfaceVariant)));
    } else {
      final sorted = [...reports]..sort((a, b) {
          if (a.done != b.done) return a.done ? 1 : -1;
          return b.createdAt.compareTo(a.createdAt);
        });
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, i) => _tile(t, sorted[i]),
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: Text(t.feedbackInbox)), body: body);
  }

  Widget _tile(SmileTexts t, FeedbackReport r) {
    final scheme = Theme.of(context).colorScheme;
    final tags = [
      kindLabel(t, r.kind),
      if (r.frameInfo?['name'] != null) r.frameInfo!['name'] as String,
      if (r.imageUrls.isNotEmpty) t.feedbackImageCount(r.imageUrls.length),
      if (r.done) t.feedbackDoneTag,
    ].join(' · ');
    return Opacity(
      opacity: r.done ? 0.5 : 1,
      child: InkWell(
        onTap: () => _open(r),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SmileSpacing.l, vertical: SmileSpacing.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmileAvatar(name: r.senderName ?? '?', avatarUrl: r.avatarUrl, size: 40),
              const SizedBox(width: SmileSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.senderName ?? r.senderEmail ?? '?',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(shortWhen(r.createdAt), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(r.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(tags, style: TextStyle(fontSize: 12, color: r.kind == FeedbackKind.problem && !r.done ? scheme.primary : scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (!r.done)
                Padding(
                  padding: const EdgeInsets.only(left: SmileSpacing.s, top: 6),
                  child: Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String kindLabel(SmileTexts t, FeedbackKind k) => switch (k) {
      FeedbackKind.problem => t.feedbackKindProblem,
      FeedbackKind.idea => t.feedbackKindIdea,
      FeedbackKind.question => t.feedbackKindQuestion,
    };

String _two(int n) => n.toString().padLeft(2, '0');

String shortWhen(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return '${_two(d.hour)}:${_two(d.minute)}';
  return '${_two(d.day)}.${_two(d.month)}.${d.year}';
}

String fullWhen(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// One report: text, pictures, device and Frame, Erledigt and the e-mail reply.
class FeedbackDetailScreen extends StatefulWidget {
  const FeedbackDetailScreen({super.key, required this.report});

  final FeedbackReport report;

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  bool _busy = false;

  Future<void> _toggleDone() async {
    final r = widget.report;
    setState(() => _busy = true);
    try {
      await FeedbackService.instance.setDone(r.id, !r.done);
      r.done = !r.done;
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reply() async {
    final r = widget.report;
    final email = r.senderEmail;
    if (email == null) return;
    String enc(String s) => Uri.encodeComponent(s);
    final quoted = r.message.split('\n').map((l) => '> $l').join('\n');
    final uri = Uri.parse('mailto:$email?subject=${enc('Deine Nachricht an Smile')}&body=${enc('Hallo ${r.senderName ?? ''},\n\n\n\n$quoted')}');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final r = widget.report;
    final muted = TextStyle(color: scheme.onSurfaceVariant, height: 1.45);
    final d = r.deviceInfo;
    final f = r.frameInfo;
    String? lastSeen;
    final seen = DateTime.tryParse(f?['last_seen_at'] as String? ?? '');
    if (seen != null) lastSeen = fullWhen(seen.toLocal());

    return Scaffold(
      appBar: AppBar(title: Text(kindLabel(t, r.kind))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SmileSpacing.l, SmileSpacing.s, SmileSpacing.l, SmileSpacing.xl),
          children: [
            Row(
              children: [
                SmileAvatar(name: r.senderName ?? '?', avatarUrl: r.avatarUrl, size: 44),
                const SizedBox(width: SmileSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.senderName ?? '?', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      if (r.senderEmail != null) SelectableText(r.senderEmail!, style: muted),
                    ],
                  ),
                ),
                Text(fullWhen(r.createdAt), style: muted.copyWith(fontSize: 12)),
              ],
            ),
            const SizedBox(height: SmileSpacing.l),
            SelectableText(r.message, style: const TextStyle(fontSize: 15.5, height: 1.5)),
            if (r.imageUrls.isNotEmpty) ...[
              const SizedBox(height: SmileSpacing.l),
              for (final url in r.imageUrls)
                Padding(
                  padding: const EdgeInsets.only(bottom: SmileSpacing.s),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(SmileRadius.m),
                    child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                  ),
                ),
            ],
            const SizedBox(height: SmileSpacing.l),
            _box(t.feedbackDevice, [
              [if (d['app_version'] != null) 'Smile ${d['app_version']}', if (d['language'] != null) '${d['language']}'.toUpperCase()].join(' · '),
              [if (d['device'] != null) '${d['device']}', if (d['os'] != null) '${d['os']}'].join(' · '),
            ]),
            if (f != null) ...[
              const SizedBox(height: SmileSpacing.m),
              _box('Frame: ${f['name'] ?? ''}${f['space'] != null ? ' (${f['space']})' : ''}', [
                [if (f['device_model'] != null) '${f['device_model']}', if (f['app_version'] != null) 'Smile ${f['app_version']}'].join(' · '),
                [
                  if (f['battery_level'] != null) t.feedbackBattery('${f['battery_level']}'),
                  if (f['control_level'] != null) t.feedbackLevel('${f['control_level']}'),
                ].join(' · '),
                if (lastSeen != null) t.feedbackLastSeen(lastSeen),
              ]),
            ],
            const SizedBox(height: SmileSpacing.xl),
            if (r.senderEmail != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _reply,
                icon: const Icon(SmileIcons.email, size: 18),
                label: Text(t.feedbackReplyMail),
              ),
            const SizedBox(height: SmileSpacing.s),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _busy ? null : _toggleDone,
              icon: Icon(r.done ? SmileIcons.restore : SmileIcons.check, size: 18),
              label: Text(r.done ? t.feedbackReopen : t.feedbackMarkDone),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(String title, List<String> lines) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(SmileSpacing.m),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(SmileRadius.m)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final l in lines.where((l) => l.isNotEmpty))
            Text(l, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.45)),
        ],
      ),
    );
  }
}
