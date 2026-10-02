// lib/services/company_service.dart
//
// FULL REPLACEMENT. Existing methods keep the same signatures:
//   getMyCompanies, createCompany, updateCompany, createPaymentOrder, verifyPayment
// New methods:
//   getCompanyDetail, softDeleteCompany, restoreCompany, getStock, getLowStock
//
// WEB + ANDROID: images are passed as XFile (from image_picker) and uploaded as
// bytes, because dart:io File does not work on Flutter Web.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'api_urls.dart';
import '../models/company_model.dart';
import '../models/company_stock_model.dart';
import '../utils/shared_preferences_helper.dart';

class CompanyService {
  static const _timeout = Duration(seconds: 30);
  static const _uploadTimeout = Duration(seconds: 90);

  static Future<Map<String, String>> _jsonHeaders() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _authOnlyHeaders() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Builds a multipart image part from an XFile (works on web and mobile).
  /// Backend upload_file_to_s3() needs a filename WITH extension and a
  /// correct content_type, so both are always set.
  static Future<http.MultipartFile> _imagePart(String field, XFile x) async {
    final bytes = await x.readAsBytes();
    var name = x.name.isNotEmpty ? x.name : x.path.split('/').last;
    final mime = (x.mimeType != null && x.mimeType!.startsWith('image/'))
        ? x.mimeType!
        : _mimeFromName(name);
    if (!name.contains('.')) name = '$name.${_extFromMime(mime)}';
    return http.MultipartFile.fromBytes(
      field,
      bytes,
      filename: name,
      contentType: MediaType.parse(mime),
    );
  }

  static String _mimeFromName(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  static String _extFromMime(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }

  /// POSTs JSON and returns (statusCode, decoded map). Throws on network errors.
  static Future<(int, Map<String, dynamic>)> _postJson(
      String url,
      Map<String, dynamic> body,
      ) async {
    final res = await http
        .post(Uri.parse(url), headers: await _jsonHeaders(), body: jsonEncode(body))
        .timeout(_timeout);
    return (res.statusCode, _decode(res.body, res.statusCode));
  }

  static Map<String, dynamic> _decode(String body, int code) {
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) return d;
      return {'status': false, 'message': 'Unexpected response'};
    } catch (_) {
      if (code == 401) {
        return {'status': false, 'message': 'Session expired. Please log in again.'};
      }
      return {'status': false, 'message': 'Invalid response from server ($code)'};
    }
  }

  static String _err(Object e) {
    if (e is SocketException) return 'No internet connection.';
    if (e is HttpException) return 'Could not reach the server.';
    if (e is http.ClientException) {
      return 'Could not reach the server. Check the base URL and that Django is running.';
    }
    if (e.toString().contains('TimeoutException')) {
      return 'The server took too long to respond. Try again.';
    }
    return 'Something went wrong: $e';
  }

  // ─────────────────────────────────────────────────────────
  // 1. My companies          POST /company/company/list/
  // ─────────────────────────────────────────────────────────
  static Future<CompanyListResponse> getMyCompanies() async {
    try {
      final (code, json) = await _postJson(ApiUrls.companyListUrl, {});
      if (code == 200) return CompanyListResponse.fromJson(json);
      return CompanyListResponse(
        status: false,
        message: json['message']?.toString() ?? 'Failed to load companies',
        data: [],
      );
    } catch (e) {
      return CompanyListResponse(status: false, message: _err(e), data: []);
    }
  }

  // ─────────────────────────────────────────────────────────
  // 2. Single company        POST /company/company/single-retrieve/
  // ─────────────────────────────────────────────────────────
  static Future<CompanyDetailResponse> getCompanyDetail(int companyId) async {
    try {
      final (_, json) =
      await _postJson(ApiUrls.companyDetailUrl, {'company_id': companyId});
      return CompanyDetailResponse.fromJson(json);
    } catch (e) {
      return CompanyDetailResponse(status: false, message: _err(e));
    }
  }

  // ─────────────────────────────────────────────────────────
  // 3. Create company (multipart)   POST /company/company/create/
  // ─────────────────────────────────────────────────────────
  static Future<CompanyActionResponse> createCompany({
    required Map<String, String> fields,
    required XFile logo,
    List<XFile> images = const [],
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(ApiUrls.companyCreateUrl))
        ..headers.addAll(await _authOnlyHeaders())
        ..fields.addAll(fields);

      request.files.add(await _imagePart('logo', logo));
      for (final img in images) {
        request.files.add(await _imagePart('images', img));
      }

      final streamed = await request.send().timeout(_uploadTimeout);
      final res = await http.Response.fromStream(streamed);
      return CompanyActionResponse.fromJson(_decode(res.body, res.statusCode));
    } catch (e) {
      return CompanyActionResponse(status: false, message: _err(e));
    }
  }

  // ─────────────────────────────────────────────────────────
  // 4. Update company (multipart)   POST /company/company/update/
  //    Also used by the photo manager: send only images/deleteImageIds.
  // ─────────────────────────────────────────────────────────
  static Future<CompanyActionResponse> updateCompany({
    required int id,
    required Map<String, String> fields,
    XFile? logo,
    List<XFile> images = const [],
    List<int> deleteImageIds = const [],
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(ApiUrls.companyUpdateUrl))
        ..headers.addAll(await _authOnlyHeaders())
        ..fields['id'] = id.toString()
        ..fields.addAll(fields);

      if (deleteImageIds.isNotEmpty) {
        request.fields['delete_image_ids'] = jsonEncode(deleteImageIds);
      }
      if (logo != null) {
        request.files.add(await _imagePart('logo', logo));
      }
      for (final img in images) {
        request.files.add(await _imagePart('images', img));
      }

      final streamed = await request.send().timeout(_uploadTimeout);
      final res = await http.Response.fromStream(streamed);
      return CompanyActionResponse.fromJson(_decode(res.body, res.statusCode));
    } catch (e) {
      return CompanyActionResponse(status: false, message: _err(e));
    }
  }

  // ─────────────────────────────────────────────────────────
  // 5. Razorpay order        POST /company/create-company-payment-order/
  // ─────────────────────────────────────────────────────────
  static Future<CompanyPaymentOrderResponse> createPaymentOrder(int companyId) async {
    try {
      final (_, json) =
      await _postJson(ApiUrls.companyPaymentOrderUrl, {'company_id': companyId});
      return CompanyPaymentOrderResponse.fromJson(json);
    } catch (e) {
      return CompanyPaymentOrderResponse(status: false, message: _err(e));
    }
  }

  // ─────────────────────────────────────────────────────────
  // 6. Verify payment        POST /company/verify-payment/
  // ─────────────────────────────────────────────────────────
  static Future<CompanyPaymentVerifyResponse> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int companyId,
  }) async {
    try {
      final (_, json) = await _postJson(ApiUrls.companyVerifyPaymentUrl, {
        'payment_id': paymentId,
        'order_id': orderId,
        'signature': signature,
        'company_id': companyId,
      });
      return CompanyPaymentVerifyResponse.fromJson(json);
    } catch (e) {
      return CompanyPaymentVerifyResponse(status: false, message: _err(e));
    }
  }

  // ─────────────────────────────────────────────────────────
  // 7. Deactivate / restore  POST /company/company/soft-delete/  /restore/
  //    Backend returns {"message": ...} or {"error": ...} (no "status" key)
  // ─────────────────────────────────────────────────────────
  static Future<CompanySimpleResponse> softDeleteCompany(int companyId) =>
      _simple(ApiUrls.companySoftDeleteUrl, companyId);

  static Future<CompanySimpleResponse> restoreCompany(int companyId) =>
      _simple(ApiUrls.companyRestoreUrl, companyId);

  static Future<CompanySimpleResponse> _simple(String url, int companyId) async {
    try {
      final (code, json) = await _postJson(url, {'company_id': companyId});
      final ok = code >= 200 && code < 300 && json['error'] == null;
      return CompanySimpleResponse(
        status: ok,
        message: (ok ? json['message'] : (json['error'] ?? json['message']))
            ?.toString() ??
            (ok ? 'Done' : 'Request failed'),
      );
    } catch (e) {
      return CompanySimpleResponse(status: false, message: _err(e));
    }
  }

  // ─────────────────────────────────────────────────────────
  // 8. Stock                 POST /company/company/stock/
  // 9. Low stock (<= 10)     POST /company/company/low-stock/
  //    company_id is sent for the backend fix in the README; the current
  //    backend ignores it and uses the user's first company.
  // ─────────────────────────────────────────────────────────
  static Future<CompanyStockResponse> getStock({int? companyId}) async {
    try {
      final (_, json) = await _postJson(
          ApiUrls.companyStockUrl, {if (companyId != null) 'company_id': companyId});
      return CompanyStockResponse.fromJson(json);
    } catch (e) {
      return CompanyStockResponse(status: false, message: _err(e));
    }
  }

  static Future<LowStockResponse> getLowStock({int? companyId}) async {
    try {
      final (_, json) = await _postJson(ApiUrls.companyLowStockUrl,
          {if (companyId != null) 'company_id': companyId});
      return LowStockResponse.fromJson(json);
    } catch (e) {
      return LowStockResponse(status: false, message: _err(e));
    }
  }
}