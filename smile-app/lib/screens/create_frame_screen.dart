import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smile_design_system/smile_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;

import '../frame/frame.dart' as frame;
import '../main.dart';
import '../services/frame_service.dart';
import '../services/push_service.dart';
import '../services/upload_queue.dart';
import '../widgets/friendly_error.dart';
import 'frame_remote_screen.dart';

/// "Frame einrichten" (one app, decided 2026-10-11): name it, then either
/// another device scans the QR code (or types the code) -- or THIS device
/// becomes the Frame right away, no code needed. The pairing itself is the
/// same as always (create-frame, claim-frame-pairing).
class CreateFrameScreen extends StatefulWidget {
  CreateFrameScreen({
    super.key,
    required this.spaceId,
    this.existingFrame,
    FrameService? frameService,
  }) : frameService = frameService ?? FrameService();

  final String spaceId;
  final FrameService frameService;

  /// "Anderes Gerät verbinden" for a Frame that exists already: straight
  /// to its code -- a device that claims it becomes this Frame (same
  /// albums and settings), the previous device loses its access.
  final SmileFrame? existingFrame;

  @override
  State<CreateFrameScreen> createState() => _CreateFrameScreenState();
}

class _CreateFrameScreenState extends State<CreateFrameScreen> {
  final _nameController = TextEditingController();
  bool _busy = false;
  String? _errorMessage;
  late SmileFrame? _created = widget.existingFrame;
  Timer? _waitForPairing;

  @override
  void dispose() {
    _nameController.dispose();
    _waitForPairing?.cancel();
    super.dispose();
  }

  Future<SmileFrame?> _createFrame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return null;
    final t = SmileTexts.of(context);
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      return await widget.frameService.createFrame(
        spaceId: widget.spaceId,
        name: name,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = t.actionFailed(errorReasonIn(t, e)));
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Ein anderes Gerät": show the code, and switch to the remote control
  /// as soon as the device has paired.
  Future<void> _forAnotherDevice() async {
    final frame = await _createFrame();
    if (frame == null || !mounted) return;
    setState(() => _created = frame);
    _waitForPairing = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final now = await widget.frameService.getFrame(frame.id);
        if (now.lifecycleState != 'active' || !mounted) return;
        _waitForPairing?.cancel();
        unawaited(
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => FrameRemoteScreen(
                frameId: frame.id,
                frame: now,
                spaceId: widget.spaceId,
              ),
            ),
          ),
        );
      } catch (_) {}
    });
  }

  /// "Dieses Gerät": it becomes the Frame at once. The person's sign-in on
  /// this device ends -- a device is a phone or a Frame, never both.
  Future<void> _forThisDevice() async {
    final t = SmileTexts.of(context);
    final confirmed = await showSmileConfirmDialog(
      context,
      title: t.thisDeviceTitle,
      message: t.thisDeviceMessage,
      confirmLabel: t.thisDeviceConfirm,
    );
    if (!confirmed) return;
    final created = await _createFrame();
    if (created == null || created.pairingCode == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await frame.becomeFrame(
        created.pairingCode!,
        // The app's own side ends here: no more personal notifications on
        // this device, nothing of the person left to send, signed out.
        beforeSwitch: () async {
          final token = await PushService().getToken();
          if (token != null) {
            try {
              await supabase
                  .from('user_push_tokens')
                  .delete()
                  .eq('fcm_token', token);
            } catch (_) {}
          }
          await UploadQueue.instance.clear();
          await supabase.auth.signOut(scope: SignOutScope.local);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMessage = t.actionFailed(errorReasonIn(t, e));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _created == null ? t.setUpFrame : t.connectNamedFrame(_created!.name),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SmileSpacing.l),
          child: _created != null ? _buildCode(t, _created!) : _buildForm(t),
        ),
      ),
    );
  }

  Widget _buildCode(SmileTexts t, SmileFrame frame) {
    final code = frame.pairingCode ?? '';
    final pretty = code.length == 8
        ? '${code.substring(0, 4)} ${code.substring(4)}'
        : code;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        const SizedBox(height: SmileSpacing.l),
        Container(
          padding: const EdgeInsets.all(SmileSpacing.m),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(SmileRadius.l),
          ),
          child: QrImageView(
            data: 'smile:frame:$code',
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: SmileSpacing.l),
        SelectableText(
          pretty,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: SmileSpacing.m),
        Text(
          widget.existingFrame != null ? t.reconnectHint : t.connectFrameHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: SmileSpacing.l),
        if (widget.existingFrame != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.done),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: SmileSpacing.s),
              Text(t.waitingForFrame, style: TextStyle(color: muted)),
            ],
          ),
      ],
    );
  }

  Widget _buildForm(SmileTexts t) {
    final scheme = Theme.of(context).colorScheme;
    Widget choice(
      IconData icon,
      String title,
      String hint,
      VoidCallback onTap,
    ) => Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(SmileRadius.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(SmileRadius.l),
        onTap: _busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(SmileSpacing.m),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(SmileRadius.m),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: SmileSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.frameNameQuestion),
        const SizedBox(height: SmileSpacing.m),
        TextField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: t.name),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: SmileSpacing.l),
        if (_nameController.text.trim().isNotEmpty) ...[
          choice(
            SmileIcons.frame,
            t.anotherDevice,
            t.anotherDeviceHint,
            _forAnotherDevice,
          ),
          const SizedBox(height: SmileSpacing.m),
          choice(
            SmileIcons.person,
            t.thisDevice,
            t.thisDeviceHint,
            _forThisDevice,
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: SmileSpacing.l),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: SmileSpacing.m),
          Text(_errorMessage!, style: TextStyle(color: scheme.error)),
        ],
      ],
    );
  }
}
