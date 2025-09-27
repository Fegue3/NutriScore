// lib/data/products_api.dart
import 'package:dio/dio.dart';

import 'auth_api.dart'; // para baseUrl
import 'auth_storage.dart'; // para ler/gravar tokens
import '../app/di.dart';

/* ===================== HELPERS NUMÉRICOS (top-level) ===================== */
// NÃO usar 'static' no top-level.
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

/* ===================== MODELOS (top-level) ===================== */

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
        barcode: j['barcode'] as String,
        name: (j['name'] ?? '') as String,
        brand: j['brand'] as String?,
        imageUrl: j['imageUrl'] as String?,
        categories: j['categories'] as String?,
        nutriScore: (j['nutriScore'] as String?)?.toUpperCase(),
        // aceita String ou num
        energyKcal100g: _i(j['energyKcal_100g']),
      );
}

class ProductDetail {
  final String barcode;
  final String name;
  final String? brand;
  final String? origin; // podes mapear de countries
  final String? servingSize;
  final String? quantity; // ex "100 g"
  final String? imageUrl;
  final String? nutriScore; // A..E

  // 100g
  final int? kcal100g;
  final double? protein100g;
  final double? carbs100g;
  final double? sugars100g;
  final double? fat100g;
  final double? satFat100g;
  final double? fiber100g;
  final double? salt100g;
  final double? sodium100g;

  // por porção (se existir)
  final int? kcalServ;
  final double? proteinServ;
  final double? carbsServ;
  final double? sugarsServ;
  final double? fatServ;
  final double? satFatServ;
  final double? fiberServ;
  final double? saltServ;
  final double? sodiumServ;

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
  });

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        barcode: j['barcode'] as String,
        name: (j['name'] ?? '') as String,
        brand: j['brand'] as String?,
        origin: j['countries'] as String?,
        servingSize: j['servingSize'] as String?,
        quantity: j['quantity'] as String?,
        imageUrl: j['imageUrl'] as String?,
        nutriScore: (j['nutriScore'] as String?)?.toUpperCase(),
        // ---- todos os numéricos via helpers (_d/_i) ----
        kcal100g: _i(j['energyKcal_100g']),
        protein100g: _d(j['proteins_100g']),
        carbs100g: _d(j['carbs_100g']),
        sugars100g: _d(j['sugars_100g']),
        fat100g: _d(j['fat_100g']),
        satFat100g: _d(j['satFat_100g']),
        fiber100g: _d(j['fiber_100g']),
        salt100g: _d(j['salt_100g']),
        sodium100g: _d(j['sodium_100g']),
        kcalServ: _i(j['energyKcal_serv']),
        proteinServ: _d(j['proteins_serv']),
        carbsServ: _d(j['carbs_serv']),
        sugarsServ: _d(j['sugars_serv']),
        fatServ: _d(j['fat_serv']),
        satFatServ: _d(j['satFat_serv']),
        fiberServ: _d(j['fiber_serv']),
        saltServ: _d(j['salt_serv']),
        sodiumServ: _d(j['sodium_serv']),
      );
}

/* ============== MODELOS — HISTÓRICO (novo) ============== */

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
        barcode: j['barcode'] as String,
        name: (j['name'] ?? '') as String,
        brand: j['brand'] as String?,
        imageUrl: j['imageUrl'] as String?,
        nutriScore: (j['nutriScore'] as String?)?.toUpperCase(),
        energyKcal100g: _i(j['energyKcal_100g']),
      );
}

class ProductHistoryItem {
  final int id; // BigInt no backend — chega como num (ou string após fix)
  final DateTime scannedAt;
  final String? barcode;
  final String? nutriScore;
  final int? calories;
  final double? proteins;
  final double? carbs;
  final double? fat;

  // Produto "mini" incluído (pode ser null se foi apagado entretanto)
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

  factory ProductHistoryItem.fromJson(Map<String, dynamic> j) => ProductHistoryItem(
        id: (j['id'] is String) ? int.parse(j['id'] as String) : (j['id'] as num).toInt(),
        scannedAt: DateTime.parse(j['scannedAt'] as String),
        barcode: j['barcode'] as String?,
        nutriScore: (j['nutriScore'] as String?)?.toUpperCase(),
        calories: _i(j['calories']),
        proteins: _d(j['proteins']),
        carbs: _d(j['carbs']),
        fat: _d(j['fat']),
        product: (j['product'] is Map && j['product'] != null)
            ? ProductMini.fromJson((j['product'] as Map).cast<String, dynamic>())
            : null,
      );
}

/* ===================== API ===================== */

class ProductsApi {
  ProductsApi._();
  static final ProductsApi I = ProductsApi._();

  String get baseUrl => AuthApi.baseUrl; // normalmente já inclui /api
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

  /// GET autenticado com refresh automático em 401 (retry 1x)
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
            try {
              final ok = await di.authRepository.tryRefresh(rt);
              if (ok) {
                headers = await _authHeaders(requireJwt: true); // novo access
                return await _dio.getUri(uri, options: Options(headers: headers));
              }
            } catch (_) {}
          } else {
            try { await di.authRepository.expireSession(); } catch (_) {}
          }
        } catch (_) {}
      }
      rethrow;
    }
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
      final headers = await _authHeaders(requireJwt: true);
      final uri = Uri.parse('$baseUrl$pathPrefix/$barcode/favorite');
      final res = await _dio.postUri(uri, options: Options(headers: headers));
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
