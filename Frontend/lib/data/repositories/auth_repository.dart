import 'dart:async';
import 'package:flutter/foundation.dart';

import '../auth_api.dart';
import '../auth_storage.dart';

/// Repositório simples para gerir sessão + notificar o router.
class AuthRepository {
  // Notificador usado pelo GoRouter para reavaliar redirects
  final ValueNotifier<int> _routerTick = ValueNotifier<int>(0);
  Listenable get routerRefresh => _routerTick;
  void _bumpRouter() => _routerTick.value++;

  // Stream para quem quiser ouvir mudanças de auth
  final _changes = StreamController<void>.broadcast();

  bool _isLoggedIn = false;
  bool _isLoggingOut = false;
  bool _onboardingCompleted = false;
  bool _bootstrapped = false; // 👈 evita redirects antes de bootstrap

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoggingOut => _isLoggingOut;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get bootstrapped => _bootstrapped;

  Stream<void> get authStateChanges => _changes.stream;

  /// Lê tokens e estado inicial (inclui flag de onboarding) e notifica router.
  Future<void> bootstrap() async {
    final access = await AuthStorage.I.readAccessToken();
    _isLoggedIn = access != null && access.isNotEmpty;
    AuthApi.I.setAccessToken(access);

    if (_isLoggedIn) {
      try {
        _onboardingCompleted = await AuthApi.I.getOnboardingCompleted();
      } catch (_) {
        // mantém o default (false) se falhar
      }
    }

    _bootstrapped = true; // 👈 marca como concluído
    _changes.add(null);
    _bumpRouter();
  }

  /// Após login com sucesso, guarda tokens e sincroniza flag de onboarding.
  Future<void> onLoginSuccess({
    required String accessToken,
    required String refreshToken,
  }) async {
    await AuthStorage.I.saveTokens(accessToken, refreshToken);
    AuthApi.I.setAccessToken(accessToken);

    _isLoggedIn = true;
    try {
      _onboardingCompleted = await AuthApi.I.getOnboardingCompleted();
    } catch (_) {}

    _changes.add(null);
    _bumpRouter();
  }

  /// Setter do flag de onboarding que também força refresh do router.
  void setOnboardingCompleted(bool v) {
    _onboardingCompleted = v;
    _changes.add(null);
    _bumpRouter();
  }

  /// Endpoint para apagar conta (idempotente para UX).
  Future<void> deleteAccount() async {
    try {
      await AuthApi.I.deleteAccount();
    } catch (_) {}
  }

  /// Logout seguro: sinaliza loggingOut, limpa estado e reavalia router.
  Future<void> logout() async {
    _isLoggingOut = true;
    _changes.add(null);
    _bumpRouter();

    _isLoggedIn = false;
    AuthApi.I.setAccessToken(null);
    _changes.add(null);
    _bumpRouter();

    await AuthStorage.I.clear();

    _isLoggingOut = false;
    _onboardingCompleted = false; // reset para próxima sessão
    _bootstrapped = false;        // precisa de novo bootstrap
    _changes.add(null);
    _bumpRouter();
  }
}
