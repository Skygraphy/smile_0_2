import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/frame_service.dart';

/// "Frame erstellen": the Space owner names a new Frame (like a Channel) --
/// reversed order from the pre-reset pairing flow (the owner used to scan
/// a code the physical hardware showed; now the hardware consumes a code
/// this screen shows, see migrations/0031_architecture_reset.sql). The
/// Frame record and its pairing code exist immediately; the physical
/// Smile-Frame device activates itself once it's given this code
/// (claim-frame-pairing) -- no further action needed here.
class CreateFrameScreen extends StatefulWidget {
  CreateFrameScreen({super.key, required this.spaceId, FrameService? frameService})
      : frameService = frameService ?? FrameService();

  final String spaceId;
  final FrameService frameService;

  @override
  State<CreateFrameScreen> createState() => _CreateFrameScreenState();
}

class _CreateFrameScreenState extends State<CreateFrameScreen> {
  final _nameController = TextEditingController();
  bool _isCreating = false;
  String? _errorMessage;
  SmileFrame? _created;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });
    try {
      final frame = await widget.frameService.createFrame(spaceId: widget.spaceId, name: name);
      if (!mounted) return;
      setState(() => _created = frame);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Frame konnte nicht erstellt werden: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Frame erstellen')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _created != null ? _buildCode(_created!) : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildCode(SmileFrame frame) {
    final code = frame.pairingCode!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          Text('"${frame.name}" wurde angelegt.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Gib diesen Code am neuen Smile-Frame ein, oder lass ihn den QR-Code scannen.'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: QrImageView(data: code, size: 200),
          ),
          const SizedBox(height: 16),
          Text(code, style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (frame.pairingCodeExpiresAt != null)
            Text('Gültig bis ${frame.pairingCodeExpiresAt!.toLocal()}'.split('.').first),
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
        const Text('Wie soll das neue Frame heißen (z.B. "Küche")?'),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (_) => _create(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isCreating ? null : _create,
          child: _isCreating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Erstellen'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}
