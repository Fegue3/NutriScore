import 'dart:async';
import 'package:flutter/foundation.dart';

import '../auth_api.dart';
import '../auth_storage.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

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
  AuthStatus _status = AuthStatus.unknown;
  bool _isLoggingOut = false;
  bool? _onboardingCompleted; // null = desconhecido
  bool _bootstrapped = false;

  AuthStatus get status => _status;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get isLoggingOut => _isLoggingOut;
  bool? get onboardingCompleted => _onboardingCompleted;
  bool get bootstrapped => _bootstrapped;

  // ---------------------------------------------------------------------------
  // Ciclo de vida
  // ---------------------------------------------------------------------------

  /// Lê tokens guardados e sincroniza o flag de onboarding, com refresh se preciso.
  Future<void> bootstrap() async {
    final access = await AuthStorage.I.readAccessToken();
    final refresh = await AuthStorage.I.readRefreshToken();

    AuthApi.I.setAccessToken(access);

    if (access != null && access.isNotEmpty) {
      _status = AuthStatus.authenticated;
      // tenta buscar flags; se der 401 tenta refresh
      await _fetchFlagsWithRefresh(refreshToken: refresh);
    } else {
      _status = AuthStatus.unauthenticated;
      _onboardingCompleted = null;
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

    _status = AuthStatus.authenticated;
    await _fetchFlagsWithRefresh(refreshToken: refreshToken);

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
      await AuthApi.I.deleteAccount();
    } catch (_) {/* no-op */}
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
  // Refresh & helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchFlagsWithRefresh({String? refreshToken}) async {
    try {
      _onboardingCompleted = await AuthApi.I.getOnboardingCompleted();
      return;
    } catch (e) {
      // tenta refresh só se houver refreshToken
      final rt = refreshToken ?? await AuthStorage.I.readRefreshToken();
      if (rt == null || rt.isEmpty) {
        // sem refresh -> cai para unauth
        _status = AuthStatus.unauthenticated;
        _onboardingCompleted = null;
        return;
      }

      final ok = await tryRefresh(rt);
      if (!ok) {
        _status = AuthStatus.unauthenticated;
        _onboardingCompleted = null;
        return;
      }

      // após refresh, tentar de novo
      _onboardingCompleted = await AuthApi.I.getOnboardingCompleted();
    }
  }

  /// Faz refresh com o backend. True se conseguiu.
  Future<bool> tryRefresh(String refreshToken) async {
    try {
      final t = await AuthApi.I.refresh(refreshToken: refreshToken);
      await AuthStorage.I.saveTokens(t.accessToken, t.refreshToken);
      AuthApi.I.setAccessToken(t.accessToken);
      _status = AuthStatus.authenticated;
      return true;
    } catch (_) {
      await AuthStorage.I.clear();
      AuthApi.I.setAccessToken(null);
      return false;
    }
  }

  Future<void> _clearSessionFlags() async {
    _status = AuthStatus.unauthenticated;
    AuthApi.I.setAccessToken(null);
    await AuthStorage.I.clear();

    _isLoggingOut = false;
    _onboardingCompleted = null; // << NÃO assumir false
    _bootstrapped = true;

    _changes.add(null);
    _bumpRouter();
  }

  void dispose() {
    _changes.close();
    _routerTick.dispose();
  }
}
