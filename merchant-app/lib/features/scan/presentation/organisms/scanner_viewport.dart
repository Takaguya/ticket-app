import 'package:flutter/widgets.dart';

import '../../../../design_system/tokens/app_colors.dart';

/// Square frame with yellow corner brackets around the camera preview.
class ScannerViewport extends StatelessWidget {
  const ScannerViewport({super.key, required this.size, required this.child, this.overlay});

  final double size;

  /// The camera preview.
  final Widget child;

  /// Drawn over the preview, e.g. a spinner while a ticket is being checked.
  final Widget? overlay;

  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: ColoredBox(color: AppColors.darkSurface, child: child),
          ),
          ?overlay,
          const IgnorePointer(child: CustomPaint(painter: _CornersPainter())),
        ],
      ),
    );
  }
}

/// Four rounded yellow brackets, one in each corner.
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  static const double _arm = 44;
  static const double _stroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    const r = ScannerViewport._radius;
    final rect = (Offset.zero & size).deflate(_stroke / 2);

    // Top-left bracket, then the same shape mirrored into the other corners.
    Path bracket() => Path()
      ..moveTo(rect.left, rect.top + _arm)
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: const Radius.circular(r))
      ..lineTo(rect.left + _arm, rect.top);

    for (final (flipX, flipY) in [(false, false), (true, false), (false, true), (true, true)]) {
      canvas
        ..save()
        ..translate(flipX ? size.width : 0, flipY ? size.height : 0)
        ..scale(flipX ? -1 : 1, flipY ? -1 : 1)
        ..drawPath(bracket(), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => false;
}
