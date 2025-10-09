// lib/data/stats_api.dart
import 'dart:convert';
import 'package:dio/dio.dart';

import 'auth_api.dart'; // -> AuthApi.baseUrl
import 'auth_storage.dart'; // -> AuthStorage.I.readAccessToken()

class DailyTotals {
  final int kcal;
  final num proteinG;
  final num carbG;
  final num fatG;
  final num sugarsG;
  final num fiberG;
  final num saltG;

  const DailyTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.sugarsG,
    required this.fiberG,
    required this.saltG,
  });

  factory DailyTotals.fromJson(Map<String, dynamic> j) => DailyTotals(
        kcal: (j['kcal'] ?? 0) as int,
        proteinG: (j['protein_g'] ?? 0) * 1.0,
        carbG: (j['carb_g'] ?? 0) * 1.0,
        fatG: (j['fat_g'] ?? 0) * 1.0,
        sugarsG: (j['sugars_g'] ?? 0) * 1.0,
        fiberG: (j['fiber_g'] ?? 0) * 1.0,
        saltG: (j['salt_g'] ?? 0) * 1.0,
      );

  /// Helper para construir a partir do formato novo `{macros, consumedKcal}`.
  factory DailyTotals.fromNewShape({
    required int consumedKcal,
    required Map<String, dynamic> macros,
  }) {
    num n(dynamic v) => (v ?? 0) * 1.0;
    return DailyTotals(
      kcal: consumedKcal,
      proteinG: n(macros['protein']),
      carbG: n(macros['carb']),
      fatG: n(macros['fat']),
      sugarsG: n(macros['sugars']),
      fiberG: n(macros['fiber']),
      saltG: n(macros['salt']),
    );
  }
}

class MacroProgress {
  final num used;
  final num target;
  final num left;
  final num pct; // 0..1 (ou >1 se excedeu)

  const MacroProgress({
    required this.used,
    required this.target,
    required this.left,
    required this.pct,
  });

  factory MacroProgress.fromJson(Map<String, dynamic> j) => MacroProgress(
        used: (j['used'] ?? 0) * 1.0,
        target: (j['target'] ?? 0) * 1.0,
        left: (j['left'] ?? 0) * 1.0,
        pct: ((j['pct'] ?? 0) as num) * 1.0,
      );
}

class DailyGoals {
  final int? kcal;
  final num? proteinG;
  final num? carbG;
  final num? fatG;

  const DailyGoals({this.kcal, this.proteinG, this.carbG, this.fatG});

  factory DailyGoals.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const DailyGoals();
    return DailyGoals(
      kcal: j['kcal'] as int?,
      proteinG: j['protein_g'] != null ? (j['protein_g'] as num) * 1.0 : null,
      carbG: j['carb_g'] != null ? (j['carb_g'] as num) * 1.0 : null,
      fatG: j['fat_g'] != null ? (j['fat_g'] as num) * 1.0 : null,
    );
  }

  /// Helper para construir a partir do formato novo `{goalKcal}`.
  factory DailyGoals.fromNewShape({int? goalKcal}) =>
      DailyGoals(kcal: goalKcal, proteinG: null, carbG: null, fatG: null);
}

class DailyStats {
  final DateTime date;
  final DailyTotals totals;
  final DailyGoals goals;
  final MacroProgress? kcal;
  final MacroProgress? protein;
  final MacroProgress? carb;
  final MacroProgress? fat;

  /// Extra: mapa byMeal (kcal/macros por refeição).
  final Map<String, dynamic>? byMealRaw;

  const DailyStats({
    required this.date,
    required this.totals,
    required this.goals,
    this.kcal,
    this.protein,
    this.carb,
    this.fat,
    this.byMealRaw,
  });

  factory DailyStats.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(String s) => s.contains('T')
        ? DateTime.parse(s).toLocal()
        : DateTime.parse('${s}T00:00:00').toLocal();

    // ====== DETEÇÃO DO FORMATO ======
    final isOldShape = j.containsKey('totals') || j.containsKey('progress');
    if (isOldShape) {
      final progress = (j['progress'] is Map)
          ? Map<String, dynamic>.from(j['progress'])
          : const {};
      return DailyStats(
        date: parseDate(
          j['date']?.toString() ?? DateTime.now().toIso8601String(),
        ),
        totals: DailyTotals.fromJson(
          Map<String, dynamic>.from(j['totals'] ?? {}),
        ),
        goals: DailyGoals.fromJson(
          j['goals'] is Map ? Map<String, dynamic>.from(j['goals']) : null,
        ),
        kcal: progress['kcal'] is Map
            ? MacroProgress.fromJson(Map<String, dynamic>.from(progress['kcal']))
            : null,
        protein: progress['protein_g'] is Map
            ? MacroProgress.fromJson(
                Map<String, dynamic>.from(progress['protein_g']),
              )
            : null,
        carb: progress['carb_g'] is Map
            ? MacroProgress.fromJson(
                Map<String, dynamic>.from(progress['carb_g']),
              )
            : null,
        fat: progress['fat_g'] is Map
            ? MacroProgress.fromJson(Map<String, dynamic>.from(progress['fat_g']))
            : null,
        // >>> FIX: preservar byMeal também no formato antigo
        byMealRaw:
            j['byMeal'] is Map ? Map<String, dynamic>.from(j['byMeal']) : null,
      );
    }

    // ====== FORMATO NOVO ======
    final consumed = (j['consumedKcal'] ?? 0) as int;
    final macros = Map<String, dynamic>.from(j['macros'] ?? const {});
    final goalKcal =
        (j['goalKcal'] is num) ? (j['goalKcal'] as num).toInt() : null;

    return DailyStats(
      date: parseDate(
        j['date']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      totals: DailyTotals.fromNewShape(
        consumedKcal: consumed,
        macros: macros,
      ),
      goals: DailyGoals.fromNewShape(goalKcal: goalKcal),
      kcal: null,
      protein: null,
      carb: null,
      fat: null,
      byMealRaw:
          j['byMeal'] is Map ? Map<String, dynamic>.from(j['byMeal']) : null,
    );
  }
}

class RangePoint {
  final DateTime date;
  final int kcal;
  final num proteinG;
  final num carbG;
  final num fatG;

  const RangePoint({
    required this.date,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
  });

  factory RangePoint.fromJson(Map<String, dynamic> j) => RangePoint(
        date: DateTime.parse('${j['date']}T00:00:00').toLocal(),
        kcal: (j['kcal'] ?? j['consumedKcal'] ?? 0) as int,
        proteinG: (j['protein_g'] ?? (j['macros']?['protein'] ?? 0)) * 1.0,
        carbG: (j['carb_g'] ?? (j['macros']?['carb'] ?? 0)) * 1.0,
        fatG: (j['fat_g'] ?? (j['macros']?['fat'] ?? 0)) * 1.0,
      );
}

class StatsApi {
  StatsApi._();
  static final StatsApi I = StatsApi._();

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

  Future<DailyStats> getDaily({DateTime? date}) async {
    final dio = _dio();
    final qp = (date == null) ? null : {'date': _ymd(date)};
    final res = await dio.get('/stats/daily', queryParameters: qp);
    final raw = res.data;
    final map = raw is String ? jsonDecode(raw) : raw;
    return DailyStats.fromJson(Map<String, dynamic>.from(map as Map));
  }

  Future<List<RangePoint>> getRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final dio = _dio();
    final res = await dio.get(
      '/stats/range',
      queryParameters: {'from': _ymd(from), 'to': _ymd(to)},
    );
    final raw = res.data;
    final parsed = raw is String ? jsonDecode(raw) : raw;

    // Aceita ambos: [ ... ] (antigo) ou { days: [...] } (novo)
    if (parsed is List) {
      return parsed
          .whereType<Map>()
          .map((e) => RangePoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (parsed is Map && parsed['days'] is List) {
      final list = (parsed['days'] as List);
      return list
          .whereType<Map>()
          .map((e) => RangePoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception('Formato inesperado em /stats/range');
  }
}

// ---------------- /stats/recommended ----------------

class RecommendedTargets {
  final int kcal;
  final num proteinG;
  final num carbG;
  final num fatG;
  final num fiberG;
  final num sugarsGMax; // limite diário recomendado
  final num saltGMax;   // limite diário recomendado
  final num satFatGMax; // limite diário recomendado

  const RecommendedTargets({
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    required this.fiberG,
    required this.sugarsGMax,
    required this.saltGMax,
    required this.satFatGMax,
  });

  static num _d(dynamic v) =>
      (v is num) ? v.toDouble() : num.tryParse('$v') ?? 0;

  static int _i(dynamic v) =>
      (v is int) ? v : (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

  /// Aceita várias variantes de chaves para robustez:
  /// - sugars: sugars_g_max | sugars_g
  /// - salt:   salt_g_max   | salt_g
  /// - sat fat: sat_fat_g_max | satFat_g_max | satFatGMax
  factory RecommendedTargets.fromTargetsMap(Map<String, dynamic> t) {
    return RecommendedTargets(
      kcal: _i(t['kcal']),
      proteinG: _d(t['protein_g'] ?? t['proteinG']),
      carbG:    _d(t['carb_g']    ?? t['carbG']),
      fatG:     _d(t['fat_g']     ?? t['fatG']),
      fiberG:   _d(t['fiber_g']   ?? t['fiberG']),
      sugarsGMax: _d(t['sugars_g_max'] ?? t['sugars_g'] ?? t['sugarsGMax'] ?? t['sugarsG']),
      saltGMax:   _d(t['salt_g_max']   ?? t['salt_g']   ?? t['saltGMax']   ?? t['saltG']),
      satFatGMax: _d(t['sat_fat_g_max'] ?? t['satFat_g_max'] ?? t['satFatGMax'] ?? 0),
    );
  }
}

class RecommendedResponse {
  final RecommendedTargets targets;
  final Map<String, dynamic> macrosPercent; // {protein, carb, fat} se o backend enviar
  final Map<String, dynamic> preferences;   // {lowSalt, lowSugar, ...} se existir

  const RecommendedResponse({
    required this.targets,
    required this.macrosPercent,
    required this.preferences,
  });

  factory RecommendedResponse.fromJson(Map<String, dynamic> j) {
    final targetsRaw = (j['targets'] is Map)
        ? Map<String, dynamic>.from(j['targets'])
        : (j); // também aceita quando o backend já devolve só o objeto de targets
    return RecommendedResponse(
      targets: RecommendedTargets.fromTargetsMap(targetsRaw),
      macrosPercent: Map<String, dynamic>.from(j['macros_percent'] ?? const {}),
      preferences:   Map<String, dynamic>.from(j['preferences']    ?? const {}),
    );
  }
}

extension StatsApiRecommended on StatsApi {
  /// NOVO: usa /stats/recommended e NÃO /stats/day-nutrients.
  /// Retorna RecommendedResponse (com .targets para kcal e metas todas).
  Future<RecommendedResponse> getRecommended() async {
    final dio = _dio();
    final res = await dio.get('/stats/recommended');
    final raw = res.data;
    final j = raw is String ? jsonDecode(raw) : raw;

    // Aceita:
    // - { targets: {...}, macros_percent: {...}, preferences: {...} }
    // - {...} diretamente com as chaves dos targets
    if (j is Map<String, dynamic>) {
      if (j.containsKey('targets')) {
        return RecommendedResponse.fromJson(j);
      } else {
        // backend a devolver só o objeto de alvos
        return RecommendedResponse.fromJson({'targets': j});
      }
    }
    throw Exception('Formato inesperado em /stats/recommended');
  }

  /// Atalho: devolve só os targets (kcal + metas) já normalizados.
  Future<RecommendedTargets> getRecommendedTargets() async {
    final r = await getRecommended();
    return r.targets;
  }
}
