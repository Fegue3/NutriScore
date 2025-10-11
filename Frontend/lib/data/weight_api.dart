// lib/data/weight_api.dart
import 'dart:convert';
import 'package:dio/dio.dart';

import 'auth_api.dart';      // AuthApi.baseUrl
import 'auth_storage.dart';  // AuthStorage.I.readAccessToken()

class WeightApi {
  WeightApi._();
  static final WeightApi I = WeightApi._();

  Dio _dio() {
    final dio = Dio(BaseOptions(baseUrl: AuthApi.baseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          final token = await AuthStorage.I.readAccessToken();
          if (token != null && token.isNotEmpty) {
            opts.headers['Authorization'] = 'Bearer $token';
          }
          opts.headers['Content-Type'] = 'application/json';
          handler.next(opts);
        },
      ),
    );
    return dio;
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// PUT /weight  { weightKg, date?, source?, note? }
  Future<void> upsertWeight({
    required double weightKg,
    DateTime? date,
    String? note,
    String source = 'manual',
  }) async {
    final dio = _dio();
    final body = {
      'weightKg': weightKg,
      if (date != null) 'date': _ymd(date),
      'source': source,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final res = await dio.put('/weight', data: jsonEncode(body));
    // Dio lança exceção se status >= 400, mas se vier como 200/204 só devolvemos.
    final ok = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
    if (!ok) {
      throw Exception('Falha ao definir peso (${res.statusCode}): ${res.data}');
    }
  }

  /// GET /weight/latest  -> { date: "YYYY-MM-DD"|null, weightKg: number|null, ... }
  Future<Map<String, dynamic>> getLatest() async {
    final dio = _dio();
    final res = await dio.get('/weight/latest');
    final raw = res.data;
    return raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
  }

  /// GET /weight?from=YYYY-MM-DD&to=YYYY-MM-DD
  /// -> { from, to, points: [{date, weightKg, ...}] }
  Future<Map<String, dynamic>> getRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final dio = _dio();
    final res = await dio.get('/weight', queryParameters: {
      'from': _ymd(from),
      'to': _ymd(to),
    });
    final raw = res.data;
    return raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
  }
}
