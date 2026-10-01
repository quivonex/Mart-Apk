// ============ Unit Model ============

class Unit {
  final int id;
  final String name;
  final String shortName;
  final bool isActive;

  Unit({
    required this.id,
    required this.name,
    required this.shortName,
    required this.isActive,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  /// Display label like "Kilogram (kg)"
  String get displayName {
    if (shortName.isNotEmpty) return '$name ($shortName)';
    return name;
  }
}

// ============ Unit List Response ============

class UnitListResponse {
  final bool status;
  final String? message;
  final List<Unit> data;

  UnitListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory UnitListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return UnitListResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => Unit.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
  bool get hasItems => data.isNotEmpty;
}

// ============ Action Response (create/update/delete/restore) ============

class UnitActionResponse {
  final bool status;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  UnitActionResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  factory UnitActionResponse.fromJson(Map<String, dynamic> json) {
    return UnitActionResponse(
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