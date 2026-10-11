import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smile_design_system/smile_design_system.dart';

import '../main.dart';
import '../services/invite_service.dart';
import '../services/offline.dart';
import '../widgets/friendly_error.dart';
import 'channel_feed_screen.dart';

/// The invited side (decided 2026-10-11): scan the QR code someone shows
/// you -- in at once -- or type the code from a message -- then the
/// album's admins decide.
class ScanCodeScreen extends StatefulWidget {
  const ScanCodeScreen({super.key});

  @override
  State<ScanCodeScreen> createState() => _ScanCodeScreenState();
}

class _ScanCodeScreenState extends State<ScanCodeScreen> {
  final _service = InviteService();
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _busy = false;

  @override
  void dispose() {
    unawaited(_scanner.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.toLowerCase().startsWith('smile:invite:')) {
        unawaited(_redeem(value, viaQr: true));
        return;
      }
    }
  }

  Future<void> _typeCode() async {
    final t = SmileTexts.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.typeCode),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: t.codeFieldHint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.actionCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text(t.ok)),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    await _redeem(code.trim(), viaQr: false);
  }

  Future<void> _redeem(String code, {required bool viaQr, String? spaceId}) async {
    final t = SmileTexts.of(context);
    setState(() => _busy = true);
    unawaited(_scanner.stop());
    try {
      final result = await _service.redeem(code, viaQr: viaQr, spaceId: spaceId);
      if (!mounted) return;
      if (result.status == 'needs_space') {
        final picked = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(t.redeemPickSpace),
            children: [
              for (final space in result.spaces)
                SimpleDialogOption(onPressed: () => Navigator.of(context).pop(space.id), child: Text(space.name)),
            ],
          ),
        );
        if (picked == null || !mounted) {
          _resume();
          return;
        }
        await _redeem(code, viaQr: viaQr, spaceId: picked);
        return;
      }
      await _finish(result);
    } catch (e) {
      if (!mounted) return;
      if (Offline.isConnectionError(e)) {
        await showNoConnection(context);
      } else {
        final message = switch (e) {
          InviteException(code: 'invalid_code') => t.codeInvalid,
          InviteException(code: 'expired_code') => t.codeExpired,
          InviteException(code: 'qr_only') => t.codeQrOnly,
          InviteException(code: 'no_space') => t.codeNoSpace,
          _ => t.actionFailed(errorReason(context, e)),
        };
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.ok))],
          ),
        );
      }
      _resume();
    }
  }

  void _resume() {
    if (!mounted) return;
    setState(() => _busy = false);
    unawaited(_scanner.start());
  }

  Future<void> _finish(RedeemResult result) async {
    final t = SmileTexts.of(context);
    final messenger = scaffoldMessengerKey.currentState;
    final navigator = Navigator.of(context);
    void say(String text) => messenger?.showSnackBar(SnackBar(content: Text(text)));

    if (result.status == 'requested') {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.redeemRequestedTitle),
          content: Text(t.redeemRequested(result.channelName ?? result.spaceName ?? '')),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.ok))],
        ),
      );
      navigator.pop();
      return;
    }
    switch (result.kind) {
      case 'album_member':
        say(result.status == 'joined' ? t.redeemJoinedAlbum(result.channelName ?? '') : t.redeemAlready);
        // Straight into the album, like after joining a WhatsApp group.
        await navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChannelFeedScreen(channelId: result.channelId!, channelName: result.channelName ?? ''),
          ),
        );
      case 'album_share':
        say(result.status == 'joined'
            ? t.redeemJoinedShare(result.channelName ?? '', result.spaceName ?? '')
            : t.redeemAlready);
        navigator.pop();
      default:
        say(result.status == 'joined' ? t.redeemJoinedCoAdmin(result.spaceName ?? '') : t.redeemAlready);
        navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SmileTexts.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.scanCode)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SmileSpacing.l),
                      child: Text(t.cameraUnavailable, textAlign: TextAlign.center),
                    ),
                  ),
                ),
                // The frame to hold the code in.
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(SmileRadius.l),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: SmileSpacing.l,
                  child: Text(
                    t.scanHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 6)]),
                  ),
                ),
                if (_busy) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(SmileSpacing.s),
              child: TextButton.icon(
                onPressed: _busy ? null : _typeCode,
                icon: const Icon(SmileIcons.inviteCode),
                label: Text(t.typeCode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
