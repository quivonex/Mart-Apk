// ============ Property Image Model ============

class PropertyImage {
  final int id;
  final String imageS3Key;
  final bool isPrimary;

  PropertyImage({
    required this.id,
    required this.imageS3Key,
    required this.isPrimary,
  });

  factory PropertyImage.fromJson(Map<String, dynamic> json) {
    String key = json['image_s3_key']?.toString() ?? '';
    // Prepend base URL if it's a relative path/key
    if (key.isNotEmpty && !key.startsWith('http')) {
      key = 'https://api.qnxmartb2b.com/$key';
    }

    return PropertyImage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      imageS3Key: key,
      isPrimary: json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_s3_key': imageS3Key,
      'is_primary': isPrimary,
    };
  }
}

// ============ Pricing Slab Model ============

class PricingSlab {
  final String basePrice;

  PricingSlab({required this.basePrice});

  factory PricingSlab.fromJson(Map<String, dynamic> json) {
    return PricingSlab(
      basePrice: json['base_price']?.toString() ?? '0',
    );
  }

  double get basePriceAsDouble =>
      double.tryParse(basePrice.replaceAll(',', '')) ?? 0.0;

  Map<String, dynamic> toJson() {
    return {
      'base_price': basePrice,
    };
  }
}

// ============ Amenity Model (used inside property + in filter list) ============

class Amenity {
  final int id;
  final String name;
  final String icon;

  Amenity({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }
}

// ============ Property Model ============

class Property {
  final int id;
  final String slug;
  final String propertyType;
  final String transactionType;
  final String city;
  final String area;
  final String address;
  final List<PropertyImage> images;
  final List<PricingSlab> pricingSlabs;
  final List<Amenity> amenities;
  // Optional so existing code keeps compiling.
  final String title;
  final String description;

  Property({
    required this.id,
    required this.slug,
    required this.propertyType,
    required this.transactionType,
    required this.city,
    required this.area,
    required this.address,
    required this.images,
    required this.pricingSlabs,
    required this.amenities,
    this.title = '',
    this.description = '',
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] as List? ?? [];
    final slabsList = json['pricing_slabs'] as List? ?? [];
    final amenitiesList = json['amenities'] as List? ?? [];

    return Property(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      slug: json['slug']?.toString() ?? '',
      propertyType: json['property_type']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      images: imagesList.map((e) => PropertyImage.fromJson(e)).toList(),
      pricingSlabs: slabsList.map((e) => PricingSlab.fromJson(e)).toList(),
      amenities: amenitiesList.map((e) => Amenity.fromJson(e)).toList(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  /// All image URLs, primary first (for the card carousel).
  List<String> get imageUrls {
    final sorted = [...images]..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
    return [for (final i in sorted) if (i.imageS3Key.startsWith('http')) i.imageS3Key];
  }

  /// Backend label for property_type (same as the website).
  String get typeLabel => switch (propertyType) {
    'flat' => 'Flat / Apartment',
    'villa' => 'Villa / Bungalow',
    'plot' => 'Plot / Land',
    'commercial' => 'Commercial Space',
    'shop' => 'Shop / Retail',
    'office' => 'Office Space',
    'warehouse' => 'Warehouse',
    'other' => 'Other',
    _ => formattedPropertyType,
  };

  /// Backend label for transaction_type.
  String get transactionLabel => switch (transactionType) {
    'sale' => 'For Sale',
    'rent' => 'For Rent',
    'lease' => 'For Lease',
    'pg' => 'PG / Hostel',
    _ => formattedTransactionType,
  };

  /// Title shown on cards: the listing title, else "Flat / Apartment in Pune".
  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : '$typeLabel${city.isEmpty ? '' : ' in $city'}';

  /// Primary image URL (prefer is_primary = true, else first image)
  String get primaryImageUrl {
    if (images.isEmpty) return '';
    final primary = images.where((img) => img.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first.imageS3Key;
    return images.first.imageS3Key;
  }

  /// Minimum price from pricing slabs
  double get minPrice {
    if (pricingSlabs.isEmpty) return 0;
    double minVal = pricingSlabs.first.basePriceAsDouble;
    for (final slab in pricingSlabs) {
      if (slab.basePriceAsDouble < minVal && slab.basePriceAsDouble > 0) {
        minVal = slab.basePriceAsDouble;
      }
    }
    return minVal;
  }

  /// Formatted price string (e.g. "₹50.0 L" or "₹1.2 Cr")
  String get formattedMinPrice {
    final price = minPrice;
    if (price <= 0) return 'Price on request';
    if (price >= 10000000) {
      return '₹${(price / 10000000).toStringAsFixed(2)} Cr';
    } else if (price >= 100000) {
      return '₹${(price / 100000).toStringAsFixed(2)} L';
    } else if (price >= 1000) {
      return '₹${(price / 1000).toStringAsFixed(1)} K';
    }
    return '₹${price.toStringAsFixed(0)}';
  }

  /// Capitalize property type ("flat" → "Flat")
  String get formattedPropertyType {
    if (propertyType.isEmpty) return '';
    return propertyType[0].toUpperCase() + propertyType.substring(1);
  }

  /// Capitalize transaction type ("sale" → "For Sale")
  String get formattedTransactionType {
    if (transactionType.isEmpty) return '';
    final capped =
        transactionType[0].toUpperCase() + transactionType.substring(1);
    return 'For $capped';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'property_type': propertyType,
      'transaction_type': transactionType,
      'city': city,
      'area': area,
      'address': address,
      'images': images.map((e) => e.toJson()).toList(),
      'pricing_slabs': pricingSlabs.map((e) => e.toJson()).toList(),
      'amenities': amenities.map((e) => e.toJson()).toList(),
      'title': title,
      'description': description,
    };
  }
}

// ============ Property Response ============

class PropertyResponse {
  final bool status;
  final String? message;
  final List<Property> data;

  PropertyResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory PropertyResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return PropertyResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString(),
      data: dataList.map((e) => Property.fromJson(e)).toList(),
    );
  }

  bool get hasProperties => data.isNotEmpty;
}

// ============ Amenities List Response ============

class AmenitiesListResponse {
  final bool status;
  final String? message;
  final List<Amenity> data;

  AmenitiesListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory AmenitiesListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return AmenitiesListResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString(),
      data: dataList.map((e) => Amenity.fromJson(e)).toList(),
    );
  }
}

// ============ Property Video Model ============

class PropertyVideo {
  final int id;
  final String videoS3Key;
  final String title;

  PropertyVideo({
    required this.id,
    required this.videoS3Key,
    required this.title,
  });

  factory PropertyVideo.fromJson(Map<String, dynamic> json) {
    String key = json['video_s3_key']?.toString() ?? '';
    if (key.isNotEmpty && !key.startsWith('http')) {
      key = 'https://api.qnxmartb2b.com/$key';
    }

    return PropertyVideo(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      videoS3Key: key,
      title: json['title']?.toString() ?? '',
    );
  }
}

// ============ Flat Type Model ============

class FlatType {
  final String flatType;
  final bool isAvailable;
  final int areaSqft;
  final int carpetArea;
  final int builtUpArea;
  final int balconyArea;
  final int bedrooms;
  final int bathrooms;
  final int balconies;
  final int kitchens;
  final int parkingCount;
  final String description;

  FlatType({
    required this.flatType,
    required this.isAvailable,
    required this.areaSqft,
    required this.carpetArea,
    required this.builtUpArea,
    required this.balconyArea,
    required this.bedrooms,
    required this.bathrooms,
    required this.balconies,
    required this.kitchens,
    required this.parkingCount,
    required this.description,
  });

  factory FlatType.fromJson(Map<String, dynamic> json) {
    // ✅ FIXED: Handles String "1050.00" → int 1050
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) {
        final d = double.tryParse(v);
        return d?.toInt() ?? 0;
      }
      return 0;
    }

    return FlatType(
      flatType: json['flat_type']?.toString() ?? '',
      isAvailable: json['is_available'] == true,
      areaSqft: toInt(json['area_sqft']),
      carpetArea: toInt(json['carpet_area']),
      builtUpArea: toInt(json['built_up_area']),
      balconyArea: toInt(json['balcony_area']),
      bedrooms: toInt(json['bedrooms']),
      bathrooms: toInt(json['bathrooms']),
      balconies: toInt(json['balconies']),
      kitchens: toInt(json['kitchens']),
      parkingCount: toInt(json['parking_count']),
      description: json['description']?.toString() ?? '',
    );
  }
}

// ============ Pricing Slab (Detail) ============

class PricingSlabDetail {
  final String flatType;
  final int floor;
  final String basePrice;
  final String pricePerSqft;
  final String bookingAmount;
  final String discountPercentage;
  final String gstPercentage;
  final bool isAvailable;
  final Map<String, dynamic>? paymentSchedule;
  final Map<String, dynamic>? additionalCharges;

  PricingSlabDetail({
    required this.flatType,
    required this.floor,
    required this.basePrice,
    required this.pricePerSqft,
    required this.bookingAmount,
    required this.discountPercentage,
    required this.gstPercentage,
    required this.isAvailable,
    this.paymentSchedule,
    this.additionalCharges,
  });

  factory PricingSlabDetail.fromJson(Map<String, dynamic> json) {
    return PricingSlabDetail(
      flatType: json['flat_type']?.toString() ?? '',
      floor: json['floor'] is int
          ? json['floor']
          : int.tryParse(json['floor']?.toString() ?? '0') ?? 0,
      basePrice: json['base_price']?.toString() ?? '0',
      pricePerSqft: json['price_per_sqft']?.toString() ?? '0',
      bookingAmount: json['booking_amount']?.toString() ?? '0',
      discountPercentage: json['discount_percentage']?.toString() ?? '0',
      gstPercentage: json['gst_percentage']?.toString() ?? '0',
      isAvailable: json['is_available'] == true,
      paymentSchedule: json['payment_schedule'] is Map
          ? Map<String, dynamic>.from(json['payment_schedule'])
          : null,
      additionalCharges: json['additional_charges'] is Map
          ? Map<String, dynamic>.from(json['additional_charges'])
          : null,
    );
  }

  double get basePriceAsDouble =>
      double.tryParse(basePrice.replaceAll(',', '')) ?? 0.0;

  String get formattedBasePrice {
    final price = basePriceAsDouble;
    if (price <= 0) return 'Price on request';
    if (price >= 10000000) {
      return '₹${(price / 10000000).toStringAsFixed(2)} Cr';
    } else if (price >= 100000) {
      return '₹${(price / 100000).toStringAsFixed(2)} L';
    } else if (price >= 1000) {
      return '₹${(price / 1000).toStringAsFixed(1)} K';
    }
    return '₹${price.toStringAsFixed(0)}';
  }
}

// ============ Floor Model ============

class PropertyFloor {
  final int id;                          // ✅ ADDED
  final int floorNumber;                 // ✅ ADDED
  final String floorName;
  final int availableUnits;
  final int totalUnits;
  final String? expectedCompletionDate;  // ✅ ADDED

  PropertyFloor({
    required this.id,                    // ✅ ADDED
    required this.floorNumber,           // ✅ ADDED
    required this.floorName,
    required this.availableUnits,
    required this.totalUnits,
    this.expectedCompletionDate,         // ✅ ADDED
  });

  factory PropertyFloor.fromJson(Map<String, dynamic> json) {
    return PropertyFloor(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0, // ✅ ADDED
      floorNumber: json['floor_number'] is int
          ? json['floor_number']
          : int.tryParse(json['floor_number']?.toString() ?? '0') ?? 0, // ✅ ADDED
      floorName: json['floor_name']?.toString() ?? '',
      availableUnits: json['available_units'] is int
          ? json['available_units']
          : int.tryParse(json['available_units']?.toString() ?? '0') ?? 0,
      totalUnits: json['total_units'] is int
          ? json['total_units']
          : int.tryParse(json['total_units']?.toString() ?? '0') ?? 0,
      expectedCompletionDate: json['expected_completion_date']?.toString(), // ✅ ADDED
    );
  }
}

// ============ Property Builder Model ============   ✅ NEW CLASS

class PropertyBuilder {
  final int id;
  final String name;
  final String shortInfo;
  final String? logoS3Key;
  final String website;
  final String email;
  final String phone;
  final bool isActive;

  PropertyBuilder({
    required this.id,
    required this.name,
    required this.shortInfo,
    this.logoS3Key,
    required this.website,
    required this.email,
    required this.phone,
    required this.isActive,
  });

  factory PropertyBuilder.fromJson(Map<String, dynamic> json) {
    String? logo = json['logo_s3_key']?.toString();
    if (logo != null && logo.isNotEmpty && !logo.startsWith('http')) {
      logo = 'https://api.qnxmartb2b.com/$logo';
    }

    return PropertyBuilder(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      shortInfo: json['short_info']?.toString() ?? '',
      logoS3Key: logo,
      website: json['website']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }
}

// ============ Property Detail Model ============

class PropertyDetail {
  final int id;
  final String slug;
  final String title;                    // ✅ ADDED
  final String propertyType;
  final String transactionType;
  final String propertyCondition;        // ✅ ADDED
  final String status;                   // ✅ ADDED
  final bool statusApproved;             // ✅ ADDED
  final String city;
  final String area;
  final String address;
  final String landmark;                 // ✅ ADDED
  final String pincode;                  // ✅ ADDED
  final String latitude;                 // ✅ ADDED
  final String longitude;                // ✅ ADDED
  final String? googleLocationUrl;       // ✅ ADDED
  final String description;

  final List<PropertyImage> images;
  final List<PropertyVideo> videos;
  final List<Amenity> amenities;
  final List<FlatType> flatTypes;
  final List<PricingSlabDetail> pricingSlabs;
  final List<PropertyFloor> floors;
  final PropertyBuilder? builder;        // ✅ ADDED

  final String reraNumber;
  final String reraQrCode;
  final String? reraWebsite;             // ✅ ADDED
  final List<String> reraAdditionalUrls; // ✅ ADDED
  final String? propertyWebsiteUrl;      // ✅ ADDED
  final Map<String, dynamic> features;

  final String totalArea;
  final String plotArea;
  final String totalFloors;
  final String totalTowers;
  final String possessionDate;
  final String completionPercentage;

  final bool isUnderConstruction;
  final bool isVerified;
  final bool isFeatured;
  final bool isNegotiable;
  final String? referralCode;            // ✅ ADDED

  PropertyDetail({
    required this.id,
    required this.slug,
    required this.title,                 // ✅ ADDED
    required this.propertyType,
    required this.transactionType,
    required this.propertyCondition,     // ✅ ADDED
    required this.status,                // ✅ ADDED
    required this.statusApproved,        // ✅ ADDED
    required this.city,
    required this.area,
    required this.address,
    required this.landmark,              // ✅ ADDED
    required this.pincode,               // ✅ ADDED
    required this.latitude,              // ✅ ADDED
    required this.longitude,             // ✅ ADDED
    this.googleLocationUrl,              // ✅ ADDED
    required this.description,
    required this.images,
    required this.videos,
    required this.amenities,
    required this.flatTypes,
    required this.pricingSlabs,
    required this.floors,
    this.builder,                        // ✅ ADDED
    required this.reraNumber,
    required this.reraQrCode,
    this.reraWebsite,                    // ✅ ADDED
    required this.reraAdditionalUrls,    // ✅ ADDED
    this.propertyWebsiteUrl,             // ✅ ADDED
    required this.features,
    required this.totalArea,
    required this.plotArea,
    required this.totalFloors,
    required this.totalTowers,
    required this.possessionDate,
    required this.completionPercentage,
    required this.isUnderConstruction,
    required this.isVerified,
    required this.isFeatured,
    required this.isNegotiable,
    this.referralCode,                   // ✅ ADDED
  });

  factory PropertyDetail.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] as List? ?? [];
    final videosList = json['videos'] as List? ?? [];
    final amenityList = json['amenities'] as List? ?? [];
    final flatTypesList = json['flat_types'] as List? ?? [];
    final slabsList = json['pricing_slabs'] as List? ?? [];
    final floorsList = json['floors'] as List? ?? [];
    final reraUrlsList = json['rera_additional_urls'] as List? ?? [];

    String qr = json['rera_qr_code']?.toString() ?? '';
    if (qr.isNotEmpty && !qr.startsWith('http')) {
      qr = 'https://api.qnxmartb2b.com/$qr';
    }

    return PropertyDetail(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',                            // ✅ ADDED
      propertyType: json['property_type']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      propertyCondition: json['property_condition']?.toString() ?? '',   // ✅ ADDED
      status: json['status']?.toString() ?? '',                          // ✅ ADDED
      statusApproved: json['status_approved'] == true,                   // ✅ ADDED
      city: json['city']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',                      // ✅ ADDED
      pincode: json['pincode']?.toString() ?? '',                        // ✅ ADDED
      latitude: json['latitude']?.toString() ?? '',                      // ✅ ADDED
      longitude: json['longitude']?.toString() ?? '',                    // ✅ ADDED
      googleLocationUrl: json['google_location_url']?.toString(),        // ✅ ADDED
      description: json['description']?.toString() ?? '',
      images: imagesList.map((e) => PropertyImage.fromJson(e)).toList(),
      videos: videosList.map((e) => PropertyVideo.fromJson(e)).toList(),
      amenities: amenityList.map((e) => Amenity.fromJson(e)).toList(),
      flatTypes: flatTypesList.map((e) => FlatType.fromJson(e)).toList(),
      pricingSlabs:
      slabsList.map((e) => PricingSlabDetail.fromJson(e)).toList(),
      floors: floorsList.map((e) => PropertyFloor.fromJson(e)).toList(),
      builder: json['builder'] is Map                                // ✅ ADDED
          ? PropertyBuilder.fromJson(
          Map<String, dynamic>.from(json['builder']))
          : null,
      reraNumber: json['rera_number']?.toString() ?? '',
      reraQrCode: qr,
      reraWebsite: json['rera_website']?.toString(),                     // ✅ ADDED
      reraAdditionalUrls: reraUrlsList.map((e) => e.toString()).toList(), // ✅ ADDED
      propertyWebsiteUrl: json['property_website_url']?.toString(),      // ✅ ADDED
      features: json['features'] is Map
          ? Map<String, dynamic>.from(json['features'])
          : {},
      totalArea: json['total_area']?.toString() ?? '',
      plotArea: json['plot_area']?.toString() ?? '',
      totalFloors: json['total_floors']?.toString() ?? '',
      totalTowers: json['total_towers']?.toString() ?? '',
      possessionDate: json['possession_date']?.toString() ?? '',
      completionPercentage: json['completion_percentage']?.toString() ?? '',
      isUnderConstruction: json['is_under_construction'] == true,
      isVerified: json['is_verified'] == true,
      isFeatured: json['is_featured'] == true,
      isNegotiable: json['is_negotiable'] == true,
      referralCode: json['referral_code']?.toString(),                   // ✅ ADDED
    );
  }

  String get primaryImageUrl {
    if (images.isEmpty) return '';
    final primary = images.where((img) => img.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first.imageS3Key;
    return images.first.imageS3Key;
  }

  String get formattedPropertyType {
    if (propertyType.isEmpty) return '';
    return propertyType[0].toUpperCase() + propertyType.substring(1);
  }

  String get formattedTransactionType {
    if (transactionType.isEmpty) return '';
    final capped =
        transactionType[0].toUpperCase() + transactionType.substring(1);
    return 'For $capped';
  }

  double get minPrice {
    if (pricingSlabs.isEmpty) return 0;
    double minVal = pricingSlabs.first.basePriceAsDouble;
    for (final slab in pricingSlabs) {
      if (slab.basePriceAsDouble < minVal && slab.basePriceAsDouble > 0) {
        minVal = slab.basePriceAsDouble;
      }
    }
    return minVal;
  }

  String get formattedMinPrice {
    final price = minPrice;
    if (price <= 0) return 'Price on request';
    if (price >= 10000000) {
      return '₹${(price / 10000000).toStringAsFixed(2)} Cr';
    } else if (price >= 100000) {
      return '₹${(price / 100000).toStringAsFixed(2)} L';
    } else if (price >= 1000) {
      return '₹${(price / 1000).toStringAsFixed(1)} K';
    }
    return '₹${price.toStringAsFixed(0)}';
  }
}

// ============ Property Detail Response ============

class PropertyDetailResponse {
  final bool status;
  final String? message;
  final PropertyDetail? data;

  PropertyDetailResponse({
    required this.status,
    this.message,
    this.data,
  });

  factory PropertyDetailResponse.fromJson(Map<String, dynamic> json) {
    return PropertyDetailResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? PropertyDetail.fromJson(
          Map<String, dynamic>.from(json['data']))
          : null,
    );
  }

  bool get isSuccess => status && data != null;
}