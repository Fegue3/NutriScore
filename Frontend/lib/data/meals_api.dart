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
    if (label == null) {
      return null;
    }
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

  // QUANTIDADES
  final num? quantityGrams; // unit=GRAM
  final num? quantityMl; // unit=ML
  final num? servings; // unit=PIECE

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
    this.quantityMl,
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

    final Map<String, dynamic>? p = (j['product'] is Map)
        ? Map<String, dynamic>.from(j['product'])
        : null;

    T? pick<T>(String k) {
      final v = j[k];
      if (v != null) {
        return v as T?;
      }
      if (p != null && p[k] != null) {
        return p[k] as T?;
      }
      return null;
    }

    // nome/brand/barcode tentam várias chaves comuns
    String nameFrom() {
      return (pick<String>('name') ??
              pick<String>('productName') ??
              pick<String>('product_name') ??
              pick<String>('title') ??
              'Produto')
          .toString();
    }

    String? brandFrom() {
      return (pick<String>('brand') ??
              pick<String>('brands') ??
              pick<String>('brand_name'))
          ?.toString();
    }

    String? barcodeFrom() {
      return (pick<String>('barcode') ??
              pick<String>('code') ??
              pick<String>('ean'))
          ?.toString();
    }

    num? kcalFrom() {
      return numOrNull(
        j['calories'] ?? j['kcal'] ?? p?['calories'] ?? p?['kcal'],
      );
    }

    // -------- unit + quantity -> normalizamos para os 3 campos --------
    final unit = (j['unit'] ?? '')
        .toString()
        .toUpperCase(); // "GRAM" | "ML" | "PIECE"
    final q = numOrNull(j['quantity']);
    num? qG;
    num? qMl;
    num? qServ;
    if (q != null) {
      if (unit == 'GRAM') {
        qG = q;
      } else if (unit == 'ML') {
        qMl = q;
      } else if (unit == 'PIECE') {
        qServ = q;
      }
    }

    // Fallbacks (compatibilidade com versões antigas)
    qG ??= numOrNull(j['quantityGrams'] ?? p?['quantityGrams']);
    qServ ??= numOrNull(j['servings'] ?? p?['servings']);

    return MealEntry(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      at: parseDate(j['at'] ?? j['date'] ?? j['createdAt']),
      meal: MealTypeX.fromApi(
        (j['meal'] ?? j['mealType'] ?? j['type'])?.toString(),
      ),
      name: nameFrom(),
      brand: brandFrom(),
      barcode: barcodeFrom(),
      nutriScore:
          (j['nutriScore'] ??
                  j['nutriscore'] ??
                  j['nutri_score'] ??
                  p?['nutriScore'])
              ?.toString()
              .toUpperCase(),
      calories: kcalFrom(),
      protein: numOrNull(j['protein'] ?? p?['protein']),
      carbs: numOrNull(j['carbs'] ?? p?['carbs']),
      fat: numOrNull(j['fat'] ?? p?['fat']),
      quantityGrams: qG,
      quantityMl: qMl,
      servings: qServ,
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
      if (raw == null) {
        return DateTime.now();
      }
      if (raw.contains('T')) {
        return DateTime.parse(raw).toLocal();
      }
      return DateTime.parse('${raw}T00:00:00').toLocal();
    }

    final list =
        (j['entries'] ?? j['items'] ?? j['data'] ?? j['meals'] ?? []) as List;

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

  String _yyyyMmDd(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  num? _n(num? v) {
    if (v == null) return null;
    if (v.isNaN) return null;
    return num.parse(v.toStringAsFixed(2)); // evita problemas com Decimals
  }

  /* ---------- GET /meals?date=YYYY-MM-DD ---------- */
  Future<DayMeals> getDay(DateTime date) async {
    final ymd = _yyyyMmDd(DateTime(date.year, date.month, date.day));
    final dio = _dio();
    final res = await dio.get('/meals', queryParameters: {'date': ymd});

    final raw = res.data;
    final data = raw is String ? jsonDecode(raw) : raw;

    // Normalização tolerante
    List<dynamic> mealsList;
    if (data is List) {
      mealsList = data; // [ {meal+items} ]
    } else if (data is Map && data['meals'] is List) {
      mealsList = List.from(data['meals']); // { meals: [ {meal+items} ] }
    } else if (data is Map && data['entries'] is List) {
      // já vem plano, delegamos
      final entries = (data['entries'] as List)
          .whereType<Map>()
          .map((e) => MealEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final total = entries.fold<num>(0, (s, e) => s + (e.calories ?? 0));
      return DayMeals(date: date, entries: entries, totalCalories: total);
    } else {
      mealsList = const [];
    }

    final entries = <MealEntry>[];

    for (final m in mealsList.whereType<Map>()) {
      final mealType = MealTypeX.fromApi(
        (m['type'] ?? m['meal'] ?? m['mealType'])?.toString(),
      );
      final mealDate = (m['date'] ?? m['at'] ?? ymd).toString();

      final items = (m['items'] is List) ? List.from(m['items']) : const [];

      for (final it in items.whereType<Map>()) {
        // juntamos campos do meal aos do item para o parser apanhar tudo
        final merged = <String, dynamic>{
          ...Map<String, dynamic>.from(it),
          'meal': mealType.api,
          'date': mealDate,
        };

        // alguns backends aninham o produto: { product: {name, brand, kcal...} }
        if (it['product'] is Map) {
          final p = Map<String, dynamic>.from(it['product']);
          merged.addAll({
            // name
            if (p['name'] != null) 'name': p['name'],
            if (p['product_name'] != null) 'product_name': p['product_name'],

            // brand
            if (p['brand'] != null) 'brand': p['brand'],
            if (p['brands'] != null) 'brands': p['brands'],
            if (p['brand_name'] != null) 'brand_name': p['brand_name'],

            // barcode
            if (p['barcode'] != null) 'barcode': p['barcode'],
            if (p['code'] != null) 'code': p['code'],
            if (p['ean'] != null) 'ean': p['ean'],

            // energia
            if (p['kcal'] != null) 'kcal': p['kcal'],
            if (p['calories'] != null) 'calories': p['calories'],

            // nutriScore
            if (p['nutriScore'] != null) 'nutriScore': p['nutriScore'],
            if (p['nutriscore'] != null) 'nutriscore': p['nutriscore'],

            // macros (se vierem dentro do product)
            if (p['carbs'] != null) 'carbs': p['carbs'],
            if (p['carbohydrates'] != null) 'carbohydrates': p['carbohydrates'],
            if (p['protein'] != null) 'protein': p['protein'],
            if (p['fat'] != null) 'fat': p['fat'],
          });
        }

        entries.add(MealEntry.fromJson(merged));
      }
    }

    final total = entries.fold<num>(0, (s, e) => s + (e.calories ?? 0));
    return DayMeals(date: date, entries: entries, totalCalories: total);
  }

  /* ---------- POST /meals ---------- */
  /// Contrato (Nest backend):
  /// {
  ///   date: 'YYYY-MM-DD',
  ///   type: 'LUNCH' | 'DINNER' | 'BREAKFAST' | 'SNACK',
  ///   items: [{
  ///     barcode, unit: 'GRAM'|'ML'|'PIECE', quantity (>0),
  ///     name?, brand?, calories (int), protein?, carbs?, fat?, sugars?, salt?
  ///   }]
  /// }
  Future<MealEntry> add({
    required DateTime at, // data visível no ecrã
    required MealType meal,
    required String barcode,
    String? name,
    String? brand,

    // conveniências do frontend:
    num? quantityGrams, // -> unit GRAM
    num? quantityMl, // -> unit ML
    num? servings, // -> unit PIECE
    // caches opcionais:
    required int calories,
    num? protein,
    num? carbs,
    num? fat,
    num? sugars,
    num? salt,
  }) async {
    final dio = _dio();

    // --- normalizações ---
    final ymd = _yyyyMmDd(DateTime(at.year, at.month, at.day));

    // Garante que só um tipo de quantidade é enviado e que é > 0
    final units = <String, num?>{
      'GRAM': _n(quantityGrams),
      'ML': _n(quantityMl),
      'PIECE': _n(servings),
    }..removeWhere((_, v) => v == null);

    if (units.isEmpty) {
      throw ArgumentError(
        'Deves enviar quantityGrams OU quantityMl OU servings.',
      );
    }
    if (units.length > 1) {
      throw ArgumentError(
        'Não envies mais do que um tipo de quantidade (g/ml/porções).',
      );
    }

    final unit = units.keys.first;
    final quantity = units.values.first!;
    if (quantity <= 0) {
      throw ArgumentError('A quantidade tem de ser positiva.');
    }

    final payload = <String, dynamic>{
      'date': ymd,
      'type': meal.apiCaps,
      'items': [
        {
          'barcode': barcode,
          'unit': unit,
          'quantity': quantity,
          'calories': calories,
          if (protein != null) 'protein': _n(protein),
          if (carbs != null) 'carbs': _n(carbs),
          if (fat != null) 'fat': _n(fat),
          if (sugars != null) 'sugars': _n(sugars),
          if (salt != null) 'salt': _n(salt),
        },
      ],
    };

    try {
      final res = await dio.post('/meals', data: payload);
      final body = res.data;
      final map = body is String
          ? Map<String, dynamic>.from(jsonDecode(body))
          : Map<String, dynamic>.from(body as Map);

      // Preferimos apanhar o último entry devolvido (quando o serviço retorna o dia)
      final entries = (map['entries'] as List?) ?? const [];
      if (entries.isNotEmpty) {
        return MealEntry.fromJson(Map<String, dynamic>.from(entries.last));
      }

      // Fallbacks de respostas alternativas
      final items = (map['items'] as List?) ?? const [];
      if (items.isNotEmpty && items.first is Map) {
        return MealEntry.fromJson(Map<String, dynamic>.from(items.first));
      }

      // Último recurso (eco do que enviámos)
      return MealEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        at: at,
        meal: meal,
        name: name ?? 'Produto',
        brand: brand,
        barcode: barcode,
        quantityGrams: unit == 'GRAM' ? quantity : null,
        quantityMl: unit == 'ML' ? quantity : null,
        servings: unit == 'PIECE' ? quantity : null,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
    } on DioException catch (e) {
      // Extrai mensagem legível do Nest (message|error|detail)
      String msg = e.message ?? 'Erro de rede';
      final data = e.response?.data;
      if (data is Map) {
        msg = (data['message'] ?? data['error'] ?? data['detail'] ?? msg)
            .toString();
      } else if (data is String && data.isNotEmpty) {
        msg = data;
      }
      throw Exception(
        'Falha a gravar refeição (${e.response?.statusCode}): $msg',
      );
    }
  }

  /* ---------- DELETE ---------- */
  Future<void> deleteMeal(String mealId) async {
    await _dio().delete('/meals/$mealId');
  }

  Future<void> deleteMealItem({
    required String mealId,
    required String itemId,
  }) async {
    await _dio().delete('/meals/$mealId/items/$itemId');
  }

  Future<void> deleteItemById(String itemId) async {
    await _dio().delete('/meals/items/$itemId');
  }
}
