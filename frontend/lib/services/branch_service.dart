import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/branch_model.dart';
import '../utils/shared_preferences_helper.dart';

class BranchService {
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
  // API 1: Get Company Names (dropdown)
  // ─────────────────────────────────────────────────────────
  static Future<CompanyNamesResponse> getCompanyNames() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.companyNamesUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return CompanyNamesResponse.fromJson(jsonData);
    } on SocketException {
      return CompanyNamesResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return CompanyNamesResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 2: Get Branch List
  // ─────────────────────────────────────────────────────────
  static Future<BranchListResponse> getBranches() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.branchListUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BranchListResponse.fromJson(jsonData);
    } on SocketException {
      return BranchListResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return BranchListResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Create Branch
  // ─────────────────────────────────────────────────────────
  static Future<BranchActionResponse> createBranch({
    required int company,
    required String name,
    required String phoneNumber,
    required String email,
    required String address,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.branchCreateUrl),
        headers: headers,
        body: jsonEncode({
          'company': company,
          'name': name,
          'phone_number': phoneNumber,
          'email': email,
          'address': address,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BranchActionResponse.fromJson(jsonData);
    } on SocketException {
      return BranchActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BranchActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 4: Update Branch
  // ─────────────────────────────────────────────────────────
  static Future<BranchActionResponse> updateBranch({
    required int id,
    required int company,
    required String name,
    required String phoneNumber,
    required String email,
    required String address,
  }) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.branchUpdateUrl),
        headers: headers,
        body: jsonEncode({
          'id': id,
          'company': company,
          'name': name,
          'phone_number': phoneNumber,
          'email': email,
          'address': address,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BranchActionResponse.fromJson(jsonData);
    } on SocketException {
      return BranchActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BranchActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 5: Soft Delete (Deactivate)
  // ─────────────────────────────────────────────────────────
  static Future<BranchActionResponse> softDeleteBranch(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.branchSoftDeleteUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BranchActionResponse.fromJson(jsonData);
    } on SocketException {
      return BranchActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BranchActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 6: Restore Branch
  // ─────────────────────────────────────────────────────────
  static Future<BranchActionResponse> restoreBranch(int id) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.branchRestoreUrl),
        headers: headers,
        body: jsonEncode({'id': id}),
      )
          .timeout(const Duration(seconds: 30));

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      return BranchActionResponse.fromJson(jsonData);
    } on SocketException {
      return BranchActionResponse(
        status: false,
        message: 'No internet connection.',
      );
    } catch (e) {
      return BranchActionResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}