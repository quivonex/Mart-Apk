// lib/services/location_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_urls.dart';
import '../models/location_models.dart';
import '../utils/shared_preferences_helper.dart';
import 'company_locations_models.dart';

class LocationService {
  static Future<Map<String, String>> _headers() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  // ─── 1. States ───────────────────────────────────────
  // POST  {BASE_URL}state/state_retrieveAll/
  // Body: {}
  static Future<LocationResponse> getStates() async {
    try {
      final headers = await _headers();
      final res = await http
          .post(
        Uri.parse(ApiUrls.stateRetrieveAllUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return LocationResponse.fromJson(json, 'state_name');
    } catch (e) {
      return LocationResponse(status: false, message: e.toString(), data: []);
    }
  }

  // ─── 2. Districts ────────────────────────────────────
  // POST  {BASE_URL}state/get_districts/
  // Body: { "state_id": 1 }
  static Future<LocationResponse> getDistricts(int stateId) async {
    try {
      final headers = await _headers();
      final res = await http
          .post(
        Uri.parse(ApiUrls.getDistrictsUrl),
        headers: headers,
        body: jsonEncode({'state_id': stateId}),
      )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return LocationResponse.fromJson(json, 'district_name');
    } catch (e) {
      return LocationResponse(status: false, message: e.toString(), data: []);
    }
  }

  // ─── 3. Talukas ──────────────────────────────────────
  // POST  {BASE_URL}state/get_talukas/
  // Body: { "state_id": 1, "district_id": 10 }
  static Future<LocationResponse> getTalukas(
      int stateId,
      int districtId,
      ) async {
    try {
      final headers = await _headers();
      final res = await http
          .post(
        Uri.parse(ApiUrls.getTalukasUrl),
        headers: headers,
        body: jsonEncode({
          'state_id': stateId,
          'district_id': districtId,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return LocationResponse.fromJson(json, 'taluka_name');
    } catch (e) {
      return LocationResponse(status: false, message: e.toString(), data: []);
    }
  }

  // ─── 4. Villages ─────────────────────────────────────
  // POST  {BASE_URL}state/get_villages/
  // Body: { "state_id": 1, "district_id": 10, "taluka_id": 100 }
  static Future<LocationResponse> getVillages(
      int stateId,
      int districtId,
      int talukaId,
      ) async {
    try {
      final headers = await _headers();
      final res = await http
          .post(
        Uri.parse(ApiUrls.getVillagesUrl),
        headers: headers,
        body: jsonEncode({
          'state_id': stateId,
          'district_id': districtId,
          'taluka_id': talukaId,
        }),
      )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return LocationResponse.fromJson(json, 'village_name');
    } catch (e) {
      return LocationResponse(status: false, message: e.toString(), data: []);
    }
  }
}