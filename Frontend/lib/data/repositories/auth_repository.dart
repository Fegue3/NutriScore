import 'dart:async';
import '../auth_api.dart';
import '../auth_storage.dart';

/// Repositório simples para gerir sessão + notificar o router.
class AuthRepository {
  final _changes = StreamController<void>.broadcast();
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;
  Stream<void> get authStateChanges => _changes.stream;

  Future<void> bootstrap() async {
    final access = await AuthStorage.I.readAccessToken();
    _isLoggedIn = access != null && access.isNotEmpty;
    AuthApi.I.setAccessToken(access);
    _changes.add(null);
  }

  Future<void> onLoginSuccess({
    required String accessToken,
    required String refreshToken,
  }) async {
    await AuthStorage.I.saveTokens(accessToken, refreshToken);
    AuthApi.I.setAccessToken(accessToken);
    _isLoggedIn = true;
    _changes.add(null);
  }

  Future<void> logout() async {
    await AuthStorage.I.clear();
    AuthApi.I.setAccessToken(null);
    _isLoggedIn = false;
    _changes.add(null);
  }
}
