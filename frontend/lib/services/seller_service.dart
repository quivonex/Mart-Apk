import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/seller_model.dart';
import '../utils/shared_preferences_helper.dart';

class SellerService {
  /// Build common headers with Authorization
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
  // API 1: Get Seller List / Profile
  // ─────────────────────────────────────────────────────────
  static Future<SellerListResponse> getSellerList() async {
    try {
      final Uri url = Uri.parse(ApiUrls.sellerListUrl);
      final headers = await _headers();

      final http.Response response = await http
          .post(url, headers: headers, body: jsonEncode({}))
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return SellerListResponse(
          status: 'error',
          message: 'Invalid response from server',
          data: [],
        );
      }

      if (response.statusCode == 200) {
        return SellerListResponse.fromJson(jsonData);
      }

      return SellerListResponse(
        status: 'error',
        message: jsonData['message']?.toString() ??
            'Failed to load seller profile',
        data: [],
      );
    } on SocketException {
      return SellerListResponse(
        status: 'error',
        message: 'No internet connection. Please check your network.',
        data: [],
      );
    } on HttpException {
      return SellerListResponse(
        status: 'error',
        message: 'Server error. Please try again later.',
        data: [],
      );
    } catch (e) {
      return SellerListResponse(
        status: 'error',
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 2: Register Seller
  // ─────────────────────────────────────────────────────────
  static Future<SellerActionResponse> createSeller(
      SellerRequest request,
      ) async {
    try {
      final Uri url = Uri.parse(ApiUrls.sellerCreateUrl);
      final headers = await _headers();

      final http.Response response = await http
          .post(
        url,
        headers: headers,
        body: jsonEncode(request.toCreateJson()),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return SellerActionResponse(
          status: 'error',
          message: 'Invalid response from server',
        );
      }

      return SellerActionResponse.fromJson(jsonData);
    } on SocketException {
      return SellerActionResponse(
        status: 'error',
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return SellerActionResponse(
        status: 'error',
        message: 'Server error. Please try again later.',
      );
    } catch (e) {
      return SellerActionResponse(
        status: 'error',
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Update Seller
  // ─────────────────────────────────────────────────────────
  static Future<SellerActionResponse> updateSeller(
      SellerRequest request,
      ) async {
    try {
      final Uri url = Uri.parse(ApiUrls.sellerUpdateUrl);
      final headers = await _headers();

      final http.Response response = await http
          .post(
        url,
        headers: headers,
        body: jsonEncode(request.toUpdateJson()),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return SellerActionResponse(
          status: 'error',
          message: 'Invalid response from server',
        );
      }

      return SellerActionResponse.fromJson(jsonData);
    } on SocketException {
      return SellerActionResponse(
        status: 'error',
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return SellerActionResponse(
        status: 'error',
        message: 'Server error. Please try again later.',
      );
    } catch (e) {
      return SellerActionResponse(
        status: 'error',
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}