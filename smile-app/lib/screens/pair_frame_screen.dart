import 'package:flutter/material.dart';

import '../services/pairing_service.dart';
import 'qr_scan_screen.dart';

/// "Neues Frame hinzufügen" (concept doc sect. 14): enter or scan the code
/// shown on a Frame's screen to bind it to [spaceId].
class PairFrameScreen extends StatefulWidget {
  PairFrameScreen({super.key, required this.spaceId, PairingService? pairingService})
      : pairingService = pairingService ?? PairingService();

  final String spaceId;
  final PairingService pairingService;

  @override
  State<PairFrameScreen> createState() => _PairFrameScreenState();
}

class _PairFrameScreenState extends State<PairFrameScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Frame-Code scannen')),
    );
    if (code == null || !mounted) return;
    _codeController.text = code.trim().toUpperCase();
    await _submit();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.pairingService.claimDevicePairing(code: code, spaceId: widget.spaceId);
      if (!mounted) return;
      setState(() => _success = true);
    } on PairingClaimException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Koppeln fehlgeschlagen. Bitte erneut versuchen.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Frame hinzufügen')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _success ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text('Frame gekoppelt. Es aktiviert sich in Kürze von selbst.'),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Scanne den QR-Code auf dem Bildschirm des Smile-Frame, oder gib den Code manuell ein.'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('QR-Code scannen'),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Code manuell eingeben'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Koppeln'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}
