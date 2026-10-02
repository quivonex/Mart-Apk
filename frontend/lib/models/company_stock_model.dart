// lib/models/company_stock_model.dart
//
// POST /company/company/stock/      -> CompanyStockResponse
// POST /company/company/low-stock/  -> LowStockResponse

import '../services/api_urls.dart';

int _toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

/// Builds a full image URL from an S3 key (backend returns raw keys here).
String s3Url(String keyOrUrl) {
  if (keyOrUrl.isEmpty) return '';
  if (keyOrUrl.startsWith('http')) return keyOrUrl;
  return '${ApiUrls.s3BaseUrl}/$keyOrUrl';
}

class StockItem {
  final int productId;
  final String productName;
  final int stockQuantity;
  final int soldQuantity;
  final int remainingStock;

  StockItem({
    required this.productId,
    required this.productName,
    required this.stockQuantity,
    required this.soldQuantity,
    required this.remainingStock,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    productId: _toInt(json['product_id']),
    productName: json['product_name']?.toString() ?? '',
    stockQuantity: _toInt(json['stock_quantity']),
    soldQuantity: _toInt(json['sold_quantity']),
    remainingStock: _toInt(json['remaining_stock']),
  );

  /// 0..1 share of stock that has been sold.
  double get soldRatio =>
      stockQuantity <= 0 ? 0 : (soldQuantity / stockQuantity).clamp(0, 1).toDouble();

  bool get isLow => remainingStock <= 10;
  bool get isOut => remainingStock <= 0;
}

class CompanyStockResponse {
  final bool status;
  final String? message;
  final String companyName;
  final List<StockItem> products;

  CompanyStockResponse({
    required this.status,
    this.message,
    this.companyName = '',
    this.products = const [],
  });

  factory CompanyStockResponse.fromJson(Map<String, dynamic> json) {
    final list = json['products'] is List ? json['products'] as List : const [];
    return CompanyStockResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      companyName: json['company']?.toString() ?? '',
      products: list
          .whereType<Map>()
          .map((e) => StockItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get isSuccess => status;
  int get totalStock => products.fold(0, (a, p) => a + p.stockQuantity);
  int get totalSold => products.fold(0, (a, p) => a + p.soldQuantity);
  int get totalRemaining => products.fold(0, (a, p) => a + p.remainingStock);
}

class LowStockItem {
  final int id;
  final String name;
  final int stockQuantity;
  final String thumbnail;
  final double price;
  final double finalPrice;

  LowStockItem({
    required this.id,
    required this.name,
    required this.stockQuantity,
    required this.thumbnail,
    required this.price,
    required this.finalPrice,
  });

  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(
    id: _toInt(json['id']),
    name: json['name']?.toString() ?? '',
    stockQuantity: _toInt(json['stock_quantity']),
    thumbnail: s3Url(json['thumbnail_s3_key']?.toString() ?? ''),
    price: _toDouble(json['price']),
    finalPrice: _toDouble(json['final_price']),
  );
}

class LowStockResponse {
  final bool status;
  final String? message;
  final int count;
  final List<LowStockItem> products;

  LowStockResponse({
    required this.status,
    this.message,
    this.count = 0,
    this.products = const [],
  });

  factory LowStockResponse.fromJson(Map<String, dynamic> json) {
    final list = json['products'] is List ? json['products'] as List : const [];
    final items = list
        .whereType<Map>()
        .map((e) => LowStockItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return LowStockResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      count: json['count'] == null ? items.length : _toInt(json['count']),
      products: items,
    );
  }

  bool get isSuccess => status;
}