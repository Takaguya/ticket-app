import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/app_config.dart';
import '../tokens/app_colors.dart';

/// An organiser's cover image, fetched from the Pin server.
///
/// [path] is what the server sends (`/images/events/<id>?v=...`), and it is
/// fetched from the server the app talks to ([AppConfig.apiBaseUrl], which an
/// [AppConfig] above this widget provides). It fills the space it is given.
///
/// Shows [fallback] when there is no picture, and if it cannot be loaded (no
/// connection, or the organiser removed it meanwhile), so a missing picture
/// never leaves a broken-image icon: the coloured placeholder stays.
class RemoteImage extends StatelessWidget {
  const RemoteImage({super.key, required this.path, required this.fallback});

  final String? path;

  /// What to show instead of a picture; it fills the same space.
  final Widget fallback;

  /// The full address of a server [path]: the server's address in front of it,
  /// or the address itself when it already is one.
  static String resolve(String baseUrl, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    final address = path;
    if (address == null) return fallback;

    return Image.network(
      resolve(context.read<AppConfig>().apiBaseUrl, address),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // A new picture has a new address; until it arrives keep what was shown.
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(color: AppColors.fill, child: SizedBox.expand());
      },
    );
  }
}
