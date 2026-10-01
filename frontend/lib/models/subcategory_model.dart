// ============ Category (for dropdown) ============

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

// ============ Category Names Response ============

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

// ============ Sub Category ============

class SubCategory {
  final int id;
  final int category;
  final int categoryId;
  final String categoryName;
  final String name;
  final String description;
  final bool isActive;

  SubCategory({
    required this.id,
    required this.category,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.isActive,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] is int
        ? json['category']
        : int.tryParse(json['category']?.toString() ?? '0') ?? 0;
    final catId = json['category_id'] is int
        ? json['category_id']
        : int.tryParse(json['category_id']?.toString() ?? '0') ?? 0;

    return SubCategory(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      category: cat,
      categoryId: catId > 0 ? catId : cat,
      categoryName: json['category_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  /// Get the effective category id (whichever is non-zero)
  int get effectiveCategoryId => category > 0 ? category : categoryId;
}

// ============ Sub Category List Response ============

class SubCategoryListResponse {
  final bool status;
  final String? message;
  final List<SubCategory> data;

  SubCategoryListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory SubCategoryListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return SubCategoryListResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => SubCategory.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
  bool get hasItems => data.isNotEmpty;
}

// ============ Action Response (create/update/delete/restore) ============

class SubCategoryActionResponse {
  final bool status;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  SubCategoryActionResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  factory SubCategoryActionResponse.fromJson(Map<String, dynamic> json) {
    return SubCategoryActionResponse(
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