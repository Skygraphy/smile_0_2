import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/plan_service.dart';
import '../services/test_media.dart' show smileTestMode;
import '../widgets/friendly_error.dart';

/// "Gutschein einlösen" (2026-11-11, migrations/0102): the Space's Admin or
/// a Co-Admin types the code from the card, scans its QR code, or comes
/// from the link smileapp.app/g/… with the code filled in.
class RedeemVoucherScreen extends StatefulWidget {
  const RedeemVoucherScreen({super.key, this.spaceId, this.spaceName, this.code});

  /// From a Space's page: for that one. Otherwise picked here.
  final String? spaceId;
  final String? spaceName;

  /// From a link or card.
  final String? code;

  @override
  State<RedeemVoucherScreen> createState() => _RedeemVoucherScreenState();
}

class _RedeemVoucherScreenState extends State<RedeemVoucherScreen> {
  final _service = PlanService();
  late final _code = TextEditingController(text: widget.code ?? '');
  late String? _spaceId = widget.spaceId;
  late String? _spaceName = widget.spaceName;
  Map<String, String>? _spaces;
  bool _busy = false;
  String? _problem;
  VoucherResult? _done;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSpaces());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces() async {
    try {
      final spaces = await _service.managedSpaces();
      if (!mounted) return;
      setState(() {
        _spaces = spaces;
        if (_spaceId == null && spaces.length == 1) {
          _spaceId = spaces.keys.first;
          _spaceName = spaces.values.first;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _spaces = const {});
    }
  }

  Future<void> _pickSpace() async {
    final spaces = _spaces;
    if (spaces == null || spaces.isEmpty) return;
    final t = SmileTexts.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(t.voucherPickSpace, style: const TextStyle(fontWeight: FontWeight.w700))),
            for (final e in spaces.entries)
              ListTile(
                leading: const Icon(SmileIcons.space),
                title: Text(e.value),
                trailing: e.key == _spaceId ? const Icon(SmileIcons.check) : null,
                onTap: () => Navigator.of(context).pop(e.key),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _spaceId = picked;
        _spaceName = spaces[picked];
      });
    }
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _VoucherScanPage()));
    if (raw == null || !mounted) return;
    final link = RegExp(r'/g/([A-Za-z0-9-]+)').firstMatch(raw);
    _code.text = link?.group(1) ?? raw;
    await _redeem();
  }

  String _message(SmileTexts t, Object e) => switch (e) {
        VoucherException(code: 'not_found') => t.voucherNotFound,
        VoucherException(code: 'already_used') => t.voucherAlreadyUsed,
        VoucherException(code: 'expired') => t.voucherExpired,
        VoucherException(code: 'blocked') => t.voucherBlocked,
        VoucherException(code: 'rate_limited') => t.voucherRateLimited,
        VoucherException(code: 'not_space_manager') => t.voucherNotManager,
        _ => errorReasonIn(t, e),
      };

  Future<void> _redeem() async {
    final t = SmileTexts.of(context);
    final spaceId = _spaceId;
    if (spaceId == null) {
      await _pickSpace();
      if (_spaceId == null) return;
      return _redeem();
    }
    if (_code.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final result = await _service.redeem(_code.text.trim(), spaceId);
      if (mounted) setState(() => _done = result);
    } catch (e) {
      if (mounted) setState(() => _problem = _message(t, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final scheme = Theme.of(context).colorScheme;
    final done = _done;
    return Scaffold(
      appBar: AppBar(title: SmileFitText(t.redeemVoucher)),
      body: SafeArea(child: done != null ? _doneView(t, scheme, done) : _form(t, scheme)),
    );
  }

  Widget _form(SmileTexts t, ColorScheme scheme) {
    final spaces = _spaces;
    if (spaces != null && spaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: SmileSectionHint(icon: SmileIcons.space, text: t.voucherNoSpace),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: (spaces?.length ?? 0) > 1 ? _pickSpace : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(SmileIcons.space, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.voucherForSpace, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                        Text(_spaceName ?? '…', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if ((spaces?.length ?? 0) > 1) Text(t.voucherChangeSpace, style: const TextStyle(color: SmileTheme.primary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(t.voucherEnterCode, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2),
          decoration: InputDecoration(hintText: t.voucherCodeHint),
          onSubmitted: (_) => _redeem(),
        ),
        const SizedBox(height: 8),
        Text(t.voucherCodeNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
        if (_problem != null) ...[
          const SizedBox(height: 16),
          Text(_problem!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _redeem,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.voucherRedeem),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _scan,
          icon: const Icon(SmileIcons.scan),
          label: Text(t.voucherScan),
        ),
      ],
    );
  }

  Widget _doneView(SmileTexts t, ColorScheme scheme, VoucherResult done) {
    final date = DateFormat.yMMMMd(Localizations.localeOf(context).toLanguageTag());
    final space = _spaceName ?? '';
    final frames = t.planFrames(done.frames);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: SmileTheme.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: const Icon(SmileIcons.check, color: SmileTheme.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(t.voucherDone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            done.startsLater
                ? t.voucherDoneLater(space, frames, date.format(done.startsAt), date.format(done.endsAt))
                : t.voucherDoneText(space, frames, date.format(done.endsAt)),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if ((done.from ?? '').isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(SmileIcons.gift, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Flexible(child: Text(t.voucherGiftFrom(done.from!), style: TextStyle(color: scheme.onSurfaceVariant))),
              ],
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.done)),
          ),
        ],
      ),
    );
  }
}

/// The camera, only to read the card's QR code.
class _VoucherScanPage extends StatefulWidget {
  const _VoucherScanPage();

  @override
  State<_VoucherScanPage> createState() => _VoucherScanPageState();
}

class _VoucherScanPageState extends State<_VoucherScanPage> {
  // The test app never opens the camera (2026-10-22).
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode], autoStart: !smileTestMode);
  bool _taken = false;

  @override
  void dispose() {
    unawaited(_scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      appBar: AppBar(title: SmileFitText(t.voucherScan)),
      body: MobileScanner(
        controller: _scanner,
        onDetect: (capture) {
          if (_taken) return;
          for (final b in capture.barcodes) {
            final raw = b.rawValue;
            if (raw != null && raw.trim().isNotEmpty) {
              _taken = true;
              Navigator.of(context).pop(raw);
              return;
            }
          }
        },
      ),
    );
  }
}
