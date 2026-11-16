import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../design_system/theme/app_theme.dart';
import '../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../features/scan/presentation/organisms/qr_camera_view.dart';
import 'router/app_router.dart';

/// Root widget: provides the app-wide [AuthBloc], the theme and the router.
class MerchantApp extends StatefulWidget {
  const MerchantApp({super.key, required this.authBloc, this.cameraBuilder});

  final AuthBloc authBloc;

  /// Replaces the camera preview, e.g. in tests. Null uses the real camera.
  final QrCameraBuilder? cameraBuilder;

  @override
  State<MerchantApp> createState() => _MerchantAppState();
}

class _MerchantAppState extends State<MerchantApp> {
  late final GoRouter _router = createAppRouter(
    widget.authBloc,
    cameraBuilder: widget.cameraBuilder,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.authBloc,
      child: MaterialApp.router(
        title: 'Pin Merchant',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
