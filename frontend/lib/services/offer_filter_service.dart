// lib/services/offer_filter_service.dart
//
// Discount filter options for the home filter sheet (public)
//   POST offer/offers/filter-options/   {}
//   -> {product_discount:{percentage:[{label, min, max, product_count, product_ids}],
//                         flat:[{…, product_slugs}]},
//       offer_discount:  {percentage:[…], flat:[…]}}
//
// Groups with the same label are merged (product ids unioned) so the sheet
// shows one chip per range, e.g. "10% - 20% off", "₹100 - ₹500 off".

import 'api_urls.dart';
import 'qnx_api.dart';

class DiscountOption {
  final String label;
  final String kind; // percentage | flat
  final double min;
  final double? max;
  final Set<int> productIds;
  final Set<String> productSlugs;

  DiscountOption({
    required this.label,
    required this.kind,
    required this.min,
    required this.max,
    required this.productIds,
    required this.productSlugs,
  });

  int get count => productIds.isNotEmpty ? productIds.length : productSlugs.length;

  bool matches(int id, String slug) => productIds.contains(id) || (slug.isNotEmpty && productSlugs.contains(slug));
}

class OfferFilterService {
  OfferFilterService._();

  static List<DiscountOption>? _cache;

  /// Options with at least one product; percentage first, then flat.
  static Future<List<DiscountOption>> options({bool refresh = false}) async {
    if (!refresh && _cache != null) return _cache!;
    final r = await QnxApi.post(ApiUrls.offerFilterOptionsUrl, const {}, auth: QnxAuth.none);
    if (!r.ok) return _cache ?? const [];
    final body = r.dataMap;
    final byKey = <String, DiscountOption>{};
    for (final group in const ['product_discount', 'offer_discount']) {
      final g = body[group];
      if (g is! Map) continue;
      for (final kind in const ['percentage', 'flat']) {
        for (final m in (g[kind] as List? ?? const []).whereType<Map>()) {
          final label = qStr(m['label']);
          if (label.isEmpty) continue;
          final ids = <int>{
            for (final v in (m['product_ids'] as List? ?? const []))
              if (qInt(v) != null) qInt(v)!,
          };
          final slugs = <String>{
            for (final v in (m['product_slugs'] as List? ?? const []))
              if (qStr(v).isNotEmpty) qStr(v),
          };
          final key = '$kind|$label';
          final old = byKey[key];
          if (old == null) {
            byKey[key] = DiscountOption(
              label: label,
              kind: kind,
              min: qDbl(m['min']),
              max: m['max'] == null ? null : qDbl(m['max']),
              productIds: ids,
              productSlugs: slugs,
            );
          } else {
            old.productIds.addAll(ids);
            old.productSlugs.addAll(slugs);
          }
        }
      }
    }
    final list = byKey.values.where((o) => o.count > 0).toList()
      ..sort((a, b) {
        if (a.kind != b.kind) return a.kind == 'percentage' ? -1 : 1;
        return a.min.compareTo(b.min);
      });
    _cache = list;
    return list;
  }
}
