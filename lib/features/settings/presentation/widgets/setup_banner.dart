import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';

/// Shown on Admin pages while `settings/general` is missing (UI_DESIGN §3.4).
class SetupBanner extends StatelessWidget {
  const SetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MaterialBanner(
      key: const Key('setup-banner'),
      backgroundColor: scheme.tertiaryContainer,
      leading: Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
      content: Text(
        'The clinic is not set up yet. Run the initial setup to create the '
        'clinic settings, departments and visit types.',
        style: TextStyle(color: scheme.onTertiaryContainer),
      ),
      actions: [
        FilledButton(
          key: const Key('setup-banner-action'),
          onPressed: () => context.go(AppRoutes.adminSetup),
          child: const Text('Run setup'),
        ),
      ],
    );
  }
}
