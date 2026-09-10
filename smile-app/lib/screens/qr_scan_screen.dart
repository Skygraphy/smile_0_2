import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Generic in-app QR scanner. Pops with the decoded string on first
/// successful scan.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.title = 'QR-Code scannen'});

  final String title;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
