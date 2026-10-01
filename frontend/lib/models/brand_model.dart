// ============ Category Name (for dropdown) ============

class CategoryName {
  final int id;
  final String name;

  CategoryName({required this.id, required this.name});

  factory CategoryName.fromJson(Map<String, dynamic> json) {
    return CategoryName(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

// ============ Sub Category Name (for dropdown) ============

class SubCategoryName {
  final int id;
  final String name;

  SubCategoryName({required this.id, required this.name});

  factory SubCategoryName.fromJson(Map<String, dynamic> json) {
    return SubCategoryName(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

// ============ Names List Response (generic for category & subcategory dropdowns) ============

class NamesListResponse<T> {
  final bool status;
  final String? message;
  final List<T> data;

  NamesListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  bool get isSuccess => status;
}

// Specialized responses (avoid generics complexity)
class CategoryNamesResponse {
  final bool status;
  final String? message;
  final List<CategoryName> data;

  CategoryNamesResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory CategoryNamesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return CategoryNamesResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => CategoryName.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
}

class SubCategoryNamesResponse {
  final bool status;
  final String? message;
  final List<SubCategoryName> data;

  SubCategoryNamesResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory SubCategoryNamesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return SubCategoryNamesResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => SubCategoryName.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
}

// ============ Brand Model ============

class Brand {
  final int id;
  final String name;
  final String description;
  final int categoryId;
  final String categoryName;
  final int subcategoryId;
  final String subcategoryName;
  final bool isActive;

  Brand({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.isActive,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      categoryName: json['category_name']?.toString() ?? '',
      subcategoryId: json['subcategory_id'] is int
          ? json['subcategory_id']
          : int.tryParse(json['subcategory_id']?.toString() ?? '0') ?? 0,
      subcategoryName: json['subcategory_name']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }
}

// ============ Brand List Response ============

class BrandListResponse {
  final bool status;
  final String? message;
  final List<Brand> data;

  BrandListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory BrandListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return BrandListResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => Brand.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
  bool get hasItems => data.isNotEmpty;
}

// ============ Action Response (create/update/delete/restore) ============

class BrandActionResponse {
  final bool status;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  BrandActionResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  factory BrandActionResponse.fromJson(Map<String, dynamic> json) {
    return BrandActionResponse(
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