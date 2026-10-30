import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'placeholder_screen.dart';

/// Builds the app router. Auth-aware redirects are added in Phase 1.
GoRouter buildRouter({String initialLocation = AppRoutes.login}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const PlaceholderScreen(title: 'Login'),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, _) => const PlaceholderScreen(title: 'Change password'),
      ),
      GoRoute(
        path: AppRoutes.reception,
        builder: (_, _) => const PlaceholderScreen(title: 'Reception'),
      ),
      GoRoute(
        path: AppRoutes.doctor,
        builder: (_, _) => const PlaceholderScreen(title: 'Doctor'),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (_, _) => const PlaceholderScreen(title: 'Admin'),
      ),
    ],
  );
}
