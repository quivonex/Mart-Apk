import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/property_enquiry_model.dart';

class PropertyEnquiryService {
  /// Submit property enquiry.
  ///
  /// POST /real_estate/create/enquiry/
  /// Body: { property, customer_name, customer_email, ... }
  static Future<PropertyEnquiryResponse> submitEnquiry(
    PropertyEnquiryRequest request,
  ) async {
    try {
      final Uri url = Uri.parse(ApiUrls.createPropertyEnquiryUrl);

      final http.Response response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return PropertyEnquiryResponse(
          success: false,
          message: 'Invalid response from server',
        );
      }

      // Success (200 or 201)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PropertyEnquiryResponse.fromJson(jsonData);
      }

      // Error (400, 401, 422, 500 etc.)
      return PropertyEnquiryResponse.fromJson(jsonData);
    } on SocketException {
      return PropertyEnquiryResponse(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return PropertyEnquiryResponse(
        success: false,
        message: 'Server error. Please try again later.',
      );
    } catch (e) {
      return PropertyEnquiryResponse(
        success: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}
