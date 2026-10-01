import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_urls.dart';
import '../models/loan_enquiry_model.dart';

class LoanEnquiryService {
  /// Creates a new loan enquiry by sending a POST request
  /// to the backend at `/loan/loan-enquiry/create/`.
  ///
  /// Returns a [LoanEnquiryResponse] which contains:
  /// - `status` : true on success, false on failure
  /// - `message`: success or error message from the server
  /// - `error`  : error description (if any)
  Future<LoanEnquiryResponse> createLoanEnquiry(
      LoanEnquiryRequest request,
      ) async {
    try {
      final Uri url = Uri.parse(ApiUrls.createLoanEnquiryUrl);

      // Prepare headers
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Encode the request body as JSON
      final String body = jsonEncode(request.toJson());

      // Debug log (optional - remove in production)
      // print('📤 POST $url');
      // print('📤 Body: $body');

      // Send the POST request
      final http.Response response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      // Debug log (optional - remove in production)
      // print('📥 Status: ${response.statusCode}');
      // print('📥 Body: ${response.body}');

      // Parse the response body
      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return LoanEnquiryResponse(
          status: false,
          error: 'Invalid response from server',
        );
      }

      // Handle success (200 OK or 201 Created)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return LoanEnquiryResponse.fromJson(jsonData);
      }

      // Handle other status codes (400, 401, 500, etc.)
      return LoanEnquiryResponse(
        status: false,
        message: jsonData['message']?.toString(),
        error: jsonData['error']?.toString() ??
            'Request failed with status ${response.statusCode}',
      );
    } on SocketException {
      return LoanEnquiryResponse(
        status: false,
        error: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return LoanEnquiryResponse(
        status: false,
        error: 'Server error. Please try again later.',
      );
    } on FormatException {
      return LoanEnquiryResponse(
        status: false,
        error: 'Bad response format from server.',
      );
    } catch (e) {
      return LoanEnquiryResponse(
        status: false,
        error: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}