import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  AuthStorage._();
  static final AuthStorage I = AuthStorage._();

  final _s = const FlutterSecureStorage();
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<void> saveTokens(String access, String refresh) async {
    await _s.write(key: _kAccess, value: access);
    if (refresh.isNotEmpty) {
      await _s.write(key: _kRefresh, value: refresh);
    }
  }

  Future<String?> readAccessToken() => _s.read(key: _kAccess);
  Future<String?> readRefreshToken() => _s.read(key: _kRefresh);
  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
  }
}
