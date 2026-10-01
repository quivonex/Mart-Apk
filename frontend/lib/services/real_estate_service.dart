import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/property_model.dart';
import '../utils/shared_preferences_helper.dart';

class RealEstateService {
  // ─────────────────────────────────────────────────────────
  // API 1: Get Approved Properties (NO auth token)
  // ─────────────────────────────────────────────────────────
  static Future<PropertyResponse> getApprovedProperties() async {
    try {
      final Uri url = Uri.parse(ApiUrls.approvedPropertiesUrl);

      final http.Response response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return PropertyResponse(
          status: false,
          message: 'Invalid response from server',
          data: [],
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PropertyResponse.fromJson(jsonData);
      }

      return PropertyResponse(
        status: false,
        message: jsonData['message']?.toString() ??
            'Failed to load properties',
        data: [],
      );
    } on SocketException {
      return PropertyResponse(
        status: false,
        message: 'No internet connection. Please check your network.',
        data: [],
      );
    } on HttpException {
      return PropertyResponse(
        status: false,
        message: 'Server error. Please try again later.',
        data: [],
      );
    } catch (e) {
      return PropertyResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 2: Get Amenities List (WITH auth token)
  // ─────────────────────────────────────────────────────────
  static Future<AmenitiesListResponse> getAmenitiesList() async {
    try {
      final Uri url = Uri.parse(ApiUrls.amenitiesListUrl);

      final accessToken = await SharedPreferencesHelper.getAccessToken();

      final http.Response response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({}),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return AmenitiesListResponse(
          status: false,
          message: 'Invalid response from server',
          data: [],
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AmenitiesListResponse.fromJson(jsonData);
      }

      return AmenitiesListResponse(
        status: false,
        message: jsonData['message']?.toString() ??
            'Failed to load amenities',
        data: [],
      );
    } on SocketException {
      return AmenitiesListResponse(
        status: false,
        message: 'No internet connection. Please check your network.',
        data: [],
      );
    } on HttpException {
      return AmenitiesListResponse(
        status: false,
        message: 'Server error. Please try again later.',
        data: [],
      );
    } catch (e) {
      return AmenitiesListResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
        data: [],
      );
    }
  }

  // ─────────────────────────────────────────────────────────
  // API 3: Get Property Detail by Slug (NEW)
  // ─────────────────────────────────────────────────────────
  static Future<PropertyDetailResponse> getPropertyDetail(
    String slug,
  ) async {
    try {
      final Uri url = Uri.parse(ApiUrls.propertyDetailUrl);

      final http.Response response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'slug': slug}),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return PropertyDetailResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return PropertyDetailResponse.fromJson(jsonData);
      }

      return PropertyDetailResponse(
        status: false,
        message: jsonData['message']?.toString() ??
            'Failed to load property details',
      );
    } on SocketException {
      return PropertyDetailResponse(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return PropertyDetailResponse(
        status: false,
        message: 'Server error. Please try again later.',
      );
    } catch (e) {
      return PropertyDetailResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}
