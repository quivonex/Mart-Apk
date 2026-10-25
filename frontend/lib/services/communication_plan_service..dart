// lib/services/communication_plan_service.dart
//
// QNX ReMart Communication Plan (Authorization: Bearer <token> on every call)
//
//   POST olx/bazaar-communication-plans/list/          {}          -> {success, data:[plan]}
//   POST payment/bazaar-communication/create-order/    {plan_id}   -> {success, data:{razorpay_order_id,
//                                                                       razorpay_key_id, amount_in_paise, currency, plan_name}}
//   POST payment/bazaar-communication/verify-payment/  {razorpay_order_id, razorpay_payment_id, razorpay_signature}
//   POST olx/bazaar-communication-subscriptions/my/    {}          -> {success, count, data:[subscription]}
//   POST olx/bazaar-communication-usage/chat/          {}          -> {success, data:{unlimited, used, limit, remaining, …}}
//   POST olx/bazaar-communication-usage/enquiry/       {}          (same)
//
// 401 / 403 → token cleared (needsLogin). Usage errors are silent (null).
//
// Separate from the Customer Subscription (customer_subscription_service.dart).
// All endpoints come from ApiUrls (comm…Url).

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/communication_plan_models.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';
import 'package:qnx_mart/l10n/app_language.dart';

class CommunicationPlanService {
  CommunicationPlanService._();

  static const _timeout = Duration(seconds: 25);

  static Future<(int, dynamic)> _post(String url, Map<String, dynamic> body) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) return (401, <String, dynamic>{});
    final res = await http
        .post(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    )
        .timeout(_timeout);
    dynamic j;
    try {
      j = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      j = res.body;
    }
    return (res.statusCode, j);
  }

  static bool _okCode(int c) => c >= 200 && c < 300;

  /// Error text: detail → message → error → non_field_errors[0] → first list
  /// value → first short string value → [fallback].
  static String _errorText(dynamic body, String fallback) {
    if (body is Map) {
      for (final k in const ['detail', 'message', 'error']) {
        final v = body[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is List && v.isNotEmpty) return '${v.first}';
      }
      final nfe = body['non_field_errors'];
      if (nfe is List && nfe.isNotEmpty) return '${nfe.first}';
      for (final v in body.values) {
        if (v is List && v.isNotEmpty) return '${v.first}';
      }
      for (final v in body.values) {
        if (v is String && v.trim().isNotEmpty && v.length < 300) return v.trim();
      }
    }
    return fallback;
  }

  /// success:true / status:true (any 2xx without an explicit false).
  static bool _okBody(dynamic j) {
    if (j is! Map) return true;
    final s = j['success'] ?? j['status'];
    return s != false && '$s'.toLowerCase() != 'false';
  }

  static Future<CommResult<T>> _auth<T>(dynamic j) async {
    await SharedPreferencesHelper.clearAll();
    return CommResult<T>.fail(_errorText(j, tr('Session expired. Please login again.')), needsLogin: true);
  }

  static Future<CommResult<T>> _guard<T>(Future<CommResult<T>> Function() run, String fallback) async {
    try {
      return await run();
    } on TimeoutException {
      return CommResult<T>.fail(tr('The server is taking too long. Please try again.'));
    } catch (_) {
      return CommResult<T>.fail(fallback);
    }
  }

  static List<Map<String, dynamic>> _list(dynamic j) {
    final raw = j is Map ? (j['data'] ?? j['results']) : j;
    if (raw is! List) return const [];
    return [for (final e in raw.whereType<Map>()) Map<String, dynamic>.from(e)];
  }

  // ---------------------------------------------------------------- plans
  static Future<CommResult<List<CommPlan>>> plans() => _guard(() async {
    final (code, j) = await _post(ApiUrls.commPlansUrl, {});
    if (code == 401 || code == 403) return _auth<List<CommPlan>>(j);
    if (!_okCode(code) || !_okBody(j)) {
      return CommResult<List<CommPlan>>.fail(_errorText(j, tr('Unable to load plans.')));
    }
    final list = [for (final m in _list(j)) CommPlan.fromJson(m)].where((p) => p.id > 0).toList();
    return CommResult.ok(list);
  }, tr('Unable to load plans.'));

  // ---------------------------------------------------------------- my subscriptions
  static Future<CommResult<List<CommSubscription>>> mySubscriptions() => _guard(() async {
    final (code, j) = await _post(ApiUrls.commMySubscriptionsUrl, {});
    if (code == 401 || code == 403) return _auth<List<CommSubscription>>(j);
    if (!_okCode(code) || !_okBody(j)) {
      return CommResult<List<CommSubscription>>.fail(
          _errorText(j, tr('Unable to load your subscriptions.')));
    }
    final list = [for (final m in _list(j)) CommSubscription.fromJson(m)]
      ..sort((a, b) {
        if (a.currentlyValid != b.currentlyValid) return a.currentlyValid ? -1 : 1;
        final x = a.startsAt, y = b.startsAt;
        if (x == null || y == null) return b.id.compareTo(a.id);
        return y.compareTo(x);
      });
    return CommResult.ok(list);
  }, tr('Unable to load your subscriptions.'));

  // ---------------------------------------------------------------- usage (silent)
  static Future<CommUsage?> chatUsage() => _usage(ApiUrls.commChatUsageUrl);
  static Future<CommUsage?> enquiryUsage() => _usage(ApiUrls.commEnquiryUsageUrl);

  static Future<CommUsage?> _usage(String url) async {
    try {
      final (code, j) = await _post(url, {});
      if (!_okCode(code) || !_okBody(j) || j is! Map || j['data'] is! Map) return null;
      return CommUsage.fromJson(Map<String, dynamic>.from(j['data']));
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- create order
  static Future<CommResult<CommOrder>> createOrder(CommPlan plan) => _guard(() async {
    final (code, j) = await _post(ApiUrls.commCreateOrderUrl, {'plan_id': plan.id});
    if (code == 401 || code == 403) return _auth<CommOrder>(j);
    if (!_okCode(code) || !_okBody(j)) {
      return CommResult<CommOrder>.fail(_errorText(j, tr('Failed to create subscription order.')));
    }
    final d = (j is Map && j['data'] is Map) ? Map<String, dynamic>.from(j['data']) : <String, dynamic>{};
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = d[k] ?? (j is Map ? j[k] : null);
        if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
      }
      return '';
    }

    final orderId = pick(const ['razorpay_order_id', 'order_id']);
    final key = pick(const ['razorpay_key_id', 'razorpay_key', 'key_id', 'key']);
    if (orderId.isEmpty || key.isEmpty) {
      return CommResult<CommOrder>.fail(_errorText(j, tr('Failed to create subscription order.')));
    }
    final paise = int.tryParse(pick(const ['amount_in_paise', 'amount_paise', 'amount'])) ??
        (plan.price * 100).round();
    final currency = pick(const ['currency']);
    final name = pick(const ['plan_name']);
    return CommResult.ok(CommOrder(
      orderId: orderId,
      key: key,
      amountPaise: paise > 0 ? paise : (plan.price * 100).round(),
      currency: currency.isEmpty ? 'INR' : currency,
      planName: name.isEmpty ? plan.name : name,
    ));
  }, tr('Failed to create subscription order.'));

  // ---------------------------------------------------------------- verify
  static Future<CommResult<String>> verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) =>
      _guard(() async {
        final (code, j) = await _post(ApiUrls.commVerifyPaymentUrl, {
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        });
        if (code == 401 || code == 403) return _auth<String>(j);
        if (!_okCode(code) || !_okBody(j)) {
          return CommResult<String>.fail(_errorText(j, tr('Payment verification failed.')));
        }
        return CommResult.ok(_errorText(j, tr('Subscription activated successfully.')));
      }, tr('Payment verification failed.'));
}
