import 'dart:async';
import '../auth_api.dart';
import '../auth_storage.dart';

/// Repositório simples para gerir sessão + notificar o router.
class AuthRepository {
  final _changes = StreamController<void>.broadcast();

  bool _isLoggedIn = false;
  bool _isLoggingOut = false;
  bool _onboardingCompleted = false; // 👈 novo

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoggingOut => _isLoggingOut;
  bool get onboardingCompleted => _onboardingCompleted;

  Stream<void> get authStateChanges => _changes.stream;

  Future<void> bootstrap() async {
    final access = await AuthStorage.I.readAccessToken();
    _isLoggedIn = access != null && access.isNotEmpty;
    AuthApi.I.setAccessToken(access);
    if (_isLoggedIn) {
      try { _onboardingCompleted = await AuthApi.I.getOnboardingCompleted(); } catch (_) {}
    }
    _changes.add(null);
  }

  Future<void> onLoginSuccess({
    required String accessToken,
    required String refreshToken,
  }) async {
    await AuthStorage.I.saveTokens(accessToken, refreshToken);
    AuthApi.I.setAccessToken(accessToken);
    _isLoggedIn = true;
    try { _onboardingCompleted = await AuthApi.I.getOnboardingCompleted(); } catch (_) {}
    _changes.add(null);
  }

  void setOnboardingCompleted(bool v) {
    _onboardingCompleted = v;
    _changes.add(null);
  }

  /// Chama o endpoint de apagar conta (usa Authorization).
  Future<void> deleteAccount() async {
    try {
      await AuthApi.I.deleteAccount();
    } catch (_) {
      // não rebentar UX; tratamos como idempotente
    }
  }

  /// Logout “à prova de redirect”: marca loggingOut, notifica, e só depois limpa storage.
  Future<void> logout() async {
    _isLoggingOut = true;
    _changes.add(null);

    _isLoggedIn = false;
    AuthApi.I.setAccessToken(null);
    _changes.add(null);

    await AuthStorage.I.clear();

    _isLoggingOut = false;
    _onboardingCompleted = false; // reset flag
    _changes.add(null);
  }
}
