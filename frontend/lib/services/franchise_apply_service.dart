import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/franchise_plan_model.dart';
import 'api_urls.dart';

class FranchiseApplyService {
  /// Submit franchise application.
  ///
  /// POST /franchicies/franchise/create/
  static Future<FranchiseApplyResponse> submitApplication(
      FranchiseApplyRequest request,
      ) async {
    try {
      final Uri url = Uri.parse(ApiUrls.franchiseCreateUrl);

      final http.Response response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // ⚠️ No Authorization header as per API spec
        },
        body: jsonEncode(request.toJson()),
      )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return FranchiseApplyResponse(
          status: false,
          message: 'Invalid response from server.',
        );
      }

      // Success (200 or 201)
      if (response.statusCode == 200 || response.statusCode == 201) {
        return FranchiseApplyResponse.fromJson(jsonData);
      }

      // Error
      return FranchiseApplyResponse.fromJson(jsonData);
    } on SocketException {
      return FranchiseApplyResponse(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return FranchiseApplyResponse(
        status: false,
        message: 'Server error. Please try again later.',
      );
    } catch (e) {
      return FranchiseApplyResponse(
        status: false,
        message: 'Something went wrong: ${e.toString()}',
      );
    }
  }
}