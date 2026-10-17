// lib/services/remart_post_service.dart
//
// QNX ReMart "Add product" (sell a used / resale item).
//
//   POST olx/categories/                         -> categories (public)
//   POST olx/subcategories/   {category_id}      -> subcategories
//   POST olx/attributes/      {category_id, subcategory_id} -> extra fields
//   POST olx/attributes/create/ {category_id, subcategory_id, name, key, field_type,
//                                options[], is_required, is_active, sort_order} -> new field
//   POST olx/plans/                               -> listing plans (name, duration_days)
//   POST olx/pricing/plans/   {plan_id}           -> price per category for that plan
//   POST olx/listings/create/ (multipart, login)  -> listing (saved as draft)
//   POST olx/payment/create/  {listing_id, plan_id}             -> Razorpay order
//   POST olx/payment/verify/  {razorpay_order_id, razorpay_payment_id, razorpay_signature}
//                                                  -> listing becomes active

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

class RemartOption {
  final int id;
  final String name;
  const RemartOption(this.id, this.name);
}

/// One extra field for a subcategory (e.g. Brand, Year, Fuel type).
class RemartAttribute {
  final int id;
  final String name;
  final String key;
  final String type; // text | number | select | boolean | year
  final List<String> options;
  final bool required;

  const RemartAttribute({
    required this.id,
    required this.name,
    required this.key,
    required this.type,
    required this.options,
    required this.required,
  });

  /// "Fuel Type" -> "fuel_type" (the backend `key` is a SlugField).
  static String keyFrom(String name) {
    final k = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return k.isEmpty ? 'field' : (k.length > 150 ? k.substring(0, 150) : k);
  }

  factory RemartAttribute.fromJson(Map<String, dynamic> j) {
    final raw = j['options'];
    List<String> opts = [];
    if (raw is List) {
      opts = [
        for (final o in raw)
          if (o is Map) '${o['label'] ?? o['value'] ?? o['name'] ?? ''}' else '$o'
      ].where((s) => s.trim().isNotEmpty).toList();
    } else if (raw is String && raw.trim().isNotEmpty) {
      opts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return RemartAttribute(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: '${j['name'] ?? ''}',
      key: '${j['key'] ?? j['name'] ?? ''}',
      type: '${j['field_type'] ?? 'text'}',
      options: opts,
      required: j['is_required'] == true,
    );
  }
}

/// A listing plan with its price for the chosen category.
class RemartPlan {
  final int id;
  final String name;
  final int durationDays;
  final String description;
  final double? price; // null = no price set for this category

  const RemartPlan({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.description,
    this.price,
  });

  RemartPlan withPrice(double? p) =>
      RemartPlan(id: id, name: name, durationDays: durationDays, description: description, price: p);
}

class RemartResult<T> {
  final bool ok;
  final String message;
  final T? data;
  const RemartResult(this.ok, this.message, [this.data]);
}

class RemartPostService {
  static const _json = {'Content-Type': 'application/json', 'Accept': 'application/json'};

  static Future<Map<String, String>> _headers() async {
    final h = Map<String, String>.from(_json);
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static String _err(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException')) return 'Could not reach the server.';
    if (e is TimeoutException) return 'The server took too long to respond.';
    return s.replaceFirst('Exception: ', '');
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('${ApiUrls.baseUrl}$path'), headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    dynamic j;
    try {
      j = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Server error (${res.statusCode}).');
    }
    if (j is! Map) throw Exception('Unexpected server response.');
    final m = Map<String, dynamic>.from(j);
    if (res.statusCode == 401) throw Exception('Your session has expired. Please log in again.');
    if (res.statusCode >= 400 || m['success'] == false) throw Exception(_message(m, 'Request failed.'));
    return m;
  }

  static String _message(Map<String, dynamic> m, String fallback) {
    final errors = m['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      final text = first is List && first.isNotEmpty ? first.first : first;
      final field = errors.keys.first.toString().replaceAll('_', ' ');
      return '$field: $text';
    }
    return '${m['message'] ?? m['error'] ?? fallback}';
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> m) =>
      [for (final e in (m['data'] as List? ?? const [])) if (e is Map) Map<String, dynamic>.from(e)];

  // ---------------------------------------------------------------- lookups
  static Future<RemartResult<List<RemartOption>>> categories() async {
    try {
      final m = await _post('/olx/categories/', {});
      return RemartResult(true, '', [
        for (final c in _list(m))
          if (c['id'] != null) RemartOption((c['id'] as num).toInt(), '${c['name'] ?? ''}')
      ]);
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }

  static Future<RemartResult<List<RemartOption>>> subcategories(int categoryId) async {
    try {
      final m = await _post('/olx/subcategories/', {'category_id': categoryId});
      return RemartResult(true, '', [
        for (final c in _list(m))
          if (c['id'] != null) RemartOption((c['id'] as num).toInt(), '${c['name'] ?? ''}')
      ]);
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }

  static Future<RemartResult<List<RemartAttribute>>> attributes(int categoryId, int subcategoryId) async {
    try {
      final m = await _post('/olx/attributes/', {'category_id': categoryId, 'subcategory_id': subcategoryId});
      return RemartResult(true, '', [for (final a in _list(m)) RemartAttribute.fromJson(a)]);
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }

  /// Creates a new extra field (attribute) for a category / subcategory.
  static Future<RemartResult<RemartAttribute>> createAttribute({
    required int categoryId,
    int? subcategoryId,
    required String name,
    required String fieldType, // text | number | select | boolean | year
    List<String> options = const [],
    bool isRequired = false,
    int sortOrder = 0,
  }) async {
    try {
      final m = await _post('/olx/attributes/create/', {
        'category_id': categoryId,
        if (subcategoryId != null) 'subcategory_id': subcategoryId,
        'name': name.trim(),
        'key': RemartAttribute.keyFrom(name),
        'field_type': fieldType,
        'options': fieldType == 'select' ? options : <String>[],
        'is_required': isRequired,
        'is_active': true,
        'sort_order': sortOrder,
      });
      final d = m['data'];
      if (d is! Map) return const RemartResult(false, 'Attribute saved but no data was returned.');
      return RemartResult(true, '${m['message'] ?? 'Attribute created'}',
          RemartAttribute.fromJson(Map<String, dynamic>.from(d)));
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }

  /// Active plans, each with its price for [categoryId] (null when not priced).
  static Future<RemartResult<List<RemartPlan>>> plansFor(int categoryId) async {
    try {
      final m = await _post('/olx/plans/', {});
      final plans = [
        for (final p in _list(m))
          RemartPlan(
            id: (p['id'] as num?)?.toInt() ?? 0,
            name: '${p['name'] ?? 'Plan'}',
            durationDays: (p['duration_days'] as num?)?.toInt() ?? 0,
            description: '${p['description'] ?? ''}',
          )
      ];
      final priced = await Future.wait(plans.map((p) async {
        try {
          final pr = await _post('/olx/pricing/plans/', {'plan_id': p.id});
          final row = _list(pr).where((r) => '${r['category_id']}' == '$categoryId').firstOrNull;
          return p.withPrice(row == null ? null : double.tryParse('${row['price']}'));
        } catch (_) {
          return p;
        }
      }));
      return RemartResult(true, '', priced);
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }

  // ---------------------------------------------------------------- create
  /// Creates the listing (draft). Returns the new listing id.
  static Future<RemartResult<int>> createListing({
    required Map<String, String> fields,
    required Map<String, dynamic> attributes,
    required List<XFile> images,
  }) async {
    try {
      final token = await SharedPreferencesHelper.getAccessToken();
      if (token == null || token.isEmpty) return const RemartResult(false, 'Please log in to post an item.');

      final req = http.MultipartRequest('POST', Uri.parse('${ApiUrls.baseUrl}/olx/listings/create/'))
        ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $token'})
        ..fields.addAll(fields)
        ..fields['attributes'] = jsonEncode(attributes);

      for (final img in images) {
        final bytes = await img.readAsBytes();
        var name = img.name.isNotEmpty ? img.name : img.path.split('/').last;
        var mime = img.mimeType ?? '';
        if (!mime.startsWith('image/')) {
          final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
          mime = switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
        }
        if (!name.contains('.')) name = '$name.${mime == 'image/png' ? 'png' : 'jpg'}';
        req.files.add(http.MultipartFile.fromBytes('images', bytes, filename: name, contentType: MediaType.parse(mime)));
      }

      final res = await http.Response.fromStream(await req.send().timeout(const Duration(minutes: 3)));
      Map<String, dynamic> j;
      try {
        final d = jsonDecode(res.body);
        j = d is Map ? Map<String, dynamic>.from(d) : {};
      } catch (_) {
        return RemartResult(false, 'Server error (${res.statusCode}). Please try again.');
      }
      if (res.statusCode == 401) return const RemartResult(false, 'Your session has expired. Please log in again.');
      if (res.statusCode >= 200 && res.statusCode < 300 && j['success'] == true) {
        final d = j['data'] is Map ? Map<String, dynamic>.from(j['data']) : const <String, dynamic>{};
        final id = d['id'] is int ? d['id'] as int : int.tryParse('${d['id']}');
        return RemartResult(true, '${j['message'] ?? 'Listing created'}', id);
      }
      return RemartResult(false, _message(j, 'Could not create the listing.'));
    } on TimeoutException {
      return const RemartResult(false, 'Upload took too long. Check your connection and try again.');
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }

  // ---------------------------------------------------------------- payment
  /// Razorpay order for activating [listingId] on [planId].
  /// data: razorpay_order_id, amount_paise, razorpay_key
  static Future<RemartResult<Map<String, dynamic>>> createPayment(int listingId, int planId) async {
    try {
      final m = await _post('/olx/payment/create/', {'listing_id': listingId, 'plan_id': planId});
      return RemartResult(true, '${m['message'] ?? ''}', m);
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }

  static Future<RemartResult<Map<String, dynamic>>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final m = await _post('/olx/payment/verify/', {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      return RemartResult(true, '${m['message'] ?? 'Payment verified'}', m);
    } catch (e) {
      return RemartResult(false, _err(e));
    }
  }
}
