import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_hub_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/auth/onboarding_screen.dart';

import '../../features/home/home_screen.dart';
import '../../features/nutrition/nutrition_screen.dart';
import '../../features/nutrition/add_food_screen.dart';
import '../../features/nutrition/product_detail_screen.dart';
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
  refreshListenable: Listenable.merge([
    _AuthRefresh(),
    di.authRepository.routerRefresh,
  ]),
  redirect: (context, state) {
    // ⚠️ enquanto não tiver bootstrapped, não fazemos redirect nenhum
    if (!di.authRepository.bootstrapped) return null;

    final logged = di.authRepository.isLoggedIn;
    final loggingOut = di.authRepository.isLoggingOut;
    final pending = logged && !di.authRepository.onboardingCompleted;

    final loc = state.matchedLocation;
    final isAuthRoute = (loc == '/' || loc == '/login' || loc == '/signup');
    final isOnboarding = (loc == '/onboarding');

    if (!logged) {
      if (isOnboarding) return '/signup';
      if (!isAuthRoute) return '/';
      return null;
    }
    if (pending && !isOnboarding) return '/onboarding';
    if (!pending && isAuthRoute && !loggingOut) return '/dashboard';
    return null;
  },
  routes: [
    // Públicas
    GoRoute(path: '/', builder: (_, __) => const AuthHubScreen()),
    GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),

    // Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => OnboardingScreen(authRepository: di.authRepository),
    ),

    // Fullscreen fora do shell
    GoRoute(
      path: '/add-food',
      builder: (_, state) =>
          AddFoodScreen(initialMeal: state.uri.queryParameters['meal']),
    ),

    // Detalhe do produto — compatível com ProductDetailScreen v8
    GoRoute(
      name: 'productDetail',
      path: '/product-detail',
      builder: (_, state) {
        final m = (state.extra as Map?) ?? {};
        num? n(Object? x) =>
            x is num ? x : (x is String ? num.tryParse(x) : null);

        return ProductDetailScreen(
          key: state.pageKey,
          // METADADOS
          name: m["name"] ?? "Produto",
          brand: m["brand"] as String?,
          origin: m["origin"] as String?,
          baseQuantityLabel: m["baseQuantityLabel"] as String? ?? "100 g",

          // NUTRIMENTOS por base
          kcalPerBase: (n(m["kcalPerBase"]) ?? 0).toInt(),
          proteinGPerBase: (n(m["proteinGPerBase"]) ?? 0).toDouble(),
          carbsGPerBase: (n(m["carbsGPerBase"]) ?? 0).toDouble(),
          fatGPerBase: (n(m["fatGPerBase"]) ?? 0).toDouble(),
          saltGPerBase: n(m["saltGPerBase"])?.toDouble(),
          sugarsGPerBase: n(m["sugarsGPerBase"])?.toDouble(),
          satFatGPerBase: n(m["satFatGPerBase"])?.toDouble(),
          fiberGPerBase: n(m["fiberGPerBase"])?.toDouble(),
          sodiumGPerBase: n(m["sodiumGPerBase"])?.toDouble(),

          // EXTRA
          nutriScore: m["nutriScore"] as String?,
        );
      },
    ),

    // Shell com bottom nav
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
