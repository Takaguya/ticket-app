import 'package:flutter/widgets.dart';

/// The Pin logo: the mark alone, or the mark with the "Pin" wordmark.
class AppLogo extends StatelessWidget {
  /// The mark alone, e.g. in the home header.
  const AppLogo({super.key, this.height = 60}) : _asset = 'assets/images/pin_logo.png';

  /// The mark with the "Pin" wordmark, for the sign-in screen.
  const AppLogo.wordmark({super.key, this.height = 60})
    : _asset = 'assets/images/pin_wordmark.png';

  final String _asset;
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
