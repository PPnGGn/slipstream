import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:slipstream/core/ui/widgets/close_circle_button.dart';
import 'package:slipstream/features/qr/data/qr_scan.dart';

// Full-screen camera. Pops with the scanned text, or with null if closed.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final _session = QrScanSession();

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final value = _session.accept(capture.barcodes.map((b) => b.rawValue));
    if (value == null || !mounted) return;
    context.pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: .expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(
              denied:
                  error.errorCode == MobileScannerErrorCode.permissionDenied,
            ),
            overlayBuilder: (context, constraints) => const _ScanFrame(),
          ),
          const SafeArea(
            child: Align(alignment: .topLeft, child: _CloseButton()),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.denied});

  final bool denied;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const .all(32),
        child: Text(
          denied
              ? 'Camera access denied. Allow it in the system settings.'
              : 'Camera is unavailable on this device.',
          textAlign: .center,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: .all(color: Colors.white, width: 3),
              borderRadius: .circular(24),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Point the camera at a QR code',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .all(8),
      child: CloseCircleButton(onPressed: () => context.pop()),
    );
  }
}
