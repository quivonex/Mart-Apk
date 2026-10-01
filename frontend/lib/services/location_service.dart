// lib/services/location_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_urls.dart';
import '../models/company_locations_models.dart';
import '../utils/shared_preferences_helper.dart';

class LocationService {
  static Future<Map<String, String>> _headers() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Get All States
  static Future<LocationResponse> getStates() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.stateRetrieveAllUrl),
        headers: headers,
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return LocationResponse.fromJson(
          jsonDecode(response.body),
          'state_name',
        );
      }
      return LocationResponse(
        status: false,
        message: 'Failed to load states (${response.statusCode})',
        data: [],
      );
    } on SocketException {
      return LocationResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return LocationResponse(
        status: false,
        message: 'Error: $e',
        data: [],
      );
    }
  }

  // 2. Get Districts by State
  // Body: { "state_id": 1 }
  static Future<LocationResponse> getDistricts(int stateId) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.getDistrictsUrl),
        headers: headers,
        body: jsonEncode({'state_id': stateId}),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return LocationResponse.fromJson(
          jsonDecode(response.body),
          'district_name',
        );
      }
      return LocationResponse(
        status: false,
        message: 'Failed to load districts',
        data: [],
      );
    } on SocketException {
      return LocationResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return LocationResponse(
        status: false,
        message: 'Error: $e',
        data: [],
      );
    }
  }

  // 3. Get Talukas by State + District
  // Body: { "state_id": 1, "district_id": 10 }
  static Future<LocationResponse> getTalukas(
      int stateId,
      int districtId,
      ) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
        Uri.parse(ApiUrls.getTalukasUrl),
        headers: headers,
        body: jsonEncode({
          'state_id': stateId,
          'district_id': districtId,
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return LocationResponse.fromJson(
          jsonDecode(response.body),
          'taluka_name',
        );
      }
      return LocationResponse(
        status: false,
        message: 'Failed to load talukas',
        data: [],
      );
    } on SocketException {
      return LocationResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return LocationResponse(
        status: false,
        message: 'Error: $e',
        data: [],
      );
    }
  }

  // 4. Get Villages by State + District + Taluka
  // Body: { "state_id": 1, "district_id": 10, "taluka_id": 100 }
  static Future<LocationResponse> getVillages(
      int stateId,
      int districtId,
      int talukaId,
      ) async {
    try {
      final headers = await _headers();
      final response = await http
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

      if (response.statusCode == 200) {
        return LocationResponse.fromJson(
          jsonDecode(response.body),
          'village_name',
        );
      }
      return LocationResponse(
        status: false,
        message: 'Failed to load villages',
        data: [],
      );
    } on SocketException {
      return LocationResponse(
        status: false,
        message: 'No internet connection.',
        data: [],
      );
    } catch (e) {
      return LocationResponse(
        status: false,
        message: 'Error: $e',
        data: [],
      );
    }
  }
}