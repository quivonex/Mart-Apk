// lib/models/company_locations_models.dart
//
// Backend (state app) responses look like:
//   { "status": "success", "msg": "Districts found.", "data": [ {id, district_name, ...} ] }
//   { "status": "error",   "msg": "State not found or inactive." }
//
// FIX: the old code checked json['status'] == true, but the backend sends the
// STRING "success", so status was always false and the dropdowns stayed empty.

class LocationItem {
  final int id;
  final String name;

  LocationItem({required this.id, required this.name});

  factory LocationItem.fromJson(Map<String, dynamic> json, String nameKey) {
    return LocationItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: (json[nameKey] ?? json['name'] ?? '').toString().trim(),
    );
  }

  @override
  bool operator ==(Object other) => other is LocationItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class LocationResponse {
  final bool status;
  final String? message;
  final List<LocationItem> data;

  LocationResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory LocationResponse.fromJson(Map<String, dynamic> json, String nameKey) {
    final raw = json['status'];
    final ok = raw == true || raw?.toString().toLowerCase() == 'success';

    final list = json['data'] is List ? json['data'] as List : const [];
    final items = list
        .whereType<Map>()
        .map((e) => LocationItem.fromJson(Map<String, dynamic>.from(e), nameKey))
        .where((e) => e.id != 0 && e.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return LocationResponse(
      status: ok,
      message: (json['msg'] ?? json['message'])?.toString(),
      data: items,
    );
  }

  bool get isSuccess => status;
}