import 'dart:convert' show jsonDecode;
import 'package:qnx_mart/l10n/app_language.dart';

dynamic _jsonDecode(String s) => jsonDecode(s);

// ============ Product Model ============

/// Turns a backend S3 key / relative path into a full URL.
String productMediaUrl(Object? raw) {
  final v = (raw ?? '').toString().trim();
  if (v.isEmpty || v == 'null') return '';
  if (v.startsWith('http')) return v;
  return 'https://api.qnxmartb2b.com/${v.startsWith('/') ? v.substring(1) : v}';
}

String _str(Object? v) {
  final s = (v ?? '').toString().trim();
  return s == 'null' ? '' : s;
}

/// One buyable option of a product (e.g. Red / XL) from `variants`.
class ProductVariantInfo {
  final int id;
  final Map<String, String> attributes; // {"Color": "Red", "Size": "M"}
  final String price;
  final String finalPrice;
  final int stockQuantity;
  final String sku;
  final int imageIndex;
  final String image; // full URL or ''

  const ProductVariantInfo({
    required this.id,
    required this.attributes,
    required this.price,
    required this.finalPrice,
    required this.stockQuantity,
    required this.sku,
    required this.imageIndex,
    required this.image,
  });

  factory ProductVariantInfo.fromJson(Map<String, dynamic> j) {
    final raw = j['attributes'];
    final attrs = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) => attrs['$k'] = _str(v));
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final v = raw[i];
        if (v is Map) {
          // [{"name": "Color", "value": "Red"}] or [{"Color": "Red"}]
          if (v.containsKey('name') && v.containsKey('value')) {
            attrs[_str(v['name'])] = _str(v['value']);
          } else {
            v.forEach((k, val) => attrs['$k'] = _str(val));
          }
        } else {
          attrs['Option ${i + 1}'] = _str(v);
        }
      }
    } else if (_str(raw).isNotEmpty) {
      attrs['Option'] = _str(raw);
    }
    return ProductVariantInfo(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      attributes: attrs,
      price: _str(j['price']).isEmpty ? '0' : _str(j['price']),
      finalPrice: _str(j['final_price']).isEmpty ? _str(j['price']) : _str(j['final_price']),
      stockQuantity: j['stock_quantity'] is int
          ? j['stock_quantity']
          : int.tryParse('${j['stock_quantity'] ?? ''}') ?? 0,
      sku: _str(j['sku']),
      imageIndex: j['image_index'] is int ? j['image_index'] : int.tryParse('${j['image_index']}') ?? 0,
      image: productMediaUrl(j['image'] ?? j['image_s3_key']),
    );
  }

  /// "Red · M" (values only) – short label for chips.
  String get label {
    final vals = attributes.values.where((v) => v.isNotEmpty).toList();
    if (vals.isNotEmpty) return vals.join(' · ');
    return sku.isNotEmpty ? sku : tr('Option {0}', [id]);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'attributes': attributes,
    'price': price,
    'final_price': finalPrice,
    'stock_quantity': stockQuantity,
    'sku': sku,
    'image_index': imageIndex,
    'image': image,
  };
}

class Product {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String thumbnail;
  final String thumbnailS3Key;
  final String categoryName;
  final String subcategoryName;
  final String brandName;
  final String companyName;

  /// Seller's user id (company owner) – for "Chat with seller".
  final int? companyUserId;
  final bool isFranchiseAvailable;
  final String finalPrice;
  final String price;
  final String discountType;
  final String discountValue;
  final dynamic appliedOffer;

  // Present in product/approved-list/ (full ProductSerializer). Optional so
  // every existing Product(...) call keeps working.
  final int? stockQuantity;
  final String unitName;
  final List<String> videos; // full S3 URLs of product videos

  // Full detail fields (ProductSerializer `__all__`). All optional / defaulted.
  final List<String> images; // full URLs of all product photos
  final List<ProductVariantInfo> variants;
  final Map<String, String> specifications;
  final String productCode;
  final String hsnCode;
  final String weight;
  final String length;
  final String width;
  final String height;
  final String manufacturingDate;
  final String expiryDate;
  final String bestBeforeDuration;
  final String branchName;
  final bool isFeatured;
  final String createdAt;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.thumbnail,
    required this.thumbnailS3Key,
    required this.categoryName,
    required this.subcategoryName,
    required this.brandName,
    required this.companyName,
    this.companyUserId,
    required this.isFranchiseAvailable,
    required this.finalPrice,
    required this.price,
    required this.discountType,
    required this.discountValue,
    required this.appliedOffer,
    this.stockQuantity,
    this.unitName = '',
    this.videos = const [],
    this.images = const [],
    this.variants = const [],
    this.specifications = const {},
    this.productCode = '',
    this.hsnCode = '',
    this.weight = '',
    this.length = '',
    this.width = '',
    this.height = '',
    this.manufacturingDate = '',
    this.expiryDate = '',
    this.bestBeforeDuration = '',
    this.branchName = '',
    this.isFeatured = false,
    this.createdAt = '',
  });

  /// Thumbnail first, then every other photo (no duplicates).
  List<String> get gallery {
    final out = <String>[];
    for (final u in [thumbnail, ...images]) {
      if (u.isNotEmpty && !out.contains(u)) out.add(u);
    }
    return out;
  }

  static Map<String, String> _specs(Object? raw) {
    dynamic v = raw;
    if (v is String && v.trim().startsWith('{')) {
      try {
        v = _jsonDecode(v);
      } catch (_) {}
    }
    final out = <String, String>{};
    if (v is Map) {
      v.forEach((k, val) {
        final t = val is List ? val.join(', ') : _str(val);
        if ('$k'.trim().isNotEmpty && t.isNotEmpty) out['$k'] = t;
      });
    } else if (v is List) {
      for (final e in v) {
        if (e is Map && e.containsKey('key')) {
          out[_str(e['key'])] = _str(e['value']);
        } else if (e is Map && e.containsKey('name')) {
          out[_str(e['name'])] = _str(e['value']);
        }
      }
    }
    return out;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // Handle both thumbnail and thumbnail_s3_key
    String thumbnailValue = json['thumbnail'] ?? '';
    if (thumbnailValue.isEmpty) {
      thumbnailValue = json['thumbnail_s3_key'] ?? '';
    }

    if (thumbnailValue.isNotEmpty && !thumbnailValue.startsWith('http')) {
      thumbnailValue = 'https://api.qnxmartb2b.com/$thumbnailValue';
    }
    // No thumbnail? Use the first product photo so cards/detail still show an image.
    if (thumbnailValue.isEmpty && json['images'] is List) {
      for (final im in json['images'] as List) {
        final u = productMediaUrl(im is Map ? (im['image_s3_key'] ?? im['image']) : im);
        if (u.isNotEmpty) {
          thumbnailValue = u;
          break;
        }
      }
    }

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      thumbnail: thumbnailValue,
      thumbnailS3Key: json['thumbnail_s3_key'] ?? '',
      categoryName: json['category_name'] ?? '',
      subcategoryName: json['subcategory_name'] ?? '',
      brandName: json['brand_name'] ?? '',
      companyName: json['company_name'] ?? '',
      companyUserId: json['company_user_id'] is int
          ? json['company_user_id']
          : int.tryParse('${json['company_user_id'] ?? ''}'),
      isFranchiseAvailable: json['is_franchise_available'] ?? false,
      finalPrice: json['final_price']?.toString() ?? '0',
      price: json['price']?.toString() ?? '0',
      discountType: json['discount_type'] ?? '',
      discountValue: json['discount_value']?.toString() ?? '0',
      appliedOffer: json['applied_offer'],
      stockQuantity: json['stock_quantity'] is int
          ? json['stock_quantity']
          : int.tryParse(json['stock_quantity']?.toString() ?? ''),
      unitName: json['unit_name']?.toString() ?? '',
      videos: (json['videos'] is List)
          ? (json['videos'] as List)
          .map((v) => productMediaUrl(v is Map ? (v['video_s3_key'] ?? v['video']) : v))
          .where((u) => u.isNotEmpty)
          .toList()
          : const [],
      images: (json['images'] is List)
          ? (json['images'] as List)
          .map((v) => productMediaUrl(v is Map ? (v['image_s3_key'] ?? v['image']) : v))
          .where((u) => u.isNotEmpty)
          .toList()
          : const [],
      variants: (json['variants'] is List)
          ? (json['variants'] as List)
          .whereType<Map>()
          .map((v) => ProductVariantInfo.fromJson(Map<String, dynamic>.from(v)))
          .toList()
          : const [],
      specifications: _specs(json['specifications']),
      productCode: _str(json['product_code']),
      hsnCode: _str(json['HSN_code'] ?? json['hsn_code']),
      weight: _str(json['weight']),
      length: _str(json['length']),
      width: _str(json['width']),
      height: _str(json['height']),
      manufacturingDate: _str(json['manufacturing_date']),
      expiryDate: _str(json['expiry_date']),
      bestBeforeDuration: _str(json['best_before_duration']),
      branchName: _str(json['branch_name']),
      isFeatured: json['is_featured'] == true,
      createdAt: _str(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'thumbnail': thumbnail,
      'thumbnail_s3_key': thumbnailS3Key,
      'category_name': categoryName,
      'subcategory_name': subcategoryName,
      'brand_name': brandName,
      'company_name': companyName,
      'company_user_id': companyUserId,
      'is_franchise_available': isFranchiseAvailable,
      'final_price': finalPrice,
      'price': price,
      'discount_type': discountType,
      'discount_value': discountValue,
      'applied_offer': appliedOffer,
      'stock_quantity': stockQuantity,
      'unit_name': unitName,
      'videos': [for (final v in videos) {'video_s3_key': v}],
      'images': [for (final i in images) {'image_s3_key': i}],
      'variants': [for (final v in variants) v.toJson()],
      'specifications': specifications,
      'product_code': productCode,
      'HSN_code': hsnCode,
      'weight': weight,
      'length': length,
      'width': width,
      'height': height,
      'manufacturing_date': manufacturingDate,
      'expiry_date': expiryDate,
      'best_before_duration': bestBeforeDuration,
      'branch_name': branchName,
      'is_featured': isFeatured,
      'created_at': createdAt,
    };
  }
}

// ============ Latest Products Response ============

class LatestProductsResponse {
  final bool status;
  final List<Product> data;

  LatestProductsResponse({
    required this.status,
    required this.data,
  });

  factory LatestProductsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return LatestProductsResponse(
      status: json['status'] ?? false,
      data: dataList.map((item) => Product.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

// ============ Approved Product List Response ============

class ApprovedProductListResponse {
  final bool status;
  final List<Product> data;

  ApprovedProductListResponse({
    required this.status,
    required this.data,
  });

  factory ApprovedProductListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return ApprovedProductListResponse(
      status: json['status'] ?? false,
      data: dataList.map((item) => Product.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}
