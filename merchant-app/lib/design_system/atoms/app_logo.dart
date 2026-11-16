import 'package:flutter/widgets.dart';

/// The Pin logo mark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 60});

  static const _asset = 'assets/images/pin_logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Pin',
    );
  }
}
