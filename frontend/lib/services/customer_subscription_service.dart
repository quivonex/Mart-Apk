// lib/services/customer_subscription_service.dart
//
// Customer subscription (needed to send enquiries on user-posted properties).
//
//   POST payment/customer-subscription-plans/          {}          -> {success, data:[plan]}
//   POST payment/customer-subscription/create-order/   {plan_id}   (login)
//        -> {success, payment_record_id, order:{razorpay_order_id, amount_paise, …}, razorpay:{key_id}}
//   POST payment/customer-subscription/verify-payment/ {razorpay_order_id, razorpay_payment_id, razorpay_signature}
//        -> {success, subscription:{…}}
//   POST payment/customer-subscriptions/my/            {}          (login)
//        -> {success, current_subscription, subscriptions:[…]}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _i(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

class CustomerPlan {
  final int id;
  final String name;
  final double price;
  final int enquiryLimit;
  final int durationDays;

  const CustomerPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.enquiryLimit,
    required this.durationDays,
  });

  factory CustomerPlan.fromJson(Map<String, dynamic> j) => CustomerPlan(
    id: _i(j['id']),
    name: '${j['name'] ?? 'Plan'}',
    price: _d(j['price']),
    enquiryLimit: _i(j['enquiry_limit']),
    durationDays: _i(j['duration_days']),
  );
}

class CustomerSubscriptionInfo {
  final int id;
  final String planName;
  final double price;
  final int enquiryLimit;
  final int enquiryUsed;
  final int remaining;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // active | expired | inactive

  const CustomerSubscriptionInfo({
    required this.id,
    required this.planName,
    required this.price,
    required this.enquiryLimit,
    required this.enquiryUsed,
    required this.remaining,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  bool get isActive => status == 'active';

  factory CustomerSubscriptionInfo.fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] is Map ? Map<String, dynamic>.from(j['plan']) : const <String, dynamic>{};
    final limit = _i(j['enquiry_limit'] ?? plan['enquiry_limit']);
    final used = _i(j['enquiry_used']);
    return CustomerSubscriptionInfo(
      id: _i(j['subscription_id'] ?? j['id']),
      planName: '${plan['name'] ?? j['plan_name'] ?? 'Plan'}',
      price: _d(j['price'] ?? plan['price']),
      enquiryLimit: limit,
      enquiryUsed: used,
      remaining: j['remaining_enquiries'] != null ? _i(j['remaining_enquiries']) : (limit - used).clamp(0, limit),
      startDate: DateTime.tryParse('${j['start_date'] ?? ''}'),
      endDate: DateTime.tryParse('${j['end_date'] ?? ''}'),
      status: '${j['status'] ?? (j['is_active'] == true ? 'active' : 'inactive')}',
    );
  }
}

class SubscriptionResult<T> {
  final bool ok;
  final String message;
  final T? data;
  const SubscriptionResult(this.ok, this.message, [this.data]);
}

class CustomerSubscriptionService {
  static Future<(int, Map<String, dynamic>)> _post(String path, Map<String, dynamic> body,
      {bool auth = true}) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (auth && (token == null || token.isEmpty)) {
      return (401, <String, dynamic>{'message': 'Please log in to continue.'});
    }
    final res = await http
        .post(
      Uri.parse('${ApiUrls.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (auth && token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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

  static String _msg(int code, Map<String, dynamic> j, String fallback) {
    if (code == 401) return 'Your session has expired. Please log in again.';
    return '${j['message'] ?? j['detail'] ?? j['error'] ?? fallback}';
  }

  static bool _ok(int code, Map<String, dynamic> j) => code >= 200 && code < 300 && j['success'] != false;

  /// Active plans (public).
  static Future<SubscriptionResult<List<CustomerPlan>>> plans() async {
    try {
      final (code, j) = await _post('/payment/customer-subscription-plans/', {}, auth: false);
      if (!_ok(code, j)) return SubscriptionResult(false, _msg(code, j, 'Could not load plans'), const []);
      final list = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CustomerPlan.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id > 0)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));
      return SubscriptionResult(true, '', list);
    } catch (e) {
      return SubscriptionResult(false, _err(e), const []);
    }
  }

  /// (current active subscription or null, history)
  static Future<SubscriptionResult<(CustomerSubscriptionInfo?, List<CustomerSubscriptionInfo>)>> mySubscriptions() async {
    try {
      final (code, j) = await _post('/payment/customer-subscriptions/my/', {});
      if (!_ok(code, j)) return SubscriptionResult(false, _msg(code, j, 'Could not load your subscriptions'));
      final cur = j['current_subscription'] is Map
          ? CustomerSubscriptionInfo.fromJson(Map<String, dynamic>.from(j['current_subscription']))
          : null;
      final all = (j['subscriptions'] as List? ?? [])
          .whereType<Map>()
          .map((e) => CustomerSubscriptionInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return SubscriptionResult(true, '', (cur, all));
    } catch (e) {
      return SubscriptionResult(false, _err(e));
    }
  }

  /// Razorpay order for [planId] → {order_id, amount_paise, key, plan_name}
  static Future<SubscriptionResult<Map<String, dynamic>>> createOrder(int planId) async {
    try {
      final (code, j) = await _post('/payment/customer-subscription/create-order/', {'plan_id': planId});
      if (!_ok(code, j)) return SubscriptionResult(false, _msg(code, j, 'Could not start the payment'));
      final o = j['order'] is Map ? Map<String, dynamic>.from(j['order']) : const <String, dynamic>{};
      final rz = j['razorpay'] is Map ? Map<String, dynamic>.from(j['razorpay']) : const <String, dynamic>{};
      return SubscriptionResult(true, '', {
        'order_id': '${o['razorpay_order_id'] ?? ''}',
        'amount_paise': _i(o['amount_paise']),
        'key': '${rz['key_id'] ?? j['razorpay_key'] ?? ''}',
        'plan_name': '${o['plan_name'] ?? ''}',
      });
    } catch (e) {
      return SubscriptionResult(false, _err(e));
    }
  }

  static Future<SubscriptionResult<void>> verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final (code, j) = await _post('/payment/customer-subscription/verify-payment/', {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      if (!_ok(code, j)) return SubscriptionResult(false, _msg(code, j, 'Payment could not be verified'));
      return SubscriptionResult(true, '${j['message'] ?? 'Subscription activated'}');
    } catch (e) {
      return SubscriptionResult(false, _err(e));
    }
  }
}
