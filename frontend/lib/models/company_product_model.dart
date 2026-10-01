// ============ Company Product Image ============

class CPImage {
  final int id;
  final String imageS3Key;

  CPImage({required this.id, required this.imageS3Key});

  factory CPImage.fromJson(Map<String, dynamic> json) {
    return CPImage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      imageS3Key: json['image_s3_key']?.toString() ?? '',
    );
  }
}

// ============ Company Product Video ============

class CPVideo {
  final int id;
  final String videoS3Key;

  CPVideo({required this.id, required this.videoS3Key});

  factory CPVideo.fromJson(Map<String, dynamic> json) {
    return CPVideo(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      videoS3Key: json['video_s3_key']?.toString() ?? '',
    );
  }
}

// ============ Specification ============

class CPSpecification {
  final String key;
  final String value;

  CPSpecification({required this.key, required this.value});

  factory CPSpecification.fromJson(Map<String, dynamic> json) {
    return CPSpecification(
      key: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'value': value};
}

// ============ Variant ============

class CPVariant {
  final int id;
  final Map<String, dynamic> attributes;
  final String price;
  final String finalPrice;
  final int stockQuantity;
  final String sku;
  final String image;

  CPVariant({
    required this.id,
    required this.attributes,
    required this.price,
    required this.finalPrice,
    required this.stockQuantity,
    required this.sku,
    required this.image,
  });

  factory CPVariant.fromJson(Map<String, dynamic> json) {
    return CPVariant(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'])
          : {},
      price: json['price']?.toString() ?? '0',
      finalPrice: json['final_price']?.toString() ?? '0',
      stockQuantity: json['stock_quantity'] is int
          ? json['stock_quantity']
          : int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
      sku: json['sku']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
    );
  }

  String get attributesDisplay {
    if (attributes.isEmpty) return '';
    return attributes.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(' · ');
  }
}

// ============ Company Product ============

class CompanyProduct {
  final int id;
  final String name;
  final String description;
  final String thumbnailS3Key;
  final List<CPImage> images;
  final List<CPVideo> videos;
  final String companyName;
  final String branchName;
  final String categoryName;
  final String subcategoryName;
  final String brandName;
  final String unitName;
  final String price;
  final String finalPrice;
  final String discountType;
  final String discountValue;
  final int stockQuantity;
  final String hsnCode;
  final String gstPercent;
  final String weight;
  final String length;
  final String width;
  final String height;
  final String manufacturingDate;
  final String? expiryDate;
  final String bestBeforeDuration;
  final List<CPSpecification> specifications;
  final List<CPVariant> variants;
  final bool isActive;
  final bool isFeatured;
  final String status;
  final String createdAt;

  CompanyProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.thumbnailS3Key,
    required this.images,
    required this.videos,
    required this.companyName,
    required this.branchName,
    required this.categoryName,
    required this.subcategoryName,
    required this.brandName,
    required this.unitName,
    required this.price,
    required this.finalPrice,
    required this.discountType,
    required this.discountValue,
    required this.stockQuantity,
    required this.hsnCode,
    required this.gstPercent,
    required this.weight,
    required this.length,
    required this.width,
    required this.height,
    required this.manufacturingDate,
    this.expiryDate,
    required this.bestBeforeDuration,
    required this.specifications,
    required this.variants,
    required this.isActive,
    required this.isFeatured,
    required this.status,
    required this.createdAt,
  });

  factory CompanyProduct.fromJson(Map<String, dynamic> json) {
    final imgs = json['images'] as List? ?? [];
    final vids = json['videos'] as List? ?? [];
    final specs = json['specifications'] as List? ?? [];
    final vars = json['variants'] as List? ?? [];

    return CompanyProduct(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailS3Key: json['thumbnail_s3_key']?.toString() ?? '',
      images: imgs.map((e) => CPImage.fromJson(e)).toList(),
      videos: vids.map((e) => CPVideo.fromJson(e)).toList(),
      companyName: json['company_name']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      subcategoryName: json['subcategory_name']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      finalPrice: json['final_price']?.toString() ?? '0',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: json['discount_value']?.toString() ?? '0',
      stockQuantity: json['stock_quantity'] is int
          ? json['stock_quantity']
          : int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
      hsnCode: json['HSN_code']?.toString() ?? '',
      gstPercent: json['GST_percent']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      length: json['length']?.toString() ?? '',
      width: json['width']?.toString() ?? '',
      height: json['height']?.toString() ?? '',
      manufacturingDate: json['manufacturing_date']?.toString() ?? '',
      expiryDate: json['expiry_date']?.toString(),
      bestBeforeDuration: json['best_before_duration']?.toString() ?? '',
      specifications: specs.map((e) => CPSpecification.fromJson(e)).toList(),
      variants: vars.map((e) => CPVariant.fromJson(e)).toList(),
      isActive: json['is_active'] == true,
      isFeatured: json['is_featured'] == true,
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  String get thumbnailUrl => thumbnailS3Key;
  bool get hasVariants => variants.isNotEmpty;
  bool get isApproved => status.toLowerCase() == 'approved';
}

// ============ List Response ============

class CompanyProductsListResponse {
  final bool status;
  final String? message;
  final List<CompanyProduct> data;

  CompanyProductsListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory CompanyProductsListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return CompanyProductsListResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: dataList.map((e) => CompanyProduct.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
  bool get hasProducts => data.isNotEmpty;
}

// ============ Create/Update Response ============

class CompanyProductActionResponse {
  final bool status;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  CompanyProductActionResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  factory CompanyProductActionResponse.fromJson(Map<String, dynamic> json) {
    return CompanyProductActionResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'])
          : null,
      errors: json['errors'] is Map
          ? Map<String, dynamic>.from(json['errors'])
          : null,
    );
  }

  bool get isSuccess => status;

  int? get newId {
    if (data == null) return null;
    final id = data!['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String get displayMessage {
    if (isSuccess) return message ?? 'Success';

    if (errors != null && errors!.isNotEmpty) {
      final firstKey = errors!.keys.first;
      final firstError = errors![firstKey];
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }

    return message ?? 'Something went wrong';
  }
}