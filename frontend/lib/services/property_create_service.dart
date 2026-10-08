// lib/services/property_create_service.dart
//
// POST real_estate/property/create/   (multipart, login required)
//   fields  : title, description, property_type, transaction_type, … (strings)
//             amenities / flat_types / floors / pricing_slabs as JSON strings
//   images  : images[]      (image files)
//   PDFs    : documents[]   + document_types / document_titles (JSON lists, same order)
// Response  : { success, message, property_id, subscription{…}, data }

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

class PropertyDocumentUpload {
  final String fileName;
  final Uint8List bytes;
  String type; // sale_deed | agreement | noc | approval | registration | rera | other
  String title;

  PropertyDocumentUpload({
    required this.fileName,
    required this.bytes,
    this.type = 'other',
    this.title = '',
  });

  int get sizeBytes => bytes.lengthInBytes;
}

class PropertyCreateResult {
  final bool ok;
  final String message;
  final int? propertyId;
  final int? freeDays;
  final bool subscriptionRequired;

  PropertyCreateResult({
    required this.ok,
    required this.message,
    this.propertyId,
    this.freeDays,
    this.subscriptionRequired = false,
  });
}

class PropertyCreateService {
  static Future<PropertyCreateResult> createProperty({
    required Map<String, String> fields,
    List<XFile> images = const [],
    List<PropertyDocumentUpload> documents = const [],
  }) async {
    try {
      final token = await SharedPreferencesHelper.getAccessToken();
      if (token == null || token.isEmpty) {
        return PropertyCreateResult(ok: false, message: 'Please log in to list a property.');
      }
      final req = http.MultipartRequest('POST', Uri.parse('${ApiUrls.baseUrl}/real_estate/property/create/'))
        ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $token'})
        ..fields.addAll(fields);

      for (final img in images) {
        final bytes = await img.readAsBytes();
        var name = img.name.isNotEmpty ? img.name : img.path.split('/').last;
        var mime = img.mimeType ?? '';
        if (!mime.startsWith('image/')) {
          final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
          mime = switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
        }
        if (!name.contains('.')) name = '$name.${mime == 'image/png' ? 'png' : 'jpg'}';
        req.files.add(http.MultipartFile.fromBytes('images', bytes,
            filename: name, contentType: MediaType.parse(mime)));
      }

      if (documents.isNotEmpty) {
        req.fields['document_types'] = jsonEncode([for (final d in documents) d.type]);
        req.fields['document_titles'] = jsonEncode([for (final d in documents) d.title.trim()]);
        for (final d in documents) {
          final name = d.fileName.toLowerCase().endsWith('.pdf') ? d.fileName : '${d.fileName}.pdf';
          req.files.add(http.MultipartFile.fromBytes('documents', d.bytes,
              filename: name, contentType: MediaType('application', 'pdf')));
        }
      }

      final streamed = await req.send().timeout(const Duration(minutes: 3));
      final res = await http.Response.fromStream(streamed);
      Map<String, dynamic> j;
      try {
        final d = jsonDecode(res.body);
        j = d is Map<String, dynamic> ? d : {};
      } catch (_) {
        return PropertyCreateResult(ok: false, message: 'Server error (${res.statusCode}). Please try again.');
      }

      if (res.statusCode >= 200 && res.statusCode < 300 && j['success'] == true) {
        final sub = j['subscription'] is Map ? Map<String, dynamic>.from(j['subscription']) : const {};
        return PropertyCreateResult(
          ok: true,
          message: (j['message'] ?? 'Property created').toString(),
          propertyId: j['property_id'] is int ? j['property_id'] : int.tryParse('${j['property_id']}'),
          freeDays: sub['free_days'] is int ? sub['free_days'] : int.tryParse('${sub['free_days']}'),
          subscriptionRequired: sub['subscription_required'] == true,
        );
      }
      return PropertyCreateResult(ok: false, message: _errorText(j, res.statusCode));
    } on TimeoutException {
      return PropertyCreateResult(ok: false, message: 'Upload took too long. Check your connection and try again.');
    } catch (e) {
      final s = e.toString();
      if (s.contains('SocketException') || s.contains('ClientException')) {
        return PropertyCreateResult(ok: false, message: 'Could not reach the server.');
      }
      return PropertyCreateResult(ok: false, message: 'Something went wrong: $s');
    }
  }

  static String _errorText(Map<String, dynamic> j, int code) {
    final errors = j['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final key = errors.keys.first.toString();
      final val = errors[key];
      String text;
      if (val is List && val.isNotEmpty) {
        final first = val.first;
        text = first is Map ? first.values.first.toString() : first.toString();
      } else {
        text = val.toString();
      }
      final label = key.replaceAll('_', ' ');
      return key == 'non_field_errors' ? text : '${label[0].toUpperCase()}${label.substring(1)}: $text';
    }
    if (code == 401) return 'Session expired. Please log in again.';
    return (j['message'] ?? j['error'] ?? 'Could not create the property ($code).').toString();
  }
}