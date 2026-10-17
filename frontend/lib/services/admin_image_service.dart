// lib/services/admin_image_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/admin_image_model.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

class AdminImageService {
  static const _timeout = Duration(seconds: 25);

  /// POST /admin_profile/upload_image_list/
  /// Returns all banner images uploaded by the admin.
  static Future<AdminImageListResponse> getUploadedImages() async {
    try {
      final token = await SharedPreferencesHelper.getAccessToken();
      final res = await http
          .post(
        Uri.parse('${ApiUrls.baseUrl}/admin_profile/upload_image_list/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      )
          .timeout(_timeout);

      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}

      if (json == null) {
        return AdminImageListResponse(
          status: false,
          count: 0,
          data: const [],
        );
      }
      return AdminImageListResponse.fromJson(json);
    } on SocketException {
      return AdminImageListResponse(
          status: false, count: 0, data: const []);
    } on TimeoutException {
      return AdminImageListResponse(
          status: false, count: 0, data: const []);
    } catch (_) {
      return AdminImageListResponse(
          status: false, count: 0, data: const []);
    }
  }
}