import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/di/injector.dart';
import 'core/config/app_config.dart';
import 'features/auth/presentation/bloc/auth/auth_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();

  // Look for a saved session straight away; the splash screen shows meanwhile.
  final authBloc = sl<AuthBloc>()..add(const AuthStarted());
  runApp(PinApp(authBloc: authBloc, config: sl<AppConfig>()));
}
