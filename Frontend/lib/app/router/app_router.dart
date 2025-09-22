import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_hub_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/nutrition/nutrition_screen.dart';
import '../../features/nutrition/add_food_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/auth/onboarding_screen.dart';
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
    final logged      = di.authRepository.isLoggedIn;
    final loggingOut  = di.authRepository.isLoggingOut;
    final pending     = logged && !di.authRepository.onboardingCompleted;

    final loc = state.matchedLocation;
    final isAuthRoute  = loc == '/' || loc == '/login' || loc == '/signup';
    final isOnboarding = loc == '/onboarding';

    // não autenticado
    if (!logged) {
      if (isOnboarding) return '/signup';
      if (!isAuthRoute) return '/';
      return null;
    }

    // autenticado, mas ainda não concluiu onboarding → força onboarding
    if (pending && !isOnboarding) return '/onboarding';

    // autenticado e já concluiu, evita voltar ao hub/login/signup
    if (!pending && isAuthRoute && !loggingOut) return '/dashboard';

    return null;
  },
  routes: [
    // públicas
    GoRoute(path: '/',      builder: (_, __) => const AuthHubScreen()),
    GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/signup',builder: (_, __) => const SignUpScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => OnboardingScreen(
        authRepository: di.authRepository, // sem const
      ),
    ),

    // full screen fora do shell
    GoRoute(
      path: '/add-food',
      builder: (_, state) => AddFoodScreen(
        initialMeal: state.uri.queryParameters['meal'],
      ),
    ),

    // área com bottom nav (shell)
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/diary',
          pageBuilder: (_, __) => const NoTransitionPage(child: NutritionScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, __) => const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),
  ],
);
