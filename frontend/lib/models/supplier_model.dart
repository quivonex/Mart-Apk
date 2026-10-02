// lib/models/supplier_model.dart
//
// Matches backend/company/models.py -> suppliers
// Backend responses use { "msg": "...", "status": "success" | "error", "data": ... }

class Supplier {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String state;
  final String district;
  final String taluka;
  final String village;
  final int companyId;
  final String latitude;
  final String longitude;
  final String createdAt;

  Supplier({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.state,
    required this.district,
    required this.taluka,
    required this.village,
    required this.companyId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      taluka: json['taluka']?.toString() ?? '',
      village: json['village']?.toString() ?? '',
      companyId: _toInt(json['company']),
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  String get locationLine => [village, taluka, district, state]
      .where((s) => s.trim().isNotEmpty)
      .join(', ');
}

class SupplierListResponse {
  final bool status;
  final String? message;
  final List<Supplier> data;

  SupplierListResponse({required this.status, this.message, required this.data});

  factory SupplierListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] is List ? json['data'] as List : const [];
    return SupplierListResponse(
      status: json['status']?.toString() == 'success',
      message: json['msg']?.toString(),
      data: list
          .whereType<Map>()
          .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get isSuccess => status;
}

class SupplierActionResponse {
  final bool status;
  final String? message;

  /// On success: the supplier map. On validation error: field -> [errors].
  final Map<String, dynamic>? data;

  SupplierActionResponse({required this.status, this.message, this.data});

  factory SupplierActionResponse.fromJson(Map<String, dynamic> json) {
    return SupplierActionResponse(
      status: json['status']?.toString() == 'success',
      message: json['msg']?.toString(),
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
    );
  }

  bool get isSuccess => status;

  String get displayMessage {
    if (isSuccess) return message ?? 'Done';
    final d = data;
    if (d != null && d.isNotEmpty) {
      final key = d.keys.first;
      final err = d[key];
      final text = err is List && err.isNotEmpty ? err.first.toString() : err.toString();
      return '${_label(key)}: $text';
    }
    return message ?? 'Something went wrong';
  }

  static String _label(String key) =>
      key.isEmpty ? key : key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ');
}