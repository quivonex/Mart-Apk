import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/marketing_partner_enquiry_model.dart';
import 'api_urls.dart';
import '../models/marketing_partner_enquiry_model.dart';

class PartnerService {
  /// Submit Marketing Partner Enquiry
  static Future<MarketingPartnerEnquiryResponse> createEnquiry({
    required MarketingPartnerEnquiryRequest data,
    String? authToken,
  }) async {
    try {
      final uri = Uri.parse(ApiUrls.createMarketingPartnerEnquiryUrl);

      final request = http.MultipartRequest('POST', uri);

      // Headers
      if (authToken != null && authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      // Add text fields
      final fields = data.toMap();
      fields.forEach((key, value) {
        if (value is List) {
          request.fields[key] = jsonEncode(value);
        } else {
          request.fields[key] = value.toString();
        }
      });

      // ===== Add profile image (works on Web + Mobile) =====
      if (data.profileImage != null) {
        final xfile = data.profileImage!;

        // Read bytes from XFile (works on web & mobile)
        final bytes = await xfile.readAsBytes();

        // Determine content type
        final mimeType = _getMimeType(xfile.name);

        final multipartFile = http.MultipartFile.fromBytes(
          'profile_image',
          bytes,
          filename: xfile.name,
          contentType: mimeType,
        );

        request.files.add(multipartFile);
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Parse response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return MarketingPartnerEnquiryResponse.fromJson(jsonData);
      } else {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          return MarketingPartnerEnquiryResponse.fromJson(jsonData);
        } catch (_) {
          return MarketingPartnerEnquiryResponse(
            status: false,
            message: 'Something went wrong. Please try again.',
          );
        }
      }
    } on SocketException {
      return MarketingPartnerEnquiryResponse(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } catch (e) {
      return MarketingPartnerEnquiryResponse(
        status: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  /// Detect MIME type from file name
  static MediaType _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    } else if (lower.endsWith('.gif')) {
      return MediaType('image', 'gif');
    } else if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    } else {
      return MediaType('image', 'jpeg');
    }
  }
}
