// lib/services/home_service.dart
//
// Everything the home screen loads. Each call fails on its own so one broken
// API never blanks the whole page.
//
//   accounts/banners/            {placement: home_hero|finance_partner, section}
//   product/category/all/        {}            -> names deduped, active only
//   product/product/approved-list/  (via ProductService)
//   cart/... (via CartService)  -> badge count

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cart_model.dart';
import '../models/home_models.dart';
import '../models/product_model.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';
import 'cart_service.dart';
import 'product_service.dart';

class HomeService {
  static const _timeout = Duration(seconds: 20);

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(
      Uri.parse('${ApiUrls.baseUrl}$path'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode(body),
    )
        .timeout(_timeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception(decoded is Map ? (decoded['message'] ?? 'Request failed') : 'Request failed');
  }

  static String _err(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    if (s.contains('SocketException') || s.contains('ClientException')) {
      return 'Could not reach the server.';
    }
    if (s.contains('TimeoutException')) return 'The server took too long to respond.';
    return s;
  }

  // ── Banners ─────────────────────────────────────────────
  static Future<HomeResult<List<HomeBanner>>> getBanners({
    required String placement,
    String? section,
  }) async {
    try {
      final j = await _post('/accounts/banners/', {
        'placement': placement,
        if (section != null) 'section': section,
      });
      final list = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => HomeBanner.fromJson(Map<String, dynamic>.from(e)))
          .where((b) => b.imageUrl.startsWith('http'))
          .toList();
      return HomeResult(list);
    } catch (e) {
      return HomeResult(const [], ok: false, message: _err(e));
    }
  }

  // ── Categories ──────────────────────────────────────────
  /// Category names across all companies, deduped (case-insensitive), active only.
  /// Product counts come from [products] so empty categories can be pushed to the end.
  static Future<HomeResult<List<HomeCategory>>> getCategories({
    List<Product> products = const [],
  }) async {
    try {
      final j = await _post('/product/category/all/', {});
      final counts = <String, int>{};
      for (final p in products) {
        final k = p.categoryName.trim().toLowerCase();
        if (k.isNotEmpty) counts[k] = (counts[k] ?? 0) + 1;
      }
      final seen = <String, String>{};
      for (final e in (j['data'] as List? ?? []).whereType<Map>()) {
        if (e['is_active'] == false) continue;
        final name = (e['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        seen.putIfAbsent(name.toLowerCase(), () => name);
      }
      final list = seen.entries
          .map((e) => HomeCategory(e.value, productCount: counts[e.key] ?? 0))
          .toList()
        ..sort((a, b) {
          final c = b.productCount.compareTo(a.productCount);
          return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      return HomeResult(list);
    } catch (e) {
      // Fall back to categories present on loaded products.
      final names = <String, String>{};
      for (final p in products) {
        final n = p.categoryName.trim();
        if (n.isNotEmpty) names.putIfAbsent(n.toLowerCase(), () => n);
      }
      return HomeResult(names.values.map((n) => HomeCategory(n)).toList(),
          ok: false, message: _err(e));
    }
  }

  // ── Products ────────────────────────────────────────────
  static Future<HomeResult<List<Product>>> getProducts() async {
    try {
      final r = await ProductService.getApprovedProductList();
      return HomeResult(r.data);
    } catch (e) {
      return HomeResult(const [], ok: false, message: _err(e));
    }
  }

  // ── Cart badge ──────────────────────────────────────────
  static Future<int> getCartCount() async {
    try {
      final userId = await SharedPreferencesHelper.getUserId();
      if (userId == null) return 0;
      final r = await CartService.getCartList(GetCartListRequest(userId: userId));
      return r.cartItems.length;
    } catch (_) {
      return 0;
    }
  }
}