// lib/models/my_product_model.dart
//
// A seller's product as returned by ProductSerializer
// (POST /product/company/products-list/  { company_id?, include_all: true }).
//
// Notes on the payload:
//   * price / discount_value / GST_percent are DecimalFields -> strings ("540.00")
//   * final_price is a SerializerMethodField -> number (includes active offers)
//   * thumbnail_s3_key and images[].image_s3_key are full public S3 URLs
//   * has_pending_update is added by the list view (update request awaiting admin)

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
double? _dn(dynamic v) {
  if (v == null || v.toString().isEmpty) return null;
  return v is num ? v.toDouble() : double.tryParse(v.toString());
}

int _i(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
int? _in(dynamic v) {
  if (v == null) return null;
  final i = v is int ? v : int.tryParse(v.toString());
  return (i == null || i == 0) ? null : i;
}

String _s(dynamic v) => v?.toString() ?? '';

enum ProductReviewStatus { approved, pending, rejected }

class MyProductImage {
  final int id;
  final String url;
  MyProductImage({required this.id, required this.url});

  factory MyProductImage.fromJson(Map<String, dynamic> j) =>
      MyProductImage(id: _i(j['id']), url: _s(j['image_s3_key']));
}

class MyProductVariant {
  final int id;
  final Map<String, String> attributes;
  final double price;
  final int stock;
  final String sku;

  MyProductVariant({
    required this.id,
    required this.attributes,
    required this.price,
    required this.stock,
    required this.sku,
  });

  factory MyProductVariant.fromJson(Map<String, dynamic> j) {
    final raw = j['attributes'];
    final attrs = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) => attrs[k.toString()] = v.toString());
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        attrs['Option ${i + 1}'] = raw[i].toString();
      }
    }
    return MyProductVariant(
      id: _i(j['id']),
      attributes: attrs,
      price: _d(j['price']),
      stock: _i(j['stock_quantity']),
      sku: _s(j['sku']),
    );
  }

  String get title => attributes.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
}

class MyProduct {
  final int id;
  final String name;
  final String description;
  final String productCode;

  final int? companyId;
  final String companyName;
  final int? branchId;
  final String branchName;
  final int? categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String subcategoryName;
  final int? brandId;
  final String brandName;
  final int? unitId;
  final String unitName;

  final double price;
  final double finalPrice;
  final String discountType; // '', flat, percent
  final double? discountValue;
  final double? gstPercent;
  final String hsnCode;

  final int stock;
  final String weight; // "1.5 kg"
  final String length; // "20 cm"
  final String width;
  final String height;

  final String thumbnail;
  final List<MyProductImage> images;
  final Map<String, String> specifications;
  final List<MyProductVariant> variants;

  final String manufacturingDate; // yyyy-mm-dd
  final String expiryDate;
  final String bestBefore;
  final bool franchiseAvailable;

  final String status; // approved | pending | rejected
  final bool isActive;
  final bool hasPendingUpdate;
  final String createdAt;

  MyProduct({
    required this.id,
    required this.name,
    this.description = '',
    this.productCode = '',
    this.companyId,
    this.companyName = '',
    this.branchId,
    this.branchName = '',
    this.categoryId,
    this.categoryName = '',
    this.subcategoryId,
    this.subcategoryName = '',
    this.brandId,
    this.brandName = '',
    this.unitId,
    this.unitName = '',
    this.price = 0,
    this.finalPrice = 0,
    this.discountType = '',
    this.discountValue,
    this.gstPercent,
    this.hsnCode = '',
    this.stock = 0,
    this.weight = '',
    this.length = '',
    this.width = '',
    this.height = '',
    this.thumbnail = '',
    this.images = const [],
    this.specifications = const {},
    this.variants = const [],
    this.manufacturingDate = '',
    this.expiryDate = '',
    this.bestBefore = '',
    this.franchiseAvailable = false,
    this.status = 'pending',
    this.isActive = true,
    this.hasPendingUpdate = false,
    this.createdAt = '',
  });

  factory MyProduct.fromJson(Map<String, dynamic> j) {
    final specs = <String, String>{};
    final rawSpecs = j['specifications'];
    if (rawSpecs is Map) {
      rawSpecs.forEach((k, v) => specs[k.toString()] = v?.toString() ?? '');
    } else if (rawSpecs is List) {
      for (final e in rawSpecs) {
        if (e is Map && e['key'] != null) specs[e['key'].toString()] = _s(e['value']);
      }
    }

    final price = _d(j['price']);
    final fp = _dn(j['final_price']);

    return MyProduct(
      id: _i(j['id']),
      name: _s(j['name']),
      description: _s(j['description']),
      productCode: _s(j['product_code']),
      companyId: _in(j['company']),
      companyName: _s(j['company_name']),
      branchId: _in(j['branch']),
      branchName: _s(j['branch_name']),
      categoryId: _in(j['category']),
      categoryName: _s(j['category_name']),
      subcategoryId: _in(j['subcategory']),
      subcategoryName: _s(j['subcategory_name']),
      brandId: _in(j['brand']),
      brandName: _s(j['brand_name']),
      unitId: _in(j['unit']),
      unitName: _s(j['unit_name']),
      price: price,
      finalPrice: (fp == null || fp <= 0) ? price : fp,
      discountType: _s(j['discount_type']),
      discountValue: _dn(j['discount_value']),
      gstPercent: _dn(j['GST_percent']),
      hsnCode: _s(j['HSN_code']),
      stock: _i(j['stock_quantity']),
      weight: _s(j['weight']),
      length: _s(j['length']),
      width: _s(j['width']),
      height: _s(j['height']),
      thumbnail: _s(j['thumbnail_s3_key']),
      images: (j['images'] is List)
          ? (j['images'] as List)
          .whereType<Map>()
          .map((e) => MyProductImage.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.url.isNotEmpty)
          .toList()
          : const [],
      specifications: specs,
      variants: (j['variants'] is List)
          ? (j['variants'] as List)
          .whereType<Map>()
          .map((e) => MyProductVariant.fromJson(Map<String, dynamic>.from(e)))
          .toList()
          : const [],
      manufacturingDate: _s(j['manufacturing_date']),
      expiryDate: _s(j['expiry_date']),
      bestBefore: _s(j['best_before_duration']),
      franchiseAvailable: j['is_franchise_available'] == true,
      status: _s(j['status']).toLowerCase(),
      isActive: j['is_active'] != false,
      hasPendingUpdate: j['has_pending_update'] == true,
      createdAt: _s(j['created_at']),
    );
  }

  // ── Derived ────────────────────────────────────────────
  ProductReviewStatus get review => switch (status) {
    'approved' => ProductReviewStatus.approved,
    'rejected' => ProductReviewStatus.rejected,
    _ => ProductReviewStatus.pending,
  };

  static const int lowStockThreshold = 10; // same as backend low-stock API

  bool get isLowStock => stock <= lowStockThreshold;
  bool get isOutOfStock => stock <= 0;
  bool get hasDiscount => finalPrice > 0 && finalPrice < price;
  int get discountPercent => price <= 0 ? 0 : (((price - finalPrice) / price) * 100).round();

  String get catalogLine => subcategoryName.isNotEmpty ? subcategoryName : categoryName;

  /// Splits "1.5 kg" -> (1.5, "kg"). Used to prefill the edit form.
  static (String, String) splitMeasure(String raw, String fallbackUnit) {
    final m = RegExp(r'([\d.]+)\s*([a-zA-Z]*)').firstMatch(raw.trim());
    if (m == null) return ('', fallbackUnit);
    final unit = (m.group(2) ?? '').toLowerCase();
    return (m.group(1) ?? '', unit.isEmpty ? fallbackUnit : unit);
  }
}

class MyProductsResponse {
  final bool ok;
  final String? message;
  final List<MyProduct> items;

  MyProductsResponse({required this.ok, this.message, this.items = const []});
}