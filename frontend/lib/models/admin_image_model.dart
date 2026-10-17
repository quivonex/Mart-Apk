// lib/models/admin_image_model.dart
//
// Response from POST admin_profile/upload_image_list/
// {
//   "status": "success",
//   "count": 4,
//   "data": [
//     { "id": 12, "image_url": "https://...jpeg", "title": "banner",
//       "created_at": "2026-08-08T08:31:24.755632Z" },
//     ...
//   ]
// }

class AdminImage {
  final int id;
  final String imageUrl;
  final String title;
  final String createdAt;

  AdminImage({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.createdAt,
  });

  factory AdminImage.fromJson(Map<String, dynamic> json) {
    return AdminImage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      imageUrl: json['image_url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class AdminImageListResponse {
  final bool status;
  final int count;
  final List<AdminImage> data;

  AdminImageListResponse({
    required this.status,
    required this.count,
    required this.data,
  });

  factory AdminImageListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['status'];
    final ok = raw == true ||
        raw?.toString().toLowerCase() == 'success';

    final list = json['data'] is List ? json['data'] as List : const [];
    final items = list
        .whereType<Map>()
        .map((e) => AdminImage.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.imageUrl.startsWith('http'))
        .toList();

    return AdminImageListResponse(
      status: ok,
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '${items.length}') ??
          items.length,
      data: items,
    );
  }

  bool get isSuccess => status;
  bool get hasImages => data.isNotEmpty;
}