// data/auth_api.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

class AuthApi {
  AuthApi._();
  static final AuthApi I = AuthApi._();

  /// Define o host automaticamente consoante o alvo.
  /// Pode ser sobrescrito via:
  ///   flutter run --dart-define=BACKEND_URL=http://IP:3000
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('BACKEND_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) return 'http://localhost:3000';        // web (dev)
    if (Platform.isAndroid) return 'http://10.0.2.2:3000'; // emulador Android
    return 'http://localhost:3000';                     // iOS simulator / desktop
  }

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Injeta/remover o header Authorization conforme existir token.
  void setAccessToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<({String accessToken, String refreshToken, Map<String, dynamic> user})>
      signIn({required String email, required String password}) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = res.data as Map<String, dynamic>;
      final tokens = (data['tokens'] as Map<String, dynamic>?) ?? {};
      final access = (tokens['accessToken'] as String?) ??
          (tokens['access_token'] as String?) ??
          '';
      final refresh = (tokens['refreshToken'] as String?) ??
          (tokens['refresh_token'] as String?) ??
          '';

      if (access.isEmpty) throw 'Access token não recebido';
      return (
        accessToken: access,
        refreshToken: refresh,
        user: (data['user'] ?? {}) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      final code = e.response?.statusCode;
      final type = e.type; // connectTimeout, badResponse, connectionError, etc.
      final url = e.requestOptions.uri.toString();
      throw 'Falha no login: $msg (type=$type, code=$code, url=$url)';
    }
  }

  Future<({String accessToken, String refreshToken, Map<String, dynamic> user})>
      signUp({required String email, required String password, String? name}) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
      });

      final data = res.data as Map<String, dynamic>;
      final tokens = (data['tokens'] as Map<String, dynamic>?) ?? {};
      final access = (tokens['accessToken'] as String?) ??
          (tokens['access_token'] as String?) ??
          '';
      final refresh = (tokens['refreshToken'] as String?) ??
          (tokens['refresh_token'] as String?) ??
          '';

      if (access.isEmpty) throw 'Access token não recebido';
      return (
        accessToken: access,
        refreshToken: refresh,
        user: (data['user'] ?? {}) as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      final code = e.response?.statusCode;
      final type = e.type;
      final url = e.requestOptions.uri.toString();
      throw 'Falha no registo: $msg (type=$type, code=$code, url=$url)';
    }
  }
}
