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

/// Listener antigo (continua a ouvir mudanças de auth “macro”)
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    di.authRepository.authStateChanges.listen((_) => notifyListeners());
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  // 🔧 IMPORTANTE: agora o router refresca com authStateChanges **e**
  // com o "tick" emitido quando muda o onboardingCompleted/bootstrap/etc.
  refreshListenable: Listenable.merge([
    _AuthRefresh(),
    di.authRepository.routerRefresh, // <— novo
  ]),
  redirect: (context, state) {
    final logged     = di.authRepository.isLoggedIn;
    final loggingOut = di.authRepository.isLoggingOut;
    final pending    = logged && !di.authRepository.onboardingCompleted;

    final loc = state.matchedLocation;
    final isAuthRoute  = (loc == '/' || loc == '/login' || loc == '/signup');
    final isOnboarding = (loc == '/onboarding');

    // Não autenticado
    if (!logged) {
      if (isOnboarding) return '/signup';
      if (!isAuthRoute) return '/';
      return null;
    }

    // Autenticado mas sem onboarding -> força onboarding
    if (pending && !isOnboarding) return '/onboarding';

    // Autenticado e onboarding concluído -> evita voltar ao hub/login/signup
    if (!pending && isAuthRoute && !loggingOut) return '/dashboard';

    return null;
  },
  routes: [
    // Públicas
    GoRoute(path: '/',       builder: (_, __) => const AuthHubScreen()),
    GoRoute(path: '/login',  builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),

    // Onboarding (fora do shell)
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => OnboardingScreen(
        authRepository: di.authRepository,
      ),
    ),

    // Fullscreen fora do shell
    GoRoute(
      path: '/add-food',
      builder: (_, state) => AddFoodScreen(
        initialMeal: state.uri.queryParameters['meal'],
      ),
    ),

    // Área com bottom nav (Shell)
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (_, __) =>
              const NoTransitionPage(child: HomeScreen()),
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
