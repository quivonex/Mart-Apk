import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_urls.dart';
import '../models/franchise_plan_model.dart';
import 'package:qnx_mart/l10n/app_language.dart';

class FranchisePlanService {
  /// Fetch franchise plans for a given product slug.
  ///
  /// POST /franchicies/product-franchise-plans/
  /// Body: { "slug": "product-slug" }
  static Future<FranchisePlanResponse> getFranchisePlans(
      FranchisePlanRequest request,
      ) async {
    try {
      final Uri url = Uri.parse(ApiUrls.productFranchisePlansUrl);

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
        return FranchisePlanResponse(
          status: false,
          message: tr('Invalid response from server'),
          data: [],
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return FranchisePlanResponse.fromJson(jsonData);
      }

      return FranchisePlanResponse(
        status: false,
        message: jsonData['message']?.toString() ??
            tr('An error occurred while loading franchise plans.'),
        data: [],
      );
    } on SocketException {
      return FranchisePlanResponse(
        status: false,
        message: tr('No internet connection. Please check your network.'),
        data: [],
      );
    } on HttpException {
      return FranchisePlanResponse(
        status: false,
        message: tr('Server error. Please try again later.'),
        data: [],
      );
    } catch (e) {
      return FranchisePlanResponse(
        status: false,
        message: tr('Something went wrong: {0}', [e.toString()]),
        data: [],
      );
    }
  }
}

