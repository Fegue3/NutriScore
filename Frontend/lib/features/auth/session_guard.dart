// features/auth/session_guard.dart
import 'package:flutter/foundation.dart';
import '../../data/auth_storage.dart';

class SessionGuard extends ChangeNotifier {
  SessionGuard._();
  static final I = SessionGuard._();

  bool _authenticated = false;
  bool get isAuthenticated => _authenticated;

  Future<void> bootstrap() async {
    final t = await AuthStorage.I.readAccessToken();
    _authenticated = t != null && t.isNotEmpty;
    notifyListeners(); // faz o router reavaliar
  }

  void setAuthenticated(bool v) {
    _authenticated = v;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthStorage.I.clear();
    _authenticated = false;
    notifyListeners();
  }
}
