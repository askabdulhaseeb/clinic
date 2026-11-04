import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodels/session_controller.dart';

/// Root widget. Expects a [SessionController] (and the repositories the
/// screens read) to be provided above it; `main.dart` does that.
class ClinicApp extends StatefulWidget {
  const ClinicApp({super.key, this.router});

  /// Override in tests; defaults to [buildRouter] with the provided session.
  final GoRouter? router;

  @override
  State<ClinicApp> createState() => _ClinicAppState();
}

class _ClinicAppState extends State<ClinicApp> {
  late final GoRouter _router =
      widget.router ?? buildRouter(session: context.read<SessionController>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
