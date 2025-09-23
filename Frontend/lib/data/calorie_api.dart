// lib/data/calorie_api.dart
import 'package:dio/dio.dart';

import 'auth_api.dart';      // mantém o baseUrl
import 'auth_storage.dart';  // lê o access token guardado

class CalorieApi {
  CalorieApi._();
  static final CalorieApi I = CalorieApi._();

  String get baseUrl => AuthApi.baseUrl;
  static const String PATH_PREFIX = '/api';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  String? _overrideAccessToken;
  void setAccessToken(String? token) {
    _overrideAccessToken = (token != null && token.isNotEmpty) ? token : null;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = _overrideAccessToken ?? await AuthStorage.I.readAccessToken();
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  // -------- ENDPOINT: /api/calories/daily -----------
  // Se 'date' for null, o backend assume "hoje".
  Future<({
    String? date,
    String? timezone,
    int targetCalories,
    int consumedCalories,
    int remaining,
    int overBy,
    Map<String, dynamic>? macros,
  })> getDaily({DateTime? date, String? timezone}) async {
    try {
      final headers = await _authHeaders();

      String? dateParam;
      if (date != null) {
        final y = date.year.toString().padLeft(4, '0');
        final m = date.month.toString().padLeft(2, '0');
        final d = date.day.toString().padLeft(2, '0');
        dateParam = '$y-$m-$d';
      }

      final uri = Uri.parse('$baseUrl$PATH_PREFIX/calories/daily').replace(
        queryParameters: {
          if (dateParam != null) 'date': dateParam,
          if (timezone != null && timezone.isNotEmpty) 'tz': timezone,
        },
      );

      final res = await _dio.getUri(uri, options: Options(headers: headers));
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.data}';
      }

      final data = (res.data as Map).cast<String, dynamic>();
      return (
        date: data['date'] as String?,
        timezone: data['timezone'] as String?,
        targetCalories: (data['targetCalories'] as num?)?.toInt() ?? 0,
        consumedCalories: (data['consumedCalories'] as num?)?.toInt() ?? 0,
        remaining: (data['remaining'] as num?)?.toInt()
            ?? (((data['targetCalories'] as num?)?.toInt() ?? 0) - ((data['consumedCalories'] as num?)?.toInt() ?? 0)),
        overBy: (data['overBy'] as num?)?.toInt() ?? 0,
        macros: data['macros'] is Map ? (data['macros'] as Map).cast<String, dynamic>() : null,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      final code = e.response?.statusCode;
      final url = e.requestOptions.uri.toString();
      final type = e.type;
      throw 'Falha em GET $PATH_PREFIX/calories/daily: $msg (type=$type, code=$code, url=$url)';
    }
  }

  // -------- ENDPOINT: /api/calories/range -----------
  // Devolve uma série diária (útil para gráficos/relatórios).
  Future<({
    String start,
    String end,
    String? timezone,
    List<Map<String, dynamic>> days,
  })> getRange({
    required DateTime start,
    required DateTime end,
    String? timezone,
  }) async {
    try {
      final headers = await _authHeaders();

      String _fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse('$baseUrl$PATH_PREFIX/calories/range').replace(
        queryParameters: {
          'start': _fmt(start),
          'end': _fmt(end),
          if (timezone != null && timezone.isNotEmpty) 'tz': timezone,
        },
      );

      final res = await _dio.getUri(uri, options: Options(headers: headers));
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.data}';
      }

      final data = (res.data as Map).cast<String, dynamic>();
      final days = (data['days'] as List? ?? const [])
          .map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>())
          .toList();

      return (
        start: data['start'] as String,
        end: data['end'] as String,
        timezone: data['timezone'] as String?,
        days: days,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      final code = e.response?.statusCode;
      final url = e.requestOptions.uri.toString();
      final type = e.type;
      throw 'Falha em GET $PATH_PREFIX/calories/range: $msg (type=$type, code=$code, url=$url)';
    }
  }
}
