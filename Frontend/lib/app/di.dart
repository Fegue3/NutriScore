// lib/app/di.dart
import '../data/repositories/auth_repository.dart';

final di = _DI();

class _DI {
  AuthRepository? _authRepository;
  bool get isReady => _authRepository != null;

  AuthRepository get authRepository {
    if (_authRepository == null) {
      throw StateError('DI not initialized. Call di.init() first.');
    }
    return _authRepository!;
  }

  Future<void> init() async {
    _authRepository = AuthRepository();
    await _authRepository!.bootstrap(); // lê tokens guardados
  }
}
