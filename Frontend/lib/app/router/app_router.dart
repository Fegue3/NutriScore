import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_hub_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/nutrition/nutrition_screen.dart';
import '../../features/nutrition/add_food_screen.dart'; // <-- NOVO
import '../../features/settings/settings_screen.dart';
import '../app_shell.dart';
import '../di.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    di.authRepository.authStateChanges.listen((_) => notifyListeners());
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _AuthRefresh(),
  redirect: (context, state) {
    final logged = di.authRepository.isLoggedIn;
    final isAuthRoute = state.matchedLocation == '/login'
        || state.matchedLocation == '/signup'
        || state.matchedLocation == '/';

    if (!logged && !isAuthRoute) return '/';
    if (logged && isAuthRoute) return '/dashboard';
    return null;
  },
  routes: [
    // Rotas públicas / auth
    GoRoute(path: '/', builder: (_, __) => const AuthHubScreen()),
    GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),

    // ⚠️ Full-screen standalone (sem bottom nav)
    GoRoute(
      path: '/add-food',
      builder: (_, state) {
        final mealParam = state.uri.queryParameters['meal'];
        return AddFoodScreen(initialMeal: mealParam);
      },
    ),

    // Área com shell (navbar)
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/diary',
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: NutritionScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
  ],
);
