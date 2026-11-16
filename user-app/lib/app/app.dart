import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../design_system/theme/app_theme.dart';
import '../features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'router/app_router.dart';

/// Root widget: provides the app-wide [AuthBloc] and [AppConfig] (where the server is,
/// for fetching pictures), the theme and the router.
class PinApp extends StatefulWidget {
  const PinApp({super.key, required this.authBloc, this.config = AppConfig.fromEnvironment});

  final AuthBloc authBloc;
  final AppConfig config;

  @override
  State<PinApp> createState() => _PinAppState();
}

class _PinAppState extends State<PinApp> {
  late final GoRouter _router = createAppRouter(widget.authBloc);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: widget.config,
      child: BlocProvider.value(
        value: widget.authBloc,
        child: MaterialApp.router(
          title: 'Pin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}
