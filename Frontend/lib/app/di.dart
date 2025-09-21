import '../data/repositories/auth_repository.dart';

final di = _DI();

class _DI {
  late final AuthRepository authRepository;

  Future<void> init() async {
    authRepository = AuthRepository();
    await authRepository.bootstrap(); // lê tokens guardados
  }
}
