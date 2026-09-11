import 'package:flutter/material.dart';

import '../services/membership_service.dart';
import 'qr_scan_screen.dart';

/// "Einladung einlösen": enter or scan a channel_invite code shown by an
/// existing member (see channel_members_screen.dart's "Einladungscode
/// zeigen") to join their channel. Structurally mirrors
/// pair_frame_screen.dart's device-pairing flow.
class JoinChannelScreen extends StatefulWidget {
  JoinChannelScreen({super.key, MembershipService? membershipService})
      : membershipService = membershipService ?? MembershipService();

  final MembershipService membershipService;

  @override
  State<JoinChannelScreen> createState() => _JoinChannelScreenState();
}

class _JoinChannelScreenState extends State<JoinChannelScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  ChannelJoinResult? _result;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Einladungscode scannen')),
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
      final result = await widget.membershipService.joinChannelWithCode(code);
      if (!mounted) return;
      setState(() => _result = result);
    } on ChannelInviteException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Beitreten fehlgeschlagen. Bitte erneut versuchen.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einladung einlösen')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _result != null ? _buildSuccess(_result!) : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess(ChannelJoinResult result) {
    final pending = result.status == ChannelJoinStatus.pendingApproval;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            pending ? Icons.hourglass_top : Icons.check_circle,
            size: 64,
            color: pending ? Colors.orange : Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            switch (result.status) {
              ChannelJoinStatus.alreadyMember => 'Du bist bereits Mitglied von "${result.channelName}".',
              ChannelJoinStatus.pendingApproval =>
                'Deine Anfrage für "${result.channelName}" wurde gesendet -- ein Admin muss sie noch bestätigen.',
              ChannelJoinStatus.joined => 'Du bist jetzt Mitglied von "${result.channelName}".',
            },
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Scanne den Einladungscode eines Mitglieds, oder gib ihn manuell ein.'),
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
              : const Text('Beitreten'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}
