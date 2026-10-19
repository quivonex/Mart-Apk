// lib/services/my_property_service.dart
//
// Properties posted by the logged-in user + their listing subscription.
//
//   POST real_estate/my/properties/                    {}                       (login)
//   POST payment/property-subscription-plan/list/      {}
//   POST payment/property-subscription/create-order/   {property_id, plan_id}   (login)
//        -> {success, data:{razorpay_order_id, razorpay_key, amount, plan_name, days}}
//   POST payment/property-subscription/verify/         {razorpay_order_id, razorpay_payment_id, razorpay_signature}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

String _url(Object? raw) {
  final v = '${raw ?? ''}'.trim();
  if (v.isEmpty || v == 'null') return '';
  if (v.startsWith('http')) return v;
  return 'https://api.qnxmartb2b.com/${v.startsWith('/') ? v.substring(1) : v}';
}

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _i(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

class MyProperty {
  final int id;
  final String slug;
  final String title;
  final String propertyType;
  final String transactionType;
  final String city;
  final String area;
  final String status; // draft | active | …
  final bool approved;
  final String source; // website | admin
  final String image;
  final bool subscriptionRequired;
  final bool subscriptionActive;
  final DateTime? freeExpiry;
  final DateTime? subscriptionExpiry;
  final int views;
  final int enquiries;
  final DateTime? createdAt;

  const MyProperty({
    required this.id,
    required this.slug,
    required this.title,
    required this.propertyType,
    required this.transactionType,
    required this.city,
    required this.area,
    required this.status,
    required this.approved,
    required this.source,
    required this.image,
    required this.subscriptionRequired,
    required this.subscriptionActive,
    required this.freeExpiry,
    required this.subscriptionExpiry,
    required this.views,
    required this.enquiries,
    required this.createdAt,
  });

  factory MyProperty.fromJson(Map<String, dynamic> j) {
    String img = '';
    final imgs = j['images'];
    if (imgs is List) {
      for (final m in imgs.whereType<Map>()) {
        final u = _url(m['image_s3_key'] ?? m['image']);
        if (u.isNotEmpty) {
          if (m['is_primary'] == true || img.isEmpty) img = u;
        }
      }
    }
    return MyProperty(
      id: _i(j['id']),
      slug: '${j['slug'] ?? ''}',
      title: '${j['title'] ?? ''}',
      propertyType: '${j['property_type'] ?? ''}',
      transactionType: '${j['transaction_type'] ?? ''}',
      city: '${j['city'] ?? ''}',
      area: '${j['area'] ?? ''}',
      status: '${j['status'] ?? ''}',
      approved: j['status_approved'] == true,
      source: '${j['source'] ?? 'website'}',
      image: img,
      subscriptionRequired: j['subscription_required'] == true,
      subscriptionActive: j['subscription_active'] == true,
      freeExpiry: DateTime.tryParse('${j['free_expiry_date'] ?? ''}'),
      subscriptionExpiry: DateTime.tryParse('${j['subscription_expiry_date'] ?? ''}'),
      views: _i(j['views_count']),
      enquiries: _i(j['enquiry_count']),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
    );
  }

  String get location => [area, city].where((s) => s.trim().isNotEmpty).join(', ');

  /// Listing is visible: free period running or a paid subscription active.
  bool get isRunning {
    final now = DateTime.now();
    if (source == 'admin') return true;
    if (subscriptionActive && (subscriptionExpiry == null || subscriptionExpiry!.isAfter(now))) return true;
    if (freeExpiry != null && freeExpiry!.isAfter(now)) return true;
    return !subscriptionRequired && freeExpiry == null;
  }

  /// Days left in the current free / paid period (null = unknown).
  int? get daysLeft {
    final now = DateTime.now();
    final end = subscriptionActive ? subscriptionExpiry : freeExpiry;
    if (end == null) return null;
    final d = end.difference(now).inHours / 24;
    return d <= 0 ? 0 : d.ceil();
  }

  bool get canPay => source != 'admin' && !(subscriptionActive && isRunning);
}

class PropertyPlan {
  final int id;
  final String name;
  final int days;
  final double price;
  const PropertyPlan({required this.id, required this.name, required this.days, required this.price});

  factory PropertyPlan.fromJson(Map<String, dynamic> j) =>
      PropertyPlan(id: _i(j['id']), name: '${j['name'] ?? 'Plan'}', days: _i(j['days']), price: _d(j['price']));
}

class MyPropertyResult<T> {
  final bool ok;
  final String message;
  final T? data;
  const MyPropertyResult(this.ok, this.message, [this.data]);
}

class MyPropertyService {
  static Future<(int, Map<String, dynamic>)> _post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (auth && (token == null || token.isEmpty)) return (401, <String, dynamic>{'message': 'Please log in to continue.'});
    final res = await http
        .post(
      Uri.parse('${ApiUrls.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 30));
    try {
      final d = jsonDecode(res.body);
      return (res.statusCode, d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{});
    } catch (_) {
      return (res.statusCode, <String, dynamic>{'message': 'Server error (${res.statusCode}).'});
    }
  }

  static String _err(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException')) return 'Could not reach the server.';
    if (e is TimeoutException) return 'The server took too long to respond.';
    return s.replaceFirst('Exception: ', '');
  }

  static String _msg(int code, Map<String, dynamic> j, String fb) =>
      code == 401 ? 'Your session has expired. Please log in again.' : '${j['message'] ?? j['detail'] ?? j['error'] ?? fb}';

  static Future<MyPropertyResult<List<MyProperty>>> myProperties() async {
    try {
      final (code, j) = await _post('/real_estate/my/properties/', {});
      if (code >= 300 || j['status'] == false || j['success'] == false) {
        return MyPropertyResult(false, _msg(code, j, 'Could not load your properties'), const []);
      }
      final list = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => MyProperty.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return MyPropertyResult(true, '', list);
    } catch (e) {
      return MyPropertyResult(false, _err(e), const []);
    }
  }

  static Future<MyPropertyResult<List<PropertyPlan>>> plans() async {
    try {
      final (code, j) = await _post('/payment/property-subscription-plan/list/', {}, auth: false);
      if (code >= 300 || j['success'] == false) return MyPropertyResult(false, _msg(code, j, 'Could not load plans'), const []);
      final list = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PropertyPlan.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id > 0)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));
      return MyPropertyResult(true, '', list);
    } catch (e) {
      return MyPropertyResult(false, _err(e), const []);
    }
  }

  /// → {order_id, key, amount_paise, plan_name}
  static Future<MyPropertyResult<Map<String, dynamic>>> createOrder(int propertyId, int planId) async {
    try {
      final (code, j) = await _post('/payment/property-subscription/create-order/', {
        'property_id': propertyId,
        'plan_id': planId,
      });
      if (code >= 300 || j['success'] != true || j['data'] is! Map) {
        return MyPropertyResult(false, _msg(code, j, 'Could not start the payment'));
      }
      final d = Map<String, dynamic>.from(j['data']);
      return MyPropertyResult(true, '', {
        'order_id': '${d['razorpay_order_id'] ?? ''}',
        'key': '${d['razorpay_key'] ?? ''}',
        'amount_paise': (_d(d['amount']) * 100).round(),
        'plan_name': '${d['plan_name'] ?? ''}',
      });
    } catch (e) {
      return MyPropertyResult(false, _err(e));
    }
  }

  static Future<MyPropertyResult<void>> verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final (code, j) = await _post('/payment/property-subscription/verify/', {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      if (code >= 300 || j['success'] != true) return MyPropertyResult(false, _msg(code, j, 'Payment could not be verified'));
      return MyPropertyResult(true, '${j['message'] ?? 'Subscription activated'}');
    } catch (e) {
      return MyPropertyResult(false, _err(e));
    }
  }
}
