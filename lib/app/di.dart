// lib/app/di.dart
import 'dart:async';

class _AuthRepositoryFake {
  bool isLoggedIn = false;
  final _ctrl = StreamController<void>.broadcast();

  Stream<void> get authStateChanges => _ctrl.stream;
  void signIn() { isLoggedIn = true; _ctrl.add(null); }
  void signOut() { isLoggedIn = false; _ctrl.add(null); }
}

class _DI {
  late final _AuthRepositoryFake authRepository;

  Future<void> init() async {
    authRepository = _AuthRepositoryFake();
  }
}

final di = _DI();
