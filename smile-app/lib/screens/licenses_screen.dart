import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

/// "Open-Source-Lizenzen" in Smile's own look (2026-11-10) instead of
/// Flutter's grey default page: every package once, alphabetically, with
/// a small label for its kind of licence; a tap shows the text.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

/// One package and the licence texts that apply to it.
class _Package {
  _Package(this.name);

  final String name;
  final List<String> texts = [];

  /// "MIT", "BSD · Apache 2.0", ...
  String get kinds {
    final seen = <String>[];
    for (final text in texts) {
      final kind = _kindOf(text);
      if (!seen.contains(kind)) seen.add(kind);
    }
    return seen.take(2).join(' · ');
  }
}

String _kindOf(String text) {
  final t = text.toLowerCase();
  if (t.contains('apache license')) return 'Apache 2.0';
  if (t.contains('open font license')) return 'OFL';
  if (t.contains('mozilla public license')) return 'MPL';
  if (t.contains('permission is hereby granted, free of charge')) return 'MIT';
  if (t.contains('redistribution and use in source and binary forms')) return 'BSD';
  if (t.contains('gnu lesser general public')) return 'LGPL';
  if (t.contains('zlib')) return 'zlib';
  return 'Lizenz';
}

class _LicensesScreenState extends State<LicensesScreen> {
  List<_Package>? _packages;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final byName = <String, _Package>{};
    await for (final entry in LicenseRegistry.licenses) {
      final text = entry.paragraphs.map((p) => p.text.trim()).where((p) => p.isNotEmpty).join('\n\n');
      for (final name in entry.packages) {
        byName.putIfAbsent(name, () => _Package(name)).texts.add(text);
      }
    }
    final list = byName.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) setState(() => _packages = list);
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final packages = _packages?.where((p) => query.isEmpty || p.name.toLowerCase().contains(query)).toList();
    return Scaffold(
      appBar: AppBar(title: SmileFitText(t.openSourceLicenses)),
      body: packages == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: packages.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                    child: Column(
                      children: [
                        Text(
                          t.openSourceThanks,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, height: 1.5, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: t.searchHint,
                            prefixIcon: const Icon(SmileIcons.search, size: 20),
                            filled: true,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final p = packages[i - 1];
                return ListTile(
                  title: Text(p.name),
                  subtitle: p.texts.length > 1 ? Text(t.licenseCount(p.texts.length)) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Chip(p.kinds),
                      const SizedBox(width: 8),
                      Icon(SmileIcons.chevron, size: 16, color: scheme.onSurfaceVariant),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LicenseScreen(package: p))),
                );
              },
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: SmileTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: SmileTheme.primary)),
      );
}

/// One package's licence texts, in paragraphs on cards; the copyright
/// lines stand out.
class _LicenseScreen extends StatelessWidget {
  const _LicenseScreen({required this.package});

  final _Package package;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: SmileFitText(package.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (final text in package.texts) ...[
            Align(alignment: Alignment.centerLeft, child: _Chip(_kindOf(text))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final paragraph in text.split('\n\n'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        paragraph,
                        style: paragraph.toLowerCase().startsWith('copyright')
                            ? TextStyle(fontSize: 13, height: 1.55, fontWeight: FontWeight.w600, color: scheme.onSurface)
                            : TextStyle(fontSize: 13, height: 1.55, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
