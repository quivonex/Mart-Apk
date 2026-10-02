// lib/services/company_locations_service.dart
//
// POST /state/state_retrieveAll/   {}                                   -> state_name
// POST /state/get_districts/       {state_id}                           -> district_name
// POST /state/get_talukas/         {state_id, district_id}              -> taluka_name
// POST /state/get_villages/        {state_id, district_id, taluka_id}   -> village_name

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/company_locations_models.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

class CompanyLocationService {
  static const _timeout = Duration(seconds: 30);

  static Future<Map<String, String>> _headers() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<LocationResponse> _post(
      String url,
      Map<String, dynamic> body,
      String nameKey,
      String what,
      ) async {
    try {
      final res = await http
          .post(Uri.parse(url), headers: await _headers(), body: jsonEncode(body))
          .timeout(_timeout);

      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}

      if (json == null) {
        // Django returned an HTML error page (e.g. 500 when Redis is not running).
        return LocationResponse(
          status: false,
          message: 'Could not load $what (server error ${res.statusCode}).',
          data: [],
        );
      }

      final parsed = LocationResponse.fromJson(json, nameKey);
      if (!parsed.status && parsed.data.isEmpty) {
        return LocationResponse(
          status: false,
          message: parsed.message ?? 'Could not load $what.',
          data: [],
        );
      }
      return parsed;
    } on SocketException {
      return LocationResponse(
          status: false, message: 'No connection to the server.', data: []);
    } on TimeoutException {
      return LocationResponse(
          status: false, message: 'Loading $what timed out.', data: []);
    } catch (e) {
      return LocationResponse(status: false, message: 'Could not load $what: $e', data: []);
    }
  }

  static Future<LocationResponse> getStates() =>
      _post(ApiUrls.stateRetrieveAllUrl, {}, 'state_name', 'states');

  static Future<LocationResponse> getDistricts(int stateId) =>
      _post(ApiUrls.getDistrictsUrl, {'state_id': stateId}, 'district_name', 'districts');

  static Future<LocationResponse> getTalukas(int stateId, int districtId) => _post(
    ApiUrls.getTalukasUrl,
    {'state_id': stateId, 'district_id': districtId},
    'taluka_name',
    'talukas',
  );

  static Future<LocationResponse> getVillages(int stateId, int districtId, int talukaId) =>
      _post(
        ApiUrls.getVillagesUrl,
        {'state_id': stateId, 'district_id': districtId, 'taluka_id': talukaId},
        'village_name',
        'villages',
      );
}