import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_urls.dart';
import '../models/brand_model.dart';
import '../utils/shared_preferences_helper.dart';

class BrandService {
  static Future<Map<String, String>> _headers() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  // ─────────────────────────────────────────────────────────
  // API 1: Get Category Names (dropdown)
  // ─────────────────────────────────────────────────────────
  static Future<CategoryNamesResponse> getCategoryNames() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.categoryAllUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return CategoryNamesResponse.fromJson(jsonData);
    } on SocketException {
      return CategoryNamesResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return CategoryNamesResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 2: Get Sub Categories by Category (dropdown)
  // ─────────────────────────────────────────────────────────
  static Future<SubCategoryNamesResponse> getSubCategoriesByCategory(
      int categoryId,
      ) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.subcategoryByCategoryUrl),
        headers: headers,
        body: jsonEncode({'category': categoryId}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return SubCategoryNamesResponse.fromJson(jsonData);
    } on SocketException {
      return SubCategoryNamesResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return SubCategoryNamesResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Get Brand List
  // ─────────────────────────────────────────────────────────
  static Future<BrandListResponse> getBrandList() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.brandListUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BrandListResponse.fromJson(jsonData);
    } on SocketException {
      return BrandListResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return BrandListResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 4: Create Brand
  // ─────────────────────────────────────────────────────────
  static Future<BrandActionResponse> createBrand({
    required String name,
    required String description,
    required int category,
    required int subcategory,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.brandCreateUrl),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'description': description,
          'category': category,
          'subcategory': subcategory,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BrandActionResponse.fromJson(jsonData);
    } on SocketException {
      return BrandActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BrandActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 5: Update Brand
  // ─────────────────────────────────────────────────────────
  static Future<BrandActionResponse> updateBrand({
    required int id,
    required String name,
    required String description,
    required int category,
    required int subcategory,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.brandUpdateUrl),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'name': name,
          'description': description,
          'category': category,
          'subcategory': subcategory,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BrandActionResponse.fromJson(jsonData);
    } on SocketException {
      return BrandActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BrandActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 6: Soft Delete
  // ─────────────────────────────────────────────────────────
  static Future<BrandActionResponse> softDeleteBrand(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.brandSoftDeleteUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BrandActionResponse.fromJson(jsonData);
    } on SocketException {
      return BrandActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BrandActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 7: Restore
  // ─────────────────────────────────────────────────────────
  static Future<BrandActionResponse> restoreBrand(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.brandRestoreUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BrandActionResponse.fromJson(jsonData);
    } on SocketException {
      return BrandActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BrandActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}