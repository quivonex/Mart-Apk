// lib/services/supplier_service.dart
//
// POST /company/suppliers/list/     body: { "company": 5 }
// POST /company/suppliers/create/   body: { name, email, phone, address, state,
//                                           district, taluka, village, company,
//                                           latitude?, longitude? }
// POST /company/suppliers/update/   body: { id, ...fields }
// POST /company/supplier/delete/    body: { id }

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/supplier_model.dart';
import '../utils/shared_preferences_helper.dart';

class SupplierService {
  static const _timeout = Duration(seconds: 30);

  static Future<Map<String, String>> _headers() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse(url), headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    try {
      final d = jsonDecode(res.body);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
    return {'status': 'error', 'msg': 'Invalid response from server (${res.statusCode})'};
  }

  static String _err(Object e) {
    if (e is SocketException) return 'No internet connection.';
    if (e.toString().contains('TimeoutException')) {
      return 'The server took too long to respond. Try again.';
    }
    return 'Something went wrong: $e';
  }

  static Future<SupplierListResponse> getSuppliers(int companyId) async {
    try {
      final json = await _post(ApiUrls.supplierListUrl, {'company': companyId});
      return SupplierListResponse.fromJson(json);
    } catch (e) {
      return SupplierListResponse(status: false, message: _err(e), data: []);
    }
  }

  static Future<SupplierActionResponse> createSupplier(Map<String, dynamic> fields) async {
    try {
      final json = await _post(ApiUrls.supplierCreateUrl, fields);
      return SupplierActionResponse.fromJson(json);
    } catch (e) {
      return SupplierActionResponse(status: false, message: _err(e));
    }
  }

  static Future<SupplierActionResponse> updateSupplier(
      int id,
      Map<String, dynamic> fields,
      ) async {
    try {
      final json = await _post(ApiUrls.supplierUpdateUrl, {'id': id, ...fields});
      return SupplierActionResponse.fromJson(json);
    } catch (e) {
      return SupplierActionResponse(status: false, message: _err(e));
    }
  }

  static Future<SupplierActionResponse> deleteSupplier(int id) async {
    try {
      final json = await _post(ApiUrls.supplierDeleteUrl, {'id': id});
      return SupplierActionResponse.fromJson(json);
    } catch (e) {
      return SupplierActionResponse(status: false, message: _err(e));
    }
  }
}