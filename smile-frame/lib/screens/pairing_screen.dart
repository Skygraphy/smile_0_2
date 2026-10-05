import 'package:flutter/material.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../services/frame_credentials_store.dart';
import '../services/pairing_service.dart';
import 'slideshow_screen.dart';

/// UNPAIRED state: this Frame was already created (named, like a Channel)
/// by its Space owner in the Smile app, which shows a short pairing code --
/// reversed order from the pre-reset schema, see
/// migrations/0031_architecture_reset.sql. Whoever is setting up this
/// Frame types that code in here once; there is no more code shown *by*
/// this screen, and nothing to poll for -- claim-frame-pairing returns
/// this Frame's own credentials directly.
class PairingScreen extends StatefulWidget {
  PairingScreen({super.key, PairingService? pairingService, FrameCredentialsStore? credentialsStore})
      : pairingService = pairingService ?? PairingService(),
        credentialsStore = credentialsStore ?? FrameCredentialsStore();

  final PairingService pairingService;
  final FrameCredentialsStore credentialsStore;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final credentials = await widget.pairingService.claimPairing(code);
      await widget.credentialsStore.saveCredentials(
        frameId: credentials.frameId,
        spaceId: credentials.spaceId,
        accessToken: credentials.accessToken,
        accessTokenExpiresAt: credentials.accessTokenExpiresAt,
        refreshSecret: credentials.refreshSecret,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SlideshowScreen()),
      );
    } on PairingException catch (e) {
      setState(() => _errorMessage = _messageFor(e.code));
    } catch (_) {
      setState(() => _errorMessage = SmileTexts.of(context).framePairNoConnection);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _messageFor(String code) {
    final t = SmileTexts.of(context);
    return switch (code) {
      'invalid_code' => t.framePairInvalid,
      'code_expired' => t.framePairExpired,
      'frame_revoked' => t.framePairRevoked,
      _ => t.framePairFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SmileMark(size: 56),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(SmileIcons.frame, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(t.framePairTitle, style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.framePairHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.framePairButton),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
