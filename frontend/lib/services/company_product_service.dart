import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/company_product_model.dart';
import '../utils/shared_preferences_helper.dart';

class CompanyProductService {
  static Future<Map<String, String>> _jsonHeaders() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _authOnlyHeaders() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  // ─────────────────────────────────────────────────────────
  // API 1: Get Products by Company
  // ─────────────────────────────────────────────────────────
  static Future<CompanyProductsListResponse> getCompanyProducts({
    int? companyId,
  }) async {
    try {
      final headers = await _jsonHeaders();
      final body = <String, dynamic>{};
      if (companyId != null) body['company_id'] = companyId;

      final response = await http
          .post(
        Uri.parse(ApiUrls.companyProductsListUrl),
        headers: headers,
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyProductsListResponse(
          status: false,
          message: 'Invalid response from server',
          data: [],
        );
      }

      if (response.statusCode == 200) {
        return CompanyProductsListResponse.fromJson(jsonData);
      }
      return CompanyProductsListResponse(
        status: false,
        message: jsonData['message']?.toString() ??
            'Failed to load products',
        data: [],
      );
    } on SocketException {
      return CompanyProductsListResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return CompanyProductsListResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 2: Create Product (multipart/form-data)
  // ─────────────────────────────────────────────────────────
  static Future<CompanyProductActionResponse> createProduct({
    required Map<String, String> fields,
    required File thumbnail,
    List<File> images = const [],
    List<File> videos = const [],
    Map<String, File> variantImages = const {}, // e.g. {'variant_image_0': file}
  }) async {
    try {
      final headers = await _authOnlyHeaders();
      final uri = Uri.parse(ApiUrls.companyProductCreateUrl);

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);

      request.fields.addAll(fields);

      // Thumbnail
      request.files.add(await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnail.path,
      ));

      // Images
      for (final img in images) {
        request.files.add(
          await http.MultipartFile.fromPath('images', img.path),
        );
      }

      // Videos
      for (final vid in videos) {
        request.files.add(
          await http.MultipartFile.fromPath('videos', vid.path),
        );
      }

      // Variant images
      for (final entry in variantImages.entries) {
        request.files.add(await http.MultipartFile.fromPath(
          entry.key,
          entry.value.path,
        ));
      }

      final streamed =
      await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyProductActionResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      return CompanyProductActionResponse.fromJson(jsonData);
    } on SocketException {
      return CompanyProductActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return CompanyProductActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Update Product (multipart/form-data)
  // ─────────────────────────────────────────────────────────
  static Future<CompanyProductActionResponse> updateProduct({
    required int productId,
    required Map<String, String> fields,
    File? thumbnail,
    List<File> images = const [],
    List<int> deleteImageIds = const [],
    List<File> videos = const [],
    List<int> deleteVideoIds = const [],
    Map<String, File> variantImages = const {},
  }) async {
    try {
      final headers = await _authOnlyHeaders();
      final uri = Uri.parse(ApiUrls.companyProductUpdateUrl);

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);

      request.fields['product_id'] = productId.toString();
      request.fields.addAll(fields);

      // ✅ FIXED: JSON-encode arrays instead of overwriting
      if (deleteImageIds.isNotEmpty) {
        request.fields['delete_images'] = jsonEncode(deleteImageIds);
      }

      if (deleteVideoIds.isNotEmpty) {
        request.fields['delete_videos'] = jsonEncode(deleteVideoIds);
      }

      if (thumbnail != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'thumbnail',
          thumbnail.path,
        ));
      }

      for (final img in images) {
        request.files.add(
          await http.MultipartFile.fromPath('images', img.path),
        );
      }

      for (final vid in videos) {
        request.files.add(
          await http.MultipartFile.fromPath('videos', vid.path),
        );
      }

      for (final entry in variantImages.entries) {
        request.files.add(await http.MultipartFile.fromPath(
          entry.key,
          entry.value.path,
        ));
      }

      final streamed =
      await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyProductActionResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      return CompanyProductActionResponse.fromJson(jsonData);
    } on SocketException {
      return CompanyProductActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return CompanyProductActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}