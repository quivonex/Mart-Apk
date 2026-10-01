import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/company_model.dart';
import '../utils/shared_preferences_helper.dart';

class CompanyService {
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
  // API 1: Get My Companies
  // ─────────────────────────────────────────────────────────
  static Future<CompanyListResponse> getMyCompanies() async {
    try {
      final headers = await _jsonHeaders();
      final response = await http
          .post(
        Uri.parse(ApiUrls.companyListUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyListResponse(
          status: false,
          message: 'Invalid response from server',
          data: [],
        );
      }

      if (response.statusCode == 200) {
        return CompanyListResponse.fromJson(jsonData);
      }
      return CompanyListResponse(
        status: false,
        message: jsonData['message']?.toString() ??
            'Failed to load companies',
        data: [],
      );
    } on SocketException {
      return CompanyListResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return CompanyListResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 2: Create Company (multipart/form-data)
  // ─────────────────────────────────────────────────────────
  static Future<CompanyActionResponse> createCompany({
    required Map<String, String> fields,
    required File logo,
    List<File> images = const [],
  }) async {
    try {
      final headers = await _authOnlyHeaders();
      final uri = Uri.parse(ApiUrls.companyCreateUrl);

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);

      // Add all text fields
      request.fields.addAll(fields);

      // Add logo
      request.files.add(await http.MultipartFile.fromPath(
        'logo',
        logo.path,
      ));

      // Add images (up to 5)
      for (final img in images) {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          img.path,
        ));
      }

      final streamedResponse =
      await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyActionResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      return CompanyActionResponse.fromJson(jsonData);
    } on SocketException {
      return CompanyActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return CompanyActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Update Company (multipart/form-data)
  // ─────────────────────────────────────────────────────────
  static Future<CompanyActionResponse> updateCompany({
    required int id,
    required Map<String, String> fields,
    File? logo,
    List<File> images = const [],
    List<int> deleteImageIds = const [],
  }) async {
    try {
      final headers = await _authOnlyHeaders();
      final uri = Uri.parse(ApiUrls.companyUpdateUrl);

      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);

      // Add id first
      request.fields['id'] = id.toString();
      request.fields.addAll(fields);

      // delete_image_ids
      if (deleteImageIds.isNotEmpty) {
        request.fields['delete_image_ids'] =
            jsonEncode(deleteImageIds);
      }

      // Optional logo
      if (logo != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'logo',
          logo.path,
        ));
      }

      // Optional new images
      for (final img in images) {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          img.path,
        ));
      }

      final streamedResponse =
      await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyActionResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      return CompanyActionResponse.fromJson(jsonData);
    } on SocketException {
      return CompanyActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return CompanyActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 4: Create Payment Order (Razorpay)
  // ─────────────────────────────────────────────────────────
  static Future<CompanyPaymentOrderResponse> createPaymentOrder(
      int companyId,
      ) async {
    try {
      final headers = await _jsonHeaders();
      final response = await http
          .post(
        Uri.parse(ApiUrls.companyPaymentOrderUrl),
        headers: headers,
        body: jsonEncode({'company_id': companyId}),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyPaymentOrderResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      return CompanyPaymentOrderResponse.fromJson(jsonData);
    } on SocketException {
      return CompanyPaymentOrderResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return CompanyPaymentOrderResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 5: Verify Payment
  // ─────────────────────────────────────────────────────────
  static Future<CompanyPaymentVerifyResponse> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int companyId,
  }) async {
    try {
      final headers = await _jsonHeaders();
      final response = await http
          .post(
        Uri.parse(ApiUrls.companyVerifyPaymentUrl),
        headers: headers,
        body: jsonEncode({
          'payment_id': paymentId,
          'order_id': orderId,
          'signature': signature,
          'company_id': companyId,
        }),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CompanyPaymentVerifyResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      return CompanyPaymentVerifyResponse.fromJson(jsonData);
    } on SocketException {
      return CompanyPaymentVerifyResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return CompanyPaymentVerifyResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}