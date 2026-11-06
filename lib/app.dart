import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodels/session_controller.dart';
import 'features/settings/presentation/viewmodels/settings_controller.dart';

/// Root widget. Expects a [SessionController] (and the repositories the
/// screens read) to be provided above it; `main.dart` does that. Both
/// themes follow the clinic's colour from [SettingsController] once it has
/// loaded (Phase 10); before that, and when signed out, they use teal.
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
    final seed =
        context.watch<SettingsController?>()?.settings?.themeColor.seed ??
        AppColors.seed;
    return MaterialApp.router(
      title: 'Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed: seed),
      darkTheme: AppTheme.dark(seed: seed),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
