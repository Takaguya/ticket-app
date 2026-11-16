import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth/auth_bloc.dart';

/// Keeps the signed-in person up to date while the app is open: when Pin
/// approves or suspends the business in the admin panel, the app shows it
/// within [every], and as soon as it comes back to the foreground.
/// Expects an [AuthBloc] above it.
class SessionRefresher extends StatefulWidget {
  const SessionRefresher({
    super.key,
    required this.child,
    this.every = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration every;

  @override
  State<SessionRefresher> createState() => _SessionRefresherState();
}

class _SessionRefresherState extends State<SessionRefresher> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.every, (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() => context.read<AuthBloc>().add(const AuthRefreshRequested());

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
