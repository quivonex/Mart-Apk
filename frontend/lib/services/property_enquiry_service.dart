import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'api_urls.dart';
import '../models/property_enquiry_model.dart';
import '../utils/shared_preferences_helper.dart';
import 'package:qnx_mart/l10n/app_language.dart';

class PropertyEnquiryService {
  /// Submit property enquiry.
  ///
  /// POST /real_estate/create/enquiry/
  /// Body: { property, customer_name, customer_email, customer_mobile,
  ///         message, flat_type?, budget_min?, budget_max? }
  ///
  /// • Sends the login token when there is one.
  /// • If the server answers 401 (expired / invalid token – JWT rejects it even
  ///   on open APIs) the request is retried once without the token.
  /// • Never hides the real reason: field errors, `detail`, HTTP code or a
  ///   non-JSON (HTML) server error are all turned into a readable message.
  static Future<PropertyEnquiryResponse> submitEnquiry(
      PropertyEnquiryRequest request,
      ) async {
    if (request.property <= 0) {
      return PropertyEnquiryResponse(
        success: false,
        message: tr('Property details are not loaded. Please go back and open the property again.'),
      );
    }

    final body = jsonEncode(request.toJson());
    final token = await SharedPreferencesHelper.getAccessToken();
    final hasToken = token != null && token.isNotEmpty;

    try {
      var res = await _post(body, hasToken ? token : null);
      if (res.statusCode == 401 && hasToken) {
        debugPrint('[PropertyEnquiry] 401 with token → retrying without token');
        res = await _post(body, null);
      }
      return _parse(res);
    } on TimeoutException {
      return PropertyEnquiryResponse(
        success: false,
        message: tr('The server took too long to respond. Please try again.'),
      );
    } catch (e) {
      debugPrint('[PropertyEnquiry] request failed: $e');
      // dart:io-free (works on web): network errors arrive as
      // SocketException on mobile and ClientException on web.
      final s = e.toString();
      if (s.contains('SocketException') || s.contains('ClientException')) {
        return PropertyEnquiryResponse(
          success: false,
          message: tr('Could not reach the server. Check your internet / server and try again.'),
        );
      }
      return PropertyEnquiryResponse(
        success: false,
        message: tr('Could not send enquiry: {0}', [s.replaceFirst('Exception: ', '')]),
      );
    }
  }

  static Future<http.Response> _post(String body, String? token) {
    return http
        .post(
      Uri.parse(ApiUrls.createPropertyEnquiryUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body,
    )
        .timeout(const Duration(seconds: 30));
  }

  static PropertyEnquiryResponse _parse(http.Response res) {
    debugPrint('[PropertyEnquiry] ${res.statusCode} ${res.body.length > 600 ? res.body.substring(0, 600) : res.body}');

    Map<String, dynamic>? json;
    try {
      final d = jsonDecode(res.body);
      if (d is Map) json = Map<String, dynamic>.from(d);
    } catch (_) {
      json = null;
    }

    if (json == null) {
      // HTML error page (e.g. Django 500 / nginx 502) or empty body.
      final ok = res.statusCode == 200 || res.statusCode == 201;
      return PropertyEnquiryResponse(
        success: ok,
        statusCode: res.statusCode,
        message: ok
            ? tr('Enquiry submitted successfully.')
            : res.statusCode >= 500
            ? tr('Server error ({0}). Please try again in a moment.', [res.statusCode])
            : tr('Could not send enquiry (HTTP {0}).', [res.statusCode]),
      );
    }

    final r = PropertyEnquiryResponse.fromJson(json, statusCode: res.statusCode);
    // 2xx without an explicit success flag still means the enquiry was saved.
    if (r.success == null && (res.statusCode == 200 || res.statusCode == 201)) {
      return PropertyEnquiryResponse(
        success: true,
        statusCode: res.statusCode,
        message: r.message ?? tr('Enquiry submitted successfully.'),
      );
    }
    return r;
  }
}
