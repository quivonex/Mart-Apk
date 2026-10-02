// lib/models/catalog_models.dart
//
// Models for the product catalog masters used by the product create form:
//   Branch      (branch app)    - belongs to a company
//   Category    (product app)   - belongs to a company (optionally a branch)
//   SubCategory (product app)   - belongs to a category
//   Unit        (product app)   - belongs to the user (or global when user = null)
//   Brand       (product app)   - belongs to a subcategory

int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
int? _intOrNull(dynamic v) {
  if (v == null) return null;
  final i = v is int ? v : int.tryParse(v.toString());
  return (i == null || i == 0) ? null : i;
}

String _str(dynamic v) => v?.toString() ?? '';
bool _bool(dynamic v, {bool fallback = true}) =>
    v == null ? fallback : (v == true || v.toString().toLowerCase() == 'true');

// ---------------------------------------------------------------------------
// Anything that can be shown in a picker
// ---------------------------------------------------------------------------
abstract class CatalogOption {
  int get id;
  String get label;
  String get sublabel; // every implementer must provide it (use '' if none)
  bool get isActive;
}

// ---------------------------------------------------------------------------
class CatalogBranch implements CatalogOption {
  @override
  final int id;
  final int companyId;
  final String name;
  final String phone;
  final String email;
  final String address;
  @override
  final bool isActive;

  CatalogBranch({
    required this.id,
    required this.companyId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.isActive = true,
  });

  factory CatalogBranch.fromJson(Map<String, dynamic> j) => CatalogBranch(
    id: _int(j['id']),
    companyId: _int(j['company']),
    name: _str(j['name']),
    phone: _str(j['phone_number']),
    email: _str(j['email']),
    address: _str(j['address']),
    isActive: _bool(j['is_active']),
  );

  @override
  String get label => name;
  @override
  String get sublabel => [phone, address].where((s) => s.trim().isNotEmpty).join(' · ');
}

// ---------------------------------------------------------------------------
class CatalogCategory implements CatalogOption {
  @override
  final int id;
  final int? companyId;
  final int? branchId;
  final String branchName;
  final String name;
  final String description;
  @override
  final bool isActive;

  CatalogCategory({
    required this.id,
    required this.name,
    this.companyId,
    this.branchId,
    this.branchName = '',
    this.description = '',
    this.isActive = true,
  });

  factory CatalogCategory.fromJson(Map<String, dynamic> j) => CatalogCategory(
    id: _int(j['id']),
    companyId: _intOrNull(j['company']),
    branchId: _intOrNull(j['branch']),
    branchName: _str(j['branch_name']),
    name: _str(j['name']),
    description: _str(j['description']),
    isActive: _bool(j['is_active']),
  );

  @override
  String get label => name;
  @override
  String get sublabel => branchName.isNotEmpty ? 'Branch: $branchName' : description;
}

// ---------------------------------------------------------------------------
class CatalogSubCategory implements CatalogOption {
  @override
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final String description;
  @override
  final bool isActive;

  CatalogSubCategory({
    required this.id,
    required this.categoryId,
    required this.name,
    this.categoryName = '',
    this.description = '',
    this.isActive = true,
  });

  factory CatalogSubCategory.fromJson(Map<String, dynamic> j) => CatalogSubCategory(
    id: _int(j['id']),
    categoryId: _int(j['category'] ?? j['category_id']),
    categoryName: _str(j['category_name']),
    name: _str(j['name']),
    description: _str(j['description']),
    isActive: _bool(j['is_active']),
  );

  @override
  String get label => name;
  @override
  String get sublabel => description;
}

// ---------------------------------------------------------------------------
class CatalogUnit implements CatalogOption {
  @override
  final int id;
  final String name;
  final String shortName;
  final int? userId; // null = global unit created by admin
  @override
  final bool isActive;

  CatalogUnit({
    required this.id,
    required this.name,
    required this.shortName,
    this.userId,
    this.isActive = true,
  });

  factory CatalogUnit.fromJson(Map<String, dynamic> j) => CatalogUnit(
    id: _int(j['id']),
    name: _str(j['name']),
    shortName: _str(j['short_name']),
    userId: _intOrNull(j['user']),
    isActive: _bool(j['is_active']),
  );

  bool get isGlobal => userId == null;

  @override
  String get label => shortName.isEmpty ? name : '$name ($shortName)';
  @override
  String get sublabel => isGlobal ? 'Standard unit' : '';
}

// ---------------------------------------------------------------------------
class CatalogBrand implements CatalogOption {
  @override
  final int id;
  final String name;
  final int? subcategoryId;
  @override
  final bool isActive;

  CatalogBrand({
    required this.id,
    required this.name,
    this.subcategoryId,
    this.isActive = true,
  });

  factory CatalogBrand.fromJson(Map<String, dynamic> j) => CatalogBrand(
    id: _int(j['id']),
    name: _str(j['name']),
    subcategoryId: _intOrNull(j['subcategory_id'] ?? j['subcategory']),
    isActive: _bool(j['is_active']),
  );

  @override
  String get label => name;
  @override
  String get sublabel => '';
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------
class CatalogListResult<T> {
  final bool ok;
  final String? message;
  final List<T> items;

  CatalogListResult({required this.ok, this.message, this.items = const []});
}

class CatalogResult<T> {
  final bool ok;
  final String message;
  final T? data;

  CatalogResult({required this.ok, required this.message, this.data});
}

/// Turns any backend error shape into one readable line:
///   {"errors": {"name": ["This field is required."]}}
///   {"name": ["This field is required."]}          (branch create)
///   {"message": "..."} / {"msg": "..."} / {"error": "..."}
String catalogErrorText(Map<String, dynamic> json, {String fallback = 'Request failed'}) {
  Map<String, dynamic>? errors;
  if (json['errors'] is Map) {
    errors = Map<String, dynamic>.from(json['errors']);
  } else {
    final fieldErrors = Map<String, dynamic>.from(json)
      ..removeWhere((k, v) => const {'status', 'message', 'msg', 'data', 'error'}.contains(k));
    if (fieldErrors.isNotEmpty && fieldErrors.values.every((v) => v is List)) {
      errors = fieldErrors;
    }
  }

  if (errors != null && errors.isNotEmpty) {
    final key = errors.keys.first;
    final val = errors[key];
    final text = val is List && val.isNotEmpty ? val.first.toString() : val.toString();
    if (key == 'non_field_errors' || key == 'detail') return text;
    final label = key.replaceAll('_', ' ');
    return '${label[0].toUpperCase()}${label.substring(1)}: $text';
  }

  return (json['message'] ?? json['msg'] ?? json['error'] ?? json['detail'] ?? fallback)
      .toString();
}