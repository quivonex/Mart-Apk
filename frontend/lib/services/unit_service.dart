import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_urls.dart';
import '../models/unit_model.dart';
import '../utils/shared_preferences_helper.dart';

class UnitService {
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
  // API 1: Get Unit List
  // ─────────────────────────────────────────────────────────
  static Future<UnitListResponse> getUnitList() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.unitListUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return UnitListResponse.fromJson(jsonData);
    } on SocketException {
      return UnitListResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return UnitListResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 2: Create Unit
  // ─────────────────────────────────────────────────────────
  static Future<UnitActionResponse> createUnit({
    required String name,
    required String shortName,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.unitCreateUrl),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'short_name': shortName,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return UnitActionResponse.fromJson(jsonData);
    } on SocketException {
      return UnitActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return UnitActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Update Unit
  // ─────────────────────────────────────────────────────────
  static Future<UnitActionResponse> updateUnit({
    required int id,
    required String name,
    required String shortName,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.unitUpdateUrl),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'name': name,
          'short_name': shortName,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return UnitActionResponse.fromJson(jsonData);
    } on SocketException {
      return UnitActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return UnitActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 4: Soft Delete
  // ─────────────────────────────────────────────────────────
  static Future<UnitActionResponse> softDeleteUnit(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.unitSoftDeleteUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return UnitActionResponse.fromJson(jsonData);
    } on SocketException {
      return UnitActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return UnitActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 5: Restore
  // ─────────────────────────────────────────────────────────
  static Future<UnitActionResponse> restoreUnit(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.unitRestoreUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return UnitActionResponse.fromJson(jsonData);
    } on SocketException {
      return UnitActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return UnitActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}