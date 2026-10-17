// lib/services/property_create_service.dart
//
// POST real_estate/property/create/   (multipart, login required)
//   fields  : title, description, property_type, transaction_type, … (strings)
//             amenities / flat_types / floors / pricing_slabs as JSON strings
//   images  : images[]      (image files)
//   videos  : videos[]      (video files – backend uploads each to S3 as PropertyVideo)
//   PDFs    : documents[]   + document_types / document_titles (JSON lists, same order)
// Response  : { success, message, property_id, subscription{…}, data }
//
// POST real_estate/amenity/create/   (JSON)  { name, icon }
// Response  : { status, message, data{id, name, icon, is_active} } | { status:false, errors }

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../models/property_model.dart';
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

class AmenityCreateResult {
  final bool ok;
  final String message;
  final Amenity? amenity;

  const AmenityCreateResult({required this.ok, required this.message, this.amenity});
}

class PropertyCreateService {
  /// Adds a new amenity to the master list (e.g. "Rooftop Garden").
  static Future<AmenityCreateResult> createAmenity({
    required String name,
    String icon = '',
  }) async {
    try {
      final token = await SharedPreferencesHelper.getAccessToken();
      final res = await http
          .post(
        Uri.parse('${ApiUrls.baseUrl}/real_estate/amenity/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name.trim(), 'icon': icon.trim(), 'is_active': true}),
      )
          .timeout(const Duration(seconds: 25));
      Map<String, dynamic> j;
      try {
        final d = jsonDecode(res.body);
        j = d is Map<String, dynamic> ? d : {};
      } catch (_) {
        return AmenityCreateResult(ok: false, message: 'Server error (${res.statusCode}). Please try again.');
      }
      final ok = res.statusCode >= 200 && res.statusCode < 300 && (j['status'] == true || j['success'] == true);
      if (ok && j['data'] is Map) {
        final a = Amenity.fromJson(Map<String, dynamic>.from(j['data']));
        if (a.id > 0) {
          return AmenityCreateResult(ok: true, message: (j['message'] ?? 'Amenity added').toString(), amenity: a);
        }
      }
      return AmenityCreateResult(ok: false, message: _errorText(j, res.statusCode));
    } on TimeoutException {
      return const AmenityCreateResult(ok: false, message: 'The server took too long to respond.');
    } catch (e) {
      final s = e.toString();
      if (s.contains('SocketException') || s.contains('ClientException')) {
        return const AmenityCreateResult(ok: false, message: 'Could not reach the server.');
      }
      return AmenityCreateResult(ok: false, message: 'Something went wrong: $s');
    }
  }

  static http.MultipartFile _videoPart(String field, List<int> bytes, XFile v) {
    var name = v.name.isNotEmpty ? v.name : v.path.split('/').last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    var mime = v.mimeType ?? '';
    if (!mime.startsWith('video/')) {
      mime = switch (ext) {
        'mov' => 'video/quicktime',
        'webm' => 'video/webm',
        '3gp' => 'video/3gpp',
        'mkv' => 'video/x-matroska',
        'avi' => 'video/x-msvideo',
        _ => 'video/mp4',
      };
    }
    if (!name.contains('.')) name = '$name.mp4';
    return http.MultipartFile.fromBytes(field, bytes, filename: name, contentType: MediaType.parse(mime));
  }

  static Future<PropertyCreateResult> createProperty({
    required Map<String, String> fields,
    List<XFile> images = const [],
    List<XFile> videos = const [],
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

      for (final v in videos) {
        req.files.add(_videoPart('videos', await v.readAsBytes(), v));
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

      final streamed = await req.send().timeout(Duration(minutes: videos.isEmpty ? 3 : 8));
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
