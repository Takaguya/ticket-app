import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../design_system/tokens/app_colors.dart';

/// Builds the live camera preview and reports each QR code it reads.
/// Injected so tests can run without a camera.
typedef QrCameraBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// The real camera, reading QR codes with the back lens.
class QrCameraView extends StatefulWidget {
  const QrCameraView({super.key, required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<QrCameraView> createState() => _QrCameraViewState();
}

class _QrCameraViewState extends State<QrCameraView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        widget.onCode(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error) => const _CameraMessage(
        'The camera is not available. Allow camera access in Settings, or enter the '
        'booking ID instead.',
      ),
      placeholderBuilder: (context) => const ColoredBox(color: AppColors.darkSurface),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkSurface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.onDarkMuted, height: 1.4),
          ),
        ),
      ),
    );
  }
}
