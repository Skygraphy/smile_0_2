import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/invite_service.dart';
import '../widgets/friendly_error.dart';

/// The QR code to scan in person, and the same code to type (decided
/// 2026-10-11). Valid 24 hours; "Neuen Code erstellen" replaces it.
class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({
    super.key,
    required this.kind,
    required this.targetId,
    required this.title,
    required this.hint,
  });

  final InviteKind kind;
  final String targetId;
  final String title;
  final String hint;

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _service = InviteService();
  InviteCode? _code;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool renew = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await _service.createCode(widget.kind, widget.targetId, renew: renew);
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = SmileTexts.of(context).actionFailed(errorReason(context, e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final code = _code;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SmileSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (code == null && _error == null) const CircularProgressIndicator(),
              if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              if (code != null) ...[
                Container(
                  padding: const EdgeInsets.all(SmileSpacing.m),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(SmileRadius.l)),
                  child: QrImageView(data: code.qrData, size: 240, backgroundColor: Colors.white),
                ),
                const SizedBox(height: SmileSpacing.l),
                SelectableText(
                  code.pretty,
                  style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: SmileSpacing.m),
                Text(widget.hint, textAlign: TextAlign.center, style: TextStyle(color: muted)),
                const SizedBox(height: SmileSpacing.s),
                Text(t.qrValid, style: TextStyle(color: muted, fontSize: 12.5)),
                const SizedBox(height: SmileSpacing.l),
                TextButton(onPressed: _busy ? null : () => _load(renew: true), child: Text(t.newCode)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
