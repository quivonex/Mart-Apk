import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/product_enquiry_model.dart';
import '../utils/shared_preferences_helper.dart';

class ProductEnquiryService {
  /// Submit product enquiry with multipart/form-data.
  ///
  /// POST /enquiry/product-enquiry/
  /// Headers: Authorization: Bearer <token>
  static Future<ProductEnquiryResponse> submitEnquiry(
      ProductEnquiryRequest request,
      ) async {
    try {
      // Get access token
      final accessToken = await SharedPreferencesHelper.getAccessToken();

      // Build multipart request
      final http.MultipartRequest multipartRequest =
      await request.toMultipartRequest(ApiUrls.productEnquiryUrl);

      // Add headers (Content-Type auto-set by MultipartRequest)
      multipartRequest.headers['Accept'] = 'application/json';
      if (accessToken != null && accessToken.isNotEmpty) {
        multipartRequest.headers['Authorization'] = 'Bearer $accessToken';
      }

      // Debug log
      // print('📤 POST ${multipartRequest.url}');
      // print('📤 Fields: ${multipartRequest.fields}');
      // print('📤 Files: ${multipartRequest.files.map((f) => f.filename)}');

      // Send request with timeout
      final http.StreamedResponse streamedResponse =
      await multipartRequest.send().timeout(const Duration(seconds: 60));

      // Convert streamed response to normal response
      final http.Response response =
      await http.Response.fromStream(streamedResponse);

      // Debug log
      // print('📥 Status: ${response.statusCode}');
      // print('📥 Body: ${response.body}');

      // Parse response
      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return ProductEnquiryResponse(
          status: false,
          message: 'Invalid response from server',
        );
      }

      // Success
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ProductEnquiryResponse.fromJson(jsonData);
      }

      // Error (400, 401, 422, 500 etc.)
      return ProductEnquiryResponse.fromJson(jsonData);
    } on SocketException {
      return ProductEnquiryResponse(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return ProductEnquiryResponse(
        status: false,
        message: 'Server error. Please try again later.',
      );
    } catch (e) {
      return ProductEnquiryResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}