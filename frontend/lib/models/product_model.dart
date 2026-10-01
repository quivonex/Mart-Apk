// ============ Product Model ============

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
  final bool isFranchiseAvailable;
  final String finalPrice;
  final String price;
  final String discountType;
  final String discountValue;
  final dynamic appliedOffer;

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
    required this.isFranchiseAvailable,
    required this.finalPrice,
    required this.price,
    required this.discountType,
    required this.discountValue,
    required this.appliedOffer,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Handle both thumbnail and thumbnail_s3_key
    String thumbnailValue = json['thumbnail'] ?? '';
    if (thumbnailValue.isEmpty) {
      thumbnailValue = json['thumbnail_s3_key'] ?? '';
    }

    if (thumbnailValue.isNotEmpty && !thumbnailValue.startsWith('http')) {
      thumbnailValue = 'https://api.qnxmartb2b.com/$thumbnailValue';
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
      isFranchiseAvailable: json['is_franchise_available'] ?? false,
      finalPrice: json['final_price']?.toString() ?? '0',
      price: json['price']?.toString() ?? '0',
      discountType: json['discount_type'] ?? '',
      discountValue: json['discount_value']?.toString() ?? '0',
      appliedOffer: json['applied_offer'],
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
      'is_franchise_available': isFranchiseAvailable,
      'final_price': finalPrice,
      'price': price,
      'discount_type': discountType,
      'discount_value': discountValue,
      'applied_offer': appliedOffer,
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