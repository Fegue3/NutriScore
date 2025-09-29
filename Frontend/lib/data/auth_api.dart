import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'auth_storage.dart';

class AuthApi {
  AuthApi._();
  static final AuthApi I = AuthApi._();

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('BACKEND_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

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
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = res.data as Map<String, dynamic>;
      final tokens = (data['tokens'] as Map<String, dynamic>?) ?? {};
      final access =
          (tokens['accessToken'] as String?) ??
          (tokens['access_token'] as String?) ??
          '';
      final refresh =
          (tokens['refreshToken'] as String?) ??
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
      throw 'Falha no login: $msg (type=$type, code=$code, url=$url)';
    }
  }

  Future<({String accessToken, String refreshToken, Map<String, dynamic> user})>
  signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );

      final data = res.data as Map<String, dynamic>;
      final tokens = (data['tokens'] as Map<String, dynamic>?) ?? {};
      final access =
          (tokens['accessToken'] as String?) ??
          (tokens['access_token'] as String?) ??
          '';
      final refresh =
          (tokens['refreshToken'] as String?) ??
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

  /// Refresh do access/refresh token.
  Future<({String accessToken, String refreshToken})> refresh({
    required String refreshToken,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data as Map<String, dynamic>;
      final tokens = (data['tokens'] as Map<String, dynamic>?) ?? {};
      final access =
          (tokens['accessToken'] as String?) ??
          (tokens['access_token'] as String?) ??
          '';
      final newRefresh =
          (tokens['refreshToken'] as String?) ??
          (tokens['refresh_token'] as String?) ??
          '';
      if (access.isEmpty || newRefresh.isEmpty) {
        throw 'Tokens inválidos no refresh';
      }
      return (accessToken: access, refreshToken: newRefresh);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      throw 'Falha no refresh: $msg (code=$code)';
    }
  }

  /// DELETE /auth/me — apaga a conta atual (idempotente: 204/200/404 são aceites).
  Future<void> deleteAccount() async {
    final token = await AuthStorage.I.readAccessToken();
    if (token == null || token.isEmpty) {
      throw 'Sem access token para apagar conta';
    }
    final res = await _dio.delete(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (res.statusCode != 204 &&
        res.statusCode != 200 &&
        res.statusCode != 404) {
      throw 'Falha ao apagar conta (HTTP ${res.statusCode})';
    }
  }

  /// Upsert metas/perfil
  Future<void> upsertGoals({
    String? sex,
    int? heightCm,
    double? currentWeightKg,
    double? targetWeightKg,
    String? activityLevel,
    int? dailyCalories,
    int? carbPercent,
    int? proteinPercent,
    int? fatPercent,
    bool? lowSalt,
    bool? lowSugar,
    bool? vegetarian,
    bool? vegan,
    String? allergens,
    DateTime? dateOfBirth,
    DateTime? targetDate,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (sex != null) 'sex': sex,
        if (heightCm != null) 'heightCm': heightCm,
        if (currentWeightKg != null) 'currentWeightKg': currentWeightKg,
        if (targetWeightKg != null) 'targetWeightKg': targetWeightKg,
        if (activityLevel != null) 'activityLevel': activityLevel,
        if (dailyCalories != null) 'dailyCalories': dailyCalories,
        if (carbPercent != null) 'carbPercent': carbPercent,
        if (proteinPercent != null) 'proteinPercent': proteinPercent,
        if (fatPercent != null) 'fatPercent': fatPercent,
        if (lowSalt != null) 'lowSalt': lowSalt,
        if (lowSugar != null) 'lowSugar': lowSugar,
        if (vegetarian != null) 'vegetarian': vegetarian,
        if (vegan != null) 'vegan': vegan,
        if (allergens != null) 'allergens': allergens,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
        if (targetDate != null) 'targetDate': targetDate.toIso8601String(),
      };

      final res = await _dio.put('/api/me/goals', data: payload);
      if (res.statusCode != 200) {
        throw 'Falha ao guardar metas (HTTP ${res.statusCode})';
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['error'] ??
                        e.response!.data['message'] ??
                        e.message)
                    as Object?)
                .toString()
          : (e.message ?? 'Erro de rede');
      final code = e.response?.statusCode;
      throw 'Erro ao guardar metas: $msg (code=$code)';
    }
  }

  // -------- Flags de onboarding --------
  Future<bool> getOnboardingCompleted() async {
    try {
      final res = await _dio.get('/api/me/flags');
      final v = res.data?['flags']?['onboardingCompleted'];
      return v == true;
    } on DioException {
      // Propaga o erro (ex.: 401) para o repo decidir fazer refresh ou não
      rethrow;
    }
  }

  Future<void> setOnboardingCompleted(bool value) async {
    try {
      final res = await _dio.patch(
        '/api/me/flags',
        data: {'onboardingCompleted': value},
      );
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      throw 'PATCH /api/me/flags falhou (status=$status, body=$body)';
    }
  }
}
