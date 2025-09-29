// lib/data/products_api.dart
import 'package:dio/dio.dart';

import 'auth_api.dart';          // baseUrl
import 'auth_storage.dart';      // access/refresh tokens
import '../app/di.dart';         // di.authRepository (refresh token)

/* ===================== HELPERS (top-level) ===================== */
// NÃO uses "static" no top-level.

String? _str(dynamic v) => v?.toString();

String? _upper(dynamic v) => v?.toString().toUpperCase();

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final m = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(v);
    if (m != null) return double.tryParse(m.group(0)!.replaceAll(',', '.'));
  }
  return null;
}

int? _i(dynamic v) => _d(v)?.round();

String? _catsToString(dynamic v) {
  if (v == null) return null;
  if (v is List) return v.map((e) => e.toString()).join(', ');
  return v.toString();
}

/* ===================== MODELOS ===================== */

class ProductSummary {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? categories;
  final String? nutriScore; // "A".."E"
  final int? energyKcal100g;

  ProductSummary({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.categories,
    this.nutriScore,
    this.energyKcal100g,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> j) => ProductSummary(
        barcode: (_str(j['barcode']) ?? '').toString(),
        name: _str(j['name'] ?? j['product_name'] ?? 'Produto')!,
        brand: _str(j['brand'] ?? j['brands']),
        imageUrl: _str(j['imageUrl'] ?? j['image_url']),
        categories: _catsToString(j['categories'] ?? j['category']),
        nutriScore: _upper(j['nutriScore'] ?? j['nutriscore'] ?? j['nutriscore_grade']),
        energyKcal100g: _i(
          j['energyKcal100g'] ??
          j['energyKcal_100g'] ??
          j['energy-kcal_100g'] ??
          j['kcal_100g'] ??
          j['energy-kcal_100g_value'],
        ),
      );
}

class ProductDetail {
  final String barcode;
  final String name;
  final String? brand;
  final String? origin;       // ex: countries
  final String? servingSize;  // ex: "30 g"
  final String? quantity;     // ex: "100 g"
  final String? imageUrl;
  final String? nutriScore;   // A..E

  // por 100 g
  final int? kcal100g;
  final double? protein100g;
  final double? carbs100g;
  final double? sugars100g;
  final double? fat100g;
  final double? satFat100g;
  final double? fiber100g;
  final double? salt100g;
  final double? sodium100g;

  // por porção
  final int? kcalServ;
  final double? proteinServ;
  final double? carbsServ;
  final double? sugarsServ;
  final double? fatServ;
  final double? satFatServ;
  final double? fiberServ;
  final double? saltServ;
  final double? sodiumServ;
  final bool? isFavorite;

  ProductDetail({
    required this.barcode,
    required this.name,
    this.brand,
    this.origin,
    this.servingSize,
    this.quantity,
    this.imageUrl,
    this.nutriScore,
    this.kcal100g,
    this.protein100g,
    this.carbs100g,
    this.sugars100g,
    this.fat100g,
    this.satFat100g,
    this.fiber100g,
    this.salt100g,
    this.sodium100g,
    this.kcalServ,
    this.proteinServ,
    this.carbsServ,
    this.sugarsServ,
    this.fatServ,
    this.satFatServ,
    this.fiberServ,
    this.saltServ,
    this.sodiumServ,
    this.isFavorite,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        barcode: (_str(j['barcode']) ?? '').toString(),
        name: _str(j['name'] ?? j['product_name'] ?? 'Produto')!,
        brand: _str(j['brand'] ?? j['brands']),
        origin: _catsToString(j['countries'] ?? j['origins']),
        servingSize: _str(j['servingSize'] ?? j['serving_size']),
        quantity: _str(j['quantity']),
        imageUrl: _str(j['imageUrl'] ?? j['image_url']),
        nutriScore: _upper(j['nutriScore'] ?? j['nutriscore'] ?? j['nutriscore_grade']),
        // 100g
        kcal100g: _i(j['energyKcal100g'] ?? j['energyKcal_100g'] ?? j['energy-kcal_100g'] ?? j['kcal_100g']),
        protein100g: _d(j['proteins_100g'] ?? j['protein_100g']),
        carbs100g: _d(j['carbs_100g'] ?? j['carbohydrates_100g']),
        sugars100g: _d(j['sugars_100g']),
        fat100g: _d(j['fat_100g']),
        satFat100g: _d(j['satFat_100g'] ?? j['saturated-fat_100g']),
        fiber100g: _d(j['fiber_100g']),
        salt100g: _d(j['salt_100g']),
        sodium100g: _d(j['sodium_100g']),
        // porção
        kcalServ: _i(j['energyKcal_serv'] ?? j['energy-kcal_serving'] ?? j['kcal_serving']),
        proteinServ: _d(j['proteins_serv'] ?? j['protein_serving']),
        carbsServ: _d(j['carbs_serv'] ?? j['carbohydrates_serving']),
        sugarsServ: _d(j['sugars_serv'] ?? j['sugars_serving']),
        fatServ: _d(j['fat_serv'] ?? j['fat_serving']),
        satFatServ: _d(j['satFat_serv'] ?? j['saturated-fat_serving']),
        fiberServ: _d(j['fiber_serv'] ?? j['fiber_serving']),
        saltServ: _d(j['salt_serv'] ?? j['salt_serving']),
        sodiumServ: _d(j['sodium_serv'] ?? j['sodium_serving']),
      );
}

/* ============ HISTÓRICO ============ */

class ProductMini {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? nutriScore;
  final int? energyKcal100g;

  ProductMini({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.nutriScore,
    this.energyKcal100g,
  });

  factory ProductMini.fromJson(Map<String, dynamic> j) => ProductMini(
        barcode: (_str(j['barcode']) ?? '').toString(),
        name: _str(j['name'] ?? j['product_name'] ?? 'Produto')!,
        brand: _str(j['brand'] ?? j['brands']),
        imageUrl: _str(j['imageUrl'] ?? j['image_url']),
        nutriScore: _upper(j['nutriScore'] ?? j['nutriscore'] ?? j['nutriscore_grade']),
        energyKcal100g: _i(
          j['energyKcal100g'] ?? j['energyKcal_100g'] ?? j['energy-kcal_100g'] ?? j['kcal_100g'],
        ),
      );
}

class ProductHistoryItem {
  final int id; // BigInt no backend pode vir string/num
  final DateTime scannedAt;
  final String? barcode;
  final String? nutriScore;
  final int? calories;
  final double? proteins;
  final double? carbs;
  final double? fat;
  final ProductMini? product;

  ProductHistoryItem({
    required this.id,
    required this.scannedAt,
    required this.barcode,
    required this.nutriScore,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fat,
    required this.product,
  });

  factory ProductHistoryItem.fromJson(Map<String, dynamic> j) {
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    DateTime parseDate(dynamic raw) {
      if (raw is String && raw.contains('T')) return DateTime.parse(raw).toLocal();
      if (raw is String && raw.isNotEmpty) return DateTime.parse('${raw}T00:00:00').toLocal();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw).toLocal();
      return DateTime.now();
    }

    final prod = (j['product'] is Map)
        ? ProductMini.fromJson(Map<String, dynamic>.from(j['product'] as Map))
        : null;

    return ProductHistoryItem(
      id: parseId(j['id']),
      scannedAt: parseDate(j['scannedAt'] ?? j['createdAt'] ?? j['at']),
      barcode: _str(j['barcode']),
      nutriScore: _upper(j['nutriScore'] ?? j['nutriscore'] ?? j['nutriscore_grade']),
      calories: _i(j['calories'] ?? j['kcal']),
      proteins: _d(j['proteins'] ?? j['protein']),
      carbs: _d(j['carbs'] ?? j['carbohydrates']),
      fat: _d(j['fat']),
      product: prod,
    );
  }
}

/* ===================== CLIENTE API ===================== */

class ProductsApi {
  ProductsApi._();
  static final ProductsApi I = ProductsApi._();

  String get baseUrl => AuthApi.baseUrl; // costuma já incluir /api
  static const String pathPrefix = '/products';

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

  Future<Map<String, String>> _authHeaders({bool requireJwt = false}) async {
    final token = _overrideAccessToken ?? await AuthStorage.I.readAccessToken();
    if (token == null || token.isEmpty) {
      if (requireJwt) throw 'Sessão inválida: falta o access token.';
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// GET autenticado com refresh automático (1x) em 401
  Future<Response<dynamic>> _getAuthed(Uri uri) async {
    Map<String, String> headers = await _authHeaders(requireJwt: true);
    try {
      return await _dio.getUri(uri, options: Options(headers: headers));
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 401) {
        try {
          final rt = await AuthStorage.I.readRefreshToken();
          if (rt != null && rt.isNotEmpty) {
            final ok = await di.authRepository.tryRefresh(rt);
            if (ok) {
              headers = await _authHeaders(requireJwt: true);
              return await _dio.getUri(uri, options: Options(headers: headers));
            }
          } else {
            await di.authRepository.expireSession();
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// POST autenticado (para favorito)
  Future<Response<dynamic>> _postAuthed(Uri uri, {Object? data}) async {
    final headers = await _authHeaders(requireJwt: true);
    return _dio.postUri(uri, data: data, options: Options(headers: headers));
  }

  /* ============ Endpoints públicos ============ */

  // GET /products/suggest?q=...&limit=8
  Future<List<ProductSummary>> suggest(String q, {int limit = 8}) async {
    try {
      final uri = Uri.parse('$baseUrl$pathPrefix/suggest')
          .replace(queryParameters: {'q': q, 'limit': '$limit'});
      final res = await _dio.getUri(uri);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final map = (res.data as Map).cast<String, dynamic>();
      final items = (map['items'] as List? ?? const [])
          .map((e) => ProductSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return items;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      throw 'Falha em GET /products/suggest: $msg';
    }
  }

  // GET /products?q=...
  Future<({List<ProductSummary> items, int total, int page, int pageSize})>
      searchHybrid(String q, {int page = 1, int pageSize = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl$pathPrefix')
          .replace(queryParameters: {'q': q, 'page': '$page', 'pageSize': '$pageSize'});
      final res = await _dio.getUri(uri);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final m = (res.data as Map).cast<String, dynamic>();
      final items = (m['items'] as List? ?? const [])
          .map((e) => ProductSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return (
        items: items,
        total: (m['total'] as num?)?.toInt() ?? items.length,
        page: (m['page'] as num?)?.toInt() ?? page,
        pageSize: (m['pageSize'] as num?)?.toInt() ?? pageSize,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      throw 'Falha em GET /products: $msg';
    }
  }

  // GET /products/search-confirm?q=...
  Future<({List<ProductSummary> items, int total, int page, int pageSize})>
      searchConfirm(String q, {int page = 1, int pageSize = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl$pathPrefix/search-confirm')
          .replace(queryParameters: {'q': q, 'page': '$page', 'pageSize': '$pageSize'});
      final res = await _dio.getUri(uri);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final m = (res.data as Map).cast<String, dynamic>();
      final items = (m['items'] as List? ?? const [])
          .map((e) => ProductSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return (
        items: items,
        total: (m['total'] as num?)?.toInt() ?? items.length,
        page: (m['page'] as num?)?.toInt() ?? page,
        pageSize: (m['pageSize'] as num?)?.toInt() ?? pageSize,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      throw 'Falha em GET /products/search-confirm: $msg';
    }
  }

  /* ============ Endpoints protegidos ============ */

  // GET /products/:barcode  (JWT) — no backend isto grava no histórico
  Future<ProductDetail> getByBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$baseUrl$pathPrefix/$barcode');
      final res = await _getAuthed(uri);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final j = (res.data as Map).cast<String, dynamic>();
      return ProductDetail.fromJson(j);
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      throw 'Falha em GET /products/$barcode: $msg';
    }
  }

  // POST /products/:barcode/favorite (JWT)
  Future<bool> toggleFavorite(String barcode) async {
    try {
      final uri = Uri.parse('$baseUrl$pathPrefix/$barcode/favorite');
      final res = await _postAuthed(uri);
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}';
      }
      final m = (res.data as Map).cast<String, dynamic>();
      return (m['favorited'] as bool?) ?? false;
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      throw 'Falha em POST /products/$barcode/favorite: $msg';
    }
  }

  // GET /products/history (JWT)
  Future<({List<ProductHistoryItem> items, int total, int page, int pageSize})>
      getHistory({
        int page = 1,
        int pageSize = 20,
        String? from,
        String? to,
      }) async {
    try {
      final qp = <String, String>{
        'page': '$page',
        'pageSize': '$pageSize',
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      };
      final uri = Uri.parse('$baseUrl$pathPrefix/history').replace(queryParameters: qp);
      final res = await _getAuthed(uri);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';

      final m = (res.data as Map).cast<String, dynamic>();
      final items = (m['items'] as List? ?? const [])
          .map((e) => ProductHistoryItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      return (
        items: items,
        total: (m['total'] as num?)?.toInt() ?? items.length,
        page: (m['page'] as num?)?.toInt() ?? page,
        pageSize: (m['pageSize'] as num?)?.toInt() ?? pageSize,
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? ((e.response!.data['message'] ?? e.response!.data['error'] ?? e.message) as Object?).toString()
          : (e.message ?? 'Erro de rede');
      throw 'Falha em GET /products/history: $msg';
    }
  }
}
