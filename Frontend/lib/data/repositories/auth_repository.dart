import 'dart:async';
import 'package:flutter/foundation.dart';

import '../auth_api.dart';
import '../auth_storage.dart';

/// Repositório de sessão + notificação do router.
class AuthRepository {
  // ---- Notificador para o GoRouter reavaliar redirects
  final ValueNotifier<int> _routerTick = ValueNotifier<int>(0);
  Listenable get routerRefresh => _routerTick;
  void _bumpRouter() => _routerTick.value++;

  // ---- Stream para quem quiser ouvir mudanças de auth
  final _changes = StreamController<void>.broadcast();
  Stream<void> get authStateChanges => _changes.stream;

  // ---- Estado interno
  bool _isLoggedIn = false;
  bool _isLoggingOut = false;
  bool _onboardingCompleted = false;
  bool _bootstrapped = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoggingOut => _isLoggingOut;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get bootstrapped => _bootstrapped;

  // ---------------------------------------------------------------------------
  // Ciclo de vida
  // ---------------------------------------------------------------------------

  /// Lê tokens guardados e sincroniza o flag de onboarding.
  Future<void> bootstrap() async {
    final access = await AuthStorage.I.readAccessToken();
    _isLoggedIn = access != null && access.isNotEmpty;
    AuthApi.I.setAccessToken(access);

    if (_isLoggedIn) {
      try {
        _onboardingCompleted = await AuthApi.I.getOnboardingCompleted();
      } catch (_) {
        _onboardingCompleted = false;
      }
    }

    _bootstrapped = true;
    _changes.add(null);
    _bumpRouter();
  }

  /// Após login com sucesso.
  Future<void> onLoginSuccess({
    required String accessToken,
    required String refreshToken,
  }) async {
    await AuthStorage.I.saveTokens(accessToken, refreshToken);
    AuthApi.I.setAccessToken(accessToken);

    _isLoggedIn = true;
    try {
      _onboardingCompleted = await AuthApi.I.getOnboardingCompleted();
    } catch (_) {
      _onboardingCompleted = false;
    }

    _changes.add(null);
    _bumpRouter();
  }

  /// Atualiza o estado do onboarding e notifica o router.
  void setOnboardingCompleted(bool v) {
    _onboardingCompleted = v;
    _changes.add(null);
    _bumpRouter();
  }

  // ---------------------------------------------------------------------------
  // Ações de conta/sessão
  // ---------------------------------------------------------------------------

  /// Apaga a conta no servidor (idempotente para UX).
  Future<void> deleteAccount() async {
    try {
      await AuthApi.I.deleteAccount(); // se não existir no backend, faz no-op
    } catch (_) {
      // ignora falha para não bloquear o utilizador
    }
  }

  /// Logout local (não chama endpoint de logout do server).
  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    _changes.add(null);
    _bumpRouter();

    await _clearSessionFlags();
  }

  /// Expira a sessão (ex.: recebeu 401 num request).
  Future<void> expireSession() async {
    await _clearSessionFlags();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _clearSessionFlags() async {
    _isLoggedIn = false;
    AuthApi.I.setAccessToken(null);
    await AuthStorage.I.clear();

    _isLoggingOut = false;
    _onboardingCompleted = false;

    // Mantém bootstrapped = true para o router decidir imediatamente
    _bootstrapped = true;

    _changes.add(null);
    _bumpRouter();
  }

  // dispose opcional (se alguma vez fores destruir o repositório)
  void dispose() {
    _changes.close();
    _routerTick.dispose();
  }
}
