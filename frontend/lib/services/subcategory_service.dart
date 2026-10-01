import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/subcategory_model.dart';
import '../utils/shared_preferences_helper.dart';

class SubCategoryService {
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
  // API 1: Get All Categories (for dropdown)
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
  // API 2: Get SubCategory List (by user)
  // ─────────────────────────────────────────────────────────
  static Future<SubCategoryListResponse> getSubCategoryList() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.subcategoryListUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return SubCategoryListResponse.fromJson(jsonData);
    } on SocketException {
      return SubCategoryListResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return SubCategoryListResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Create SubCategory
  // ─────────────────────────────────────────────────────────
  static Future<SubCategoryActionResponse> createSubCategory({
    required int category,
    required String name,
    required String description,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.subcategoryCreateUrl),
        headers: headers,
        body: jsonEncode({
          'category': category,
          'name': name,
          'description': description,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return SubCategoryActionResponse.fromJson(jsonData);
    } on SocketException {
      return SubCategoryActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return SubCategoryActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 4: Update SubCategory
  // ─────────────────────────────────────────────────────────
  static Future<SubCategoryActionResponse> updateSubCategory({
    required int id,
    required int category,
    required String name,
    required String description,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.subcategoryUpdateUrl),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'category': category,
          'name': name,
          'description': description,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return SubCategoryActionResponse.fromJson(jsonData);
    } on SocketException {
      return SubCategoryActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return SubCategoryActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 5: Soft Delete SubCategory
  // ─────────────────────────────────────────────────────────
  static Future<SubCategoryActionResponse> softDeleteSubCategory(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.subcategorySoftDeleteUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return SubCategoryActionResponse.fromJson(jsonData);
    } on SocketException {
      return SubCategoryActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return SubCategoryActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 6: Restore SubCategory
  // ─────────────────────────────────────────────────────────
  static Future<SubCategoryActionResponse> restoreSubCategory(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.subcategoryRestoreUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return SubCategoryActionResponse.fromJson(jsonData);
    } on SocketException {
      return SubCategoryActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return SubCategoryActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}
