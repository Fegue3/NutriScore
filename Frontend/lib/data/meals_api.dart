// lib/data/meals_api.dart
import 'dart:convert';
import 'package:dio/dio.dart';

import 'auth_api.dart'; // -> AuthApi.baseUrl
import 'auth_storage.dart'; // -> AuthStorage.I.readAccessToken()

/* ===================== Domínio: Meal ===================== */

enum MealType { breakfast, lunch, snack, dinner }

extension MealTypeX on MealType {
  String get api => switch (this) {
        MealType.breakfast => 'breakfast',
        MealType.lunch => 'lunch',
        MealType.snack => 'snack',
        MealType.dinner => 'dinner',
      };

  String get apiCaps => api.toUpperCase();

  String get labelPt => switch (this) {
        MealType.breakfast => 'Pequeno-almoço',
        MealType.lunch => 'Almoço',
        MealType.snack => 'Lanche',
        MealType.dinner => 'Jantar',
      };

  static MealType fromApi(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    return switch (s) {
      'breakfast' => MealType.breakfast,
      'lunch' => MealType.lunch,
      'snack' => MealType.snack,
      'dinner' => MealType.dinner,
      _ => MealType.breakfast,
    };
  }

  static MealType? fromLabelPt(String? label) {
    if (label == null) return null;
    final s = label.trim().toLowerCase();
    if (s.contains('pequeno')) return MealType.breakfast;
    if (s.contains('almo')) return MealType.lunch;
    if (s.contains('lanche')) return MealType.snack;
    if (s.contains('jantar')) return MealType.dinner;
    return fromApi(label);
  }
}

/* ===================== Models ===================== */

class MealEntry {
  final String id;
  final DateTime at;
  final MealType meal;
  final String name;
  final String? brand;
  final String? barcode;
  final String? nutriScore;
  final num? calories;
  final num? carbs;
  final num? protein;
  final num? fat;
  final num? quantityGrams;
  final num? servings;

  MealEntry({
    required this.id,
    required this.at,
    required this.meal,
    required this.name,
    this.brand,
    this.barcode,
    this.nutriScore,
    this.calories,
    this.carbs,
    this.protein,
    this.fat,
    this.quantityGrams,
    this.servings,
  });

  factory MealEntry.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic raw) {
      if (raw is String && raw.contains('T')) {
        return DateTime.parse(raw).toLocal();
      }
      if (raw is String && raw.isNotEmpty) {
        return DateTime.parse('${raw}T00:00:00').toLocal();
      }
      if (raw is int) {
        return DateTime.fromMillisecondsSinceEpoch(raw).toLocal();
      }
      return DateTime.now();
    }

    num? numOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      if (v is String) return num.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    return MealEntry(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      at: parseDate(j['at'] ?? j['date'] ?? j['createdAt']),
      meal: MealTypeX.fromApi(
        (j['meal'] ?? j['mealType'] ?? j['type'])?.toString(),
      ),
      name: (j['name'] ?? j['productName'] ?? 'Produto').toString(),
      brand: j['brand']?.toString(),
      barcode: j['barcode']?.toString(),
      nutriScore: (j['nutriScore'] ??
              j['nutriscore'] ??
              j['nutri_score'])
          ?.toString()
          .toUpperCase(),
      calories: numOrNull(j['calories'] ?? j['kcal']),
      carbs: numOrNull(j['carbs']),
      protein: numOrNull(j['protein']),
      fat: numOrNull(j['fat']),
      quantityGrams: numOrNull(
        j['quantityGrams'] ??
            j['quantity'] ??
            j['grams'] ??
            j['quantity_grams'],
      ),
      servings:
          numOrNull(j['servings'] ?? j['portion'] ?? j['portions']),
    );
  }
}

class DayMeals {
  final DateTime date;
  final List<MealEntry> entries;
  final num totalCalories;

  DayMeals({
    required this.date,
    required this.entries,
    required this.totalCalories,
  });

  factory DayMeals.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(String? raw) {
      if (raw == null) return DateTime.now();
      if (raw.contains('T')) return DateTime.parse(raw).toLocal();
      return DateTime.parse('${raw}T00:00:00').toLocal();
    }

    final list =
        (j['entries'] ?? j['items'] ?? j['data'] ?? j['meals'] ?? [])
            as List<dynamic>;

    final entries = list
        .whereType<Map>()
        .map((e) => MealEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final sum = (j['totalCalories'] is num)
        ? j['totalCalories'] as num
        : entries.fold<num>(0, (s, e) => s + (e.calories ?? 0));

    final dateStr = (j['date'] ?? j['day'])?.toString();
    return DayMeals(
      date: parseDate(dateStr),
      entries: entries,
      totalCalories: sum,
    );
  }
}

/* ===================== API Client ===================== */

class MealsApi {
  MealsApi._();
  static final MealsApi I = MealsApi._();

  Dio _dio() {
    final dio = Dio(BaseOptions(baseUrl: AuthApi.baseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          final token = await AuthStorage.I.readAccessToken();
          if (token != null) {
            opts.headers['Authorization'] = 'Bearer $token';
          }
          opts.headers['Content-Type'] = 'application/json';
          handler.next(opts);
        },
      ),
    );
    return dio;
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// GET /meals?date=...
  /// 1ª tentativa: ISO 8601 full; 2ª: YYYY-MM-DD (fallback).
  Future<DayMeals> getDay(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final iso = day.toUtc().toIso8601String();

    final dio = _dio();
    Response res;

    try {
      res = await dio.get('/meals', queryParameters: {'date': iso});
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 || e.response?.statusCode == 404) {
        res = await dio.get(
          '/meals',
          queryParameters: {'date': _yyyyMmDd(day)},
        );
      } else {
        rethrow;
      }
    }

    final raw = res.data;
    dynamic data;
    if (raw is String) {
      data = jsonDecode(raw);
    } else {
      data = raw;
    }

    late final Map<String, dynamic> normalized;
    if (data is Map<String, dynamic>) {
      normalized = data;
    } else if (data is Map) {
      normalized = Map<String, dynamic>.from(data);
    } else if (data is List) {
      normalized = <String, dynamic>{'date': iso, 'entries': data};
    } else {
      normalized = <String, dynamic>{'date': iso, 'entries': const []};
    }

    return DayMeals.fromJson(normalized);
  }

  /// POST /meals — contrato: { date, type, items: [...] }
  Future<MealEntry> add({
    required DateTime at,
    required MealType meal,
    required String barcode,
    num? quantityGrams,
    num? servings,
    int? calories,
    num? protein,
    num? carb,
    num? fat,
    num? sugars,
    num? salt,
  }) async {
    final dio = _dio();

    final isoDate = DateTime(
      at.year,
      at.month,
      at.day,
    ).toUtc().toIso8601String();

    final q = quantityGrams ?? servings;

    final payload = <String, dynamic>{
      'date': isoDate,
      'type': meal.apiCaps,
      'items': [
        {
          'barcode': barcode,
          if (q != null) 'quantity': q,
          if (calories != null) 'calories': calories,
          if (protein != null) 'protein': protein,
          if (carb != null) 'carb': carb,
          if (fat != null) 'fat': fat,
          if (sugars != null) 'sugars': sugars,
          if (salt != null) 'salt': salt,
        },
      ],
    };

    final res = await dio.post('/meals', data: payload);

    final body = res.data;
    final map = body is String
        ? Map<String, dynamic>.from(jsonDecode(body))
        : Map<String, dynamic>.from(body as Map);
    final items = (map['items'] as List?) ?? const [];

    if (items.isNotEmpty && items.first is Map) {
      return MealEntry.fromJson(Map<String, dynamic>.from(items.first));
    }

    return MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      at: DateTime.now(),
      meal: meal,
      name: 'Produto',
      barcode: barcode,
    );
  }

  /// DELETE /meals/:id
  Future<void> remove(String id) async {
    await _dio().delete('/meals/$id');
  }
}
