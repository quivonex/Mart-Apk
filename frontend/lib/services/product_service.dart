import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import 'api_urls.dart';
import '../utils/shared_preferences_helper.dart';

class ProductService {
  // Get Latest Approved Products (Home Screen)
  static Future<LatestProductsResponse> getLatestApprovedProducts() async {
    try {
      final accessToken = await SharedPreferencesHelper.getAccessToken();

      final response = await http.post(
        Uri.parse(ApiUrls.latestApprovedProductsUrl),
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({}), // Empty object
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return LatestProductsResponse.fromJson(responseData);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        String errorMessage = 'Failed to load latest products';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData.containsKey('error')) {
            errorMessage = responseData['error'];
          } else if (responseData.containsKey('detail')) {
            errorMessage = responseData['detail'];
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        throw Exception(e.toString());
      }
      throw Exception('Network error. Please check your connection.');
    }
  }

  // Get Approved Product List (Products Screen)
  static Future<ApprovedProductListResponse> getApprovedProductList() async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.approvedProductListUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}), // Empty object
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApprovedProductListResponse.fromJson(responseData);
      } else {
        String errorMessage = 'Failed to load products';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData.containsKey('error')) {
            errorMessage = responseData['error'];
          } else if (responseData.containsKey('detail')) {
            errorMessage = responseData['detail'];
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e is Exception) {
        throw Exception(e.toString());
      }
      throw Exception('Network error. Please check your connection.');
    }
  }
}