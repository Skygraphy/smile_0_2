import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/device_credentials_store.dart';
import '../services/pairing_service.dart';
import 'slideshow_screen.dart';

/// UNPAIRED state (concept doc sect. 14): requests a one-time pairing code
/// from the backend and displays it as text + QR for a Space Owner's phone
/// to scan. Polls until claimed, then stores the resulting device
/// credentials and hands off to the (placeholder, for now) paired screen.
class PairingScreen extends StatefulWidget {
  PairingScreen({super.key, PairingService? pairingService, DeviceCredentialsStore? credentialsStore})
      : pairingService = pairingService ?? PairingService(),
        credentialsStore = credentialsStore ?? DeviceCredentialsStore();

  final PairingService pairingService;
  final DeviceCredentialsStore credentialsStore;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  PairingService get _pairingService => widget.pairingService;
  DeviceCredentialsStore get _credentialsStore => widget.credentialsStore;

  PairingRequest? _pairingRequest;
  Timer? _pollTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPairing() async {
    setState(() => _errorMessage = null);
    try {
      final request = await _pairingService.requestPairing();
      if (!mounted) return;
      setState(() => _pairingRequest = request);
      _pollTimer = Timer.periodic(
        Duration(seconds: request.pollIntervalSeconds),
        (_) => _poll(request),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Verbindung zum Server fehlgeschlagen. Neuer Versuch...');
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      _startPairing();
    }
  }

  Future<void> _poll(PairingRequest request) async {
    if (DateTime.now().isAfter(request.expiresAt)) {
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() => _errorMessage = 'Code abgelaufen. Neuer Versuch...');
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _startPairing();
      return;
    }

    try {
      final credentials = await _pairingService.pollPairing(
        deviceId: request.deviceId,
        code: request.code,
      );
      if (credentials == null) return; // still pending
      _pollTimer?.cancel();
      await _credentialsStore.saveCredentials(
        deviceId: credentials.deviceId,
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
      if (e.code == 'code_expired' || e.code == 'invalid_code') {
        _pollTimer?.cancel();
        if (!mounted) return;
        setState(() => _errorMessage = 'Code abgelaufen. Neuer Versuch...');
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _startPairing();
      }
      // Any other error: keep polling silently, likely transient.
    } catch (_) {
      // Network hiccup -- keep polling silently.
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _pairingRequest;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: request == null
                ? _buildLoading()
                : _buildCode(request),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(_errorMessage ?? 'Code wird angefordert...'),
      ],
    );
  }

  Widget _buildCode(PairingRequest request) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Smile-Frame koppeln', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: QrImageView(data: request.code, size: 240),
        ),
        const SizedBox(height: 24),
        Text(
          request.code,
          style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        const Text(
          'In der Smile-App: Einstellungen → Smile-Frame → Neues Frame hinzufügen',
          textAlign: TextAlign.center,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.orange)),
        ],
      ],
    );
  }
}
