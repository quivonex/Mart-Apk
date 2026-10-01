// lib/models/location_models.dart

class LocationItem {
  final int id;
  final String name;

  LocationItem({required this.id, required this.name});

  factory LocationItem.fromJson(Map<String, dynamic> json, String nameKey) {
    return LocationItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json[nameKey]?.toString() ?? '',
    );
  }
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
    final list = json['data'] as List? ?? [];
    return LocationResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => LocationItem.fromJson(e, nameKey)).toList(),
    );
  }
}