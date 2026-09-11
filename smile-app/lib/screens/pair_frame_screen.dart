import 'package:flutter/material.dart';

import '../services/device_service.dart';
import '../services/pairing_service.dart';
import 'qr_scan_screen.dart';

/// "Neues Frame hinzufügen" (concept doc sect. 14): enter or scan the code
/// shown on a Frame's screen to bind it to [spaceId]. Also offers "Ersetzt
/// dieses Gerät ein bestehendes Frame?" -- every (re-)pairing mints a
/// brand new device_id (see migrations/0023_replace_device_on_pairing.sql),
/// so without this a replaced Frame would start from a completely blank
/// slate: no channel assignments, no policy, no photos.
class PairFrameScreen extends StatefulWidget {
  PairFrameScreen({
    super.key,
    required this.spaceId,
    PairingService? pairingService,
    DeviceService? deviceService,
  })  : pairingService = pairingService ?? PairingService(),
        deviceService = deviceService ?? DeviceService();

  final String spaceId;
  final PairingService pairingService;
  final DeviceService deviceService;

  @override
  State<PairFrameScreen> createState() => _PairFrameScreenState();
}

class _PairFrameScreenState extends State<PairFrameScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _success = false;
  List<SmileDevice>? _replaceableDevices;
  String? _replaceDeviceId;

  @override
  void initState() {
    super.initState();
    _loadReplaceableDevices();
  }

  Future<void> _loadReplaceableDevices() async {
    try {
      final devices = await widget.deviceService.listDevices(widget.spaceId);
      if (!mounted) return;
      setState(() => _replaceableDevices = devices);
    } catch (_) {
      // Best-effort and non-critical -- this only feeds the optional
      // "Ersetzt dieses Gerät ein bestehendes Frame?" picker; a failure
      // here should never block pairing a plain new device. Leaving
      // _replaceableDevices null just means that picker silently doesn't
      // show up (same as "no devices yet"), not a scary error banner on
      // the main pairing screen.
      if (mounted) setState(() => _replaceableDevices = const []);
    }
  }

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
      final replaceDeviceId = _replaceDeviceId;
      if (replaceDeviceId == null) {
        await widget.pairingService.claimDevicePairing(code: code, spaceId: widget.spaceId);
      } else {
        await widget.pairingService.claimDevicePairing(
          code: code,
          spaceId: widget.spaceId,
          replaceDeviceId: replaceDeviceId,
        );
      }
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
        child: SingleChildScrollView(
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
        if (_replaceableDevices != null && _replaceableDevices!.isNotEmpty) ...[
          const SizedBox(height: 24),
          DropdownButtonFormField<String?>(
            initialValue: _replaceDeviceId,
            decoration: const InputDecoration(labelText: 'Ersetzt dieses Gerät ein bestehendes Frame?'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nein, neues Gerät')),
              for (final device in _replaceableDevices!)
                DropdownMenuItem(value: device.id, child: Text(device.name)),
            ],
            onChanged: _isSubmitting ? null : (value) => setState(() => _replaceDeviceId = value),
          ),
        ],
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
