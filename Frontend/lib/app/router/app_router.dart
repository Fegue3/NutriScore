// lib/app/router/app_router.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
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
import '../../data/repositories/auth_repository.dart';
import '../../data/meals_api.dart'; // MealType, MealTypeX

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._repo) {
    _sub = _repo.authStateChanges.listen((_) => notifyListeners());
  }
  final AuthRepository _repo;
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Usa no main.dart:
/// final router = buildAppRouter(di.authRepository);
GoRouter buildAppRouter(AuthRepository repo) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([
      _AuthRefresh(repo),
      repo.routerRefresh,
    ]),
    redirect: (context, state) {
      if (!repo.bootstrapped) return null;

      final loc = state.matchedLocation;
      final atAuthHub = (loc == '/');
      final atLogin = (loc == '/login');
      final atSignup = (loc == '/signup');
      final atAuth = atAuthHub || atLogin || atSignup;
      final atOnboarding = (loc == '/onboarding');

      if (repo.isLoggingOut) return atAuth ? null : '/';
      if (!repo.isLoggedIn) return atAuth ? null : '/';

      final needsOnboarding = (repo.onboardingCompleted == false);
      if (needsOnboarding) return atOnboarding ? null : '/onboarding';

      if (atAuth) return '/dashboard';
      return null;
    },
    routes: [
      // Públicas (Auth)
      GoRoute(path: '/', builder: (_, __) => const AuthHubScreen()),
      GoRoute(path: '/login', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),

      // Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => OnboardingScreen(authRepository: repo),
      ),

      // Fullscreen fora do shell
      GoRoute(
        path: '/add-food',
        builder: (_, state) {
          // Pode vir por query (?meal=Almoço) ou por extra (enum)
          final ex = state.extra;
          final MealType? extraMeal = ex is MealType ? ex : null;
          final MealType? initialMeal =
              extraMeal ?? MealTypeX.fromLabelPt(state.uri.queryParameters['meal']);

          return AddFoodScreen(initialMeal: initialMeal);
        },
      ),

      // Detalhe do produto (tolerante a tipos vindos em 'extra')
      GoRoute(
        name: 'productDetail',
        path: '/product-detail',
        builder: (_, state) {
          final m = (state.extra as Map?) ?? {};

          num? n(Object? x) =>
              x is num ? x : (x is String ? num.tryParse(x) : null);

          // initialMeal pode chegar como MealType (enum) OU String
          final dynamic rawInitial = m['initialMeal'];
          final MealType? initialMeal = switch (rawInitial) {
            MealType v => v,
            _ => MealTypeX.fromLabelPt(rawInitial?.toString()),
          };

          return ProductDetailScreen(
            key: state.pageKey,
            barcode: m['barcode']?.toString(),
            name: m['name']?.toString() ?? 'Produto',
            brand: m['brand']?.toString(),
            origin: m['origin']?.toString(),
            baseQuantityLabel: m['baseQuantityLabel']?.toString() ?? '100 g',
            kcalPerBase: (n(m['kcalPerBase']) ?? 0).toInt(),
            proteinGPerBase: (n(m['proteinGPerBase']) ?? 0).toDouble(),
            carbsGPerBase: (n(m['carbsGPerBase']) ?? 0).toDouble(),
            fatGPerBase: (n(m['fatGPerBase']) ?? 0).toDouble(),
            saltGPerBase: n(m['saltGPerBase'])?.toDouble(),
            sugarsGPerBase: n(m['sugarsGPerBase'])?.toDouble(),
            satFatGPerBase: n(m['satFatGPerBase'])?.toDouble(),
            fiberGPerBase: n(m['fiberGPerBase'])?.toDouble(),
            sodiumGPerBase: n(m['sodiumGPerBase'])?.toDouble(),
            nutriScore: m['nutriScore']?.toString(),
            initialMeal: initialMeal,
          );
        },
      ),

      // Shell com bottom nav
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
}
