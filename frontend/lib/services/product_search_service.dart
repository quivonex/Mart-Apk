// lib/services/product_search_service.dart
//
// Server-side product search
//   POST product/product/search/   {search: "red shoes"}
//   -> {status:true, count, data:[Product]}
//   • keywords are OR-matched on name, category, subcategory and brand
//   • when logged in (token sent) the backend saves it to search history
//
// Results are ranked here: name matches first, then by how many keywords hit.

import '../models/product_model.dart';
import 'api_urls.dart';
import 'qnx_api.dart';

class ProductSearchResult {
  final bool ok;
  final List<Product> products;
  final String message;
  const ProductSearchResult(this.ok, this.products, [this.message = '']);
}

class ProductSearchService {
  ProductSearchService._();

  static Future<ProductSearchResult> search(String text) async {
    final q = text.trim();
    if (q.isEmpty) return const ProductSearchResult(true, []);
    var r = await QnxApi.post(ApiUrls.productSearchUrl, {'search': q}, auth: QnxAuth.optional);
    // expired token → search still works as a guest (history just isn't saved)
    if (r.code == 401) r = await QnxApi.post(ApiUrls.productSearchUrl, {'search': q}, auth: QnxAuth.none);
    if (!r.ok) return ProductSearchResult(false, const [], r.error('Search failed.'));
    final list = <Product>[];
    for (final m in r.list) {
      try {
        list.add(Product.fromJson(m));
      } catch (_) {}
    }
    return ProductSearchResult(true, _rank(list, q));
  }

  static List<Product> _rank(List<Product> list, String q) {
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    int score(Product p) {
      final name = p.name.toLowerCase();
      final other = '${p.categoryName} ${p.subcategoryName} ${p.brandName}'.toLowerCase();
      var s = 0;
      if (name.contains(q.toLowerCase())) s += 100;
      for (final w in words) {
        if (name.contains(w)) s += 10;
        if (other.contains(w)) s += 3;
      }
      return s;
    }

    final scored = [for (final p in list) (p, score(p))]..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final e in scored) e.$1];
  }
}
