// lib/services/nearby_subscription_service.dart
//
// Subscription for "Nearby Search" (Google Places through the QNX backend).
// Every call needs the login token:  Authorization: Bearer <access token>
//
//   1. POST admin_profile/subscription-plans/list/                 {}
//        -> {status:true, data:[{id, name, price, duration_days, enquiry_limit}]}
//   2. POST admin_profile/subscription/create-order/              {plan_id:"2"}
//        -> {status:true, data:{order_id, razorpay_key, amount(paise), currency, plan{…}}}
//   3. POST admin_profile/place_subscription/sub_payment_verify/  {razorpay_order_id,
//        razorpay_payment_id, razorpay_signature}
//        -> {status:true, message:"Payment verified. Subscription activated."}
//
// One plan at a time:
//   After a successful payment the active plan (with its end date = today +
//   duration_days) is saved on this device for the logged-in user. While it is
//   active the plans are NOT offered again – they come back only after it expires.
//   If the backend ever answers the nearby search with 403 subscription_required,
//   the saved plan is cleared (the server is always right).
//   If the plans API returns an active/owned flag or an active_subscription
//   object, that is used instead of the saved copy (see README).

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? double.tryParse('${v ?? ''}')?.toInt() ?? 0;
bool _b(dynamic v) => v == true || v == 1 || '$v'.toLowerCase() == 'true' || '$v'.toLowerCase() == 'active';
DateTime? _date(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  if (s.isEmpty || s == 'null') return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso.toLocal();
  // dd-MM-yyyy or dd/MM/yyyy
  final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(s);
  if (m != null) {
    return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!), 23, 59, 59);
  }
  return null;
}

/// "₹ 1,299.00" (Indian grouping).
String nearbyRupees(double v) {
  final neg = v < 0;
  final parts = v.abs().toStringAsFixed(2).split('.');
  var w = parts[0];
  if (w.length > 3) {
    final last3 = w.substring(w.length - 3);
    var rest = w.substring(0, w.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    w = '${groups.join(',')},$last3';
  }
  return '${neg ? '-' : ''}₹ $w.${parts[1]}';
}

/// "21 Oct 2026"
String nearbyDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

// ============================================================ models
class NearbyPlan {
  final String id;
  final String name;
  final double price;
  final int durationDays;
  final int enquiryLimit;

  /// Optional backend flag (owned / is_active / active / is_subscribed / current).
  final bool owned;

  /// Optional backend end date for an owned plan.
  final DateTime? expiresAt;

  const NearbyPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.enquiryLimit,
    this.owned = false,
    this.expiresAt,
  });

  String get priceLabel => nearbyRupees(price);

  String get durationLabel {
    final d = durationDays;
    if (d <= 0) return '';
    if (d % 365 == 0) return d == 365 ? '1 year' : '${d ~/ 365} years';
    if (d % 30 == 0) return d == 30 ? '1 month' : '${d ~/ 30} months';
    return d == 1 ? '1 day' : '$d days';
  }

  /// "Valid until" if bought today.
  DateTime get validUntilIfBoughtNow => DateTime.now().add(Duration(days: durationDays));

  factory NearbyPlan.fromJson(Map<String, dynamic> j) => NearbyPlan(
    id: '${j['id'] ?? j['plan_id'] ?? ''}',
    name: '${j['name'] ?? j['plan_name'] ?? 'Plan'}',
    price: _d(j['price'] ?? j['amount']),
    durationDays: _i(j['duration_days'] ?? j['duration']),
    enquiryLimit: _i(j['enquiry_limit'] ?? j['search_limit']),
    owned: _b(j['owned'] ?? j['is_owned'] ?? j['is_active'] ?? j['active'] ?? j['is_subscribed'] ?? j['current']),
    expiresAt: _date(j['expires_at'] ?? j['end_date'] ?? j['expiry_date'] ?? j['valid_till'] ?? j['valid_until']),
  );
}

/// The plan the user is currently on (or was on, when expired).
class NearbyActiveSub {
  final String planId;
  final String planName;
  final double price;
  final int durationDays;
  final int enquiryLimit;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String orderId;

  const NearbyActiveSub({
    required this.planId,
    required this.planName,
    required this.price,
    required this.durationDays,
    required this.enquiryLimit,
    required this.startedAt,
    required this.expiresAt,
    this.orderId = '',
  });

  bool get isActive => DateTime.now().isBefore(expiresAt);

  /// Whole days left (today counts when some time is left).
  int get daysLeft {
    final left = expiresAt.difference(DateTime.now());
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  /// 0..1 of the period already used.
  double get usedFraction {
    final total = expiresAt.difference(startedAt).inSeconds;
    if (total <= 0) return 1;
    return (DateTime.now().difference(startedAt).inSeconds / total).clamp(0.0, 1.0);
  }

  factory NearbyActiveSub.fromPlan(NearbyPlan p, {String orderId = '', DateTime? start}) {
    final s = start ?? DateTime.now();
    return NearbyActiveSub(
      planId: p.id,
      planName: p.name,
      price: p.price,
      durationDays: p.durationDays,
      enquiryLimit: p.enquiryLimit,
      startedAt: s,
      expiresAt: s.add(Duration(days: p.durationDays)),
      orderId: orderId,
    );
  }

  Map<String, dynamic> toJson() => {
    'plan_id': planId,
    'plan_name': planName,
    'price': price,
    'duration_days': durationDays,
    'enquiry_limit': enquiryLimit,
    'started_at': startedAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'order_id': orderId,
  };

  /// Reads our saved copy and the optional backend object
  /// ({plan:{…}|plan_id, plan_name, start_date, end_date, …}).
  static NearbyActiveSub? fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] is Map ? Map<String, dynamic>.from(j['plan']) : const <String, dynamic>{};
    final end = _date(j['expires_at'] ?? j['end_date'] ?? j['expiry_date'] ?? j['valid_till'] ?? j['valid_until']);
    if (end == null) return null;
    final days = _i(j['duration_days'] ?? plan['duration_days']);
    final start = _date(j['started_at'] ?? j['start_date'] ?? j['created_at']) ??
        end.subtract(Duration(days: days > 0 ? days : 30));
    return NearbyActiveSub(
      planId: '${j['plan_id'] ?? plan['id'] ?? (j['plan'] is Map ? '' : j['plan']) ?? ''}',
      planName: '${j['plan_name'] ?? plan['name'] ?? 'Plan'}',
      price: _d(j['price'] ?? plan['price']),
      durationDays: days,
      enquiryLimit: _i(j['enquiry_limit'] ?? plan['enquiry_limit']),
      startedAt: start,
      expiresAt: end,
      orderId: '${j['order_id'] ?? ''}',
    );
  }
}

class NearbyOrder {
  final String orderId;
  final String key;
  final int amountPaise;
  final String currency;
  final NearbyPlan plan;

  const NearbyOrder({
    required this.orderId,
    required this.key,
    required this.amountPaise,
    required this.currency,
    required this.plan,
  });
}

/// Result of one API call.
class NearbyApiResult<T> {
  final bool ok;
  final String message;
  final T? data;

  /// 401 – token removed, user must log in again.
  final bool needsLogin;

  const NearbyApiResult._(this.ok, this.message, this.data, this.needsLogin);
  const NearbyApiResult.ok(T value, [String message = '']) : this._(true, message, value, false);
  const NearbyApiResult.fail(String message, {bool needsLogin = false}) : this._(false, message, null, needsLogin);
}

class NearbyPlansData {
  final List<NearbyPlan> plans;

  /// Active plan reported by the backend (null when the backend does not send one).
  final NearbyActiveSub? serverActive;
  const NearbyPlansData(this.plans, this.serverActive);
}

// ============================================================ local store
/// Saved active plan, one per logged-in user, on this device.
class NearbySubscriptionStore {
  NearbySubscriptionStore._();

  static Future<String> _key() async {
    final id = await SharedPreferencesHelper.getUserId();
    final name = await SharedPreferencesHelper.getUsername();
    final who = id != null ? '$id' : (name != null && name.isNotEmpty ? name : 'guest');
    return 'nearby_subscription_$who';
  }

  /// Last saved plan (active OR expired). Use [NearbyActiveSub.isActive].
  static Future<NearbyActiveSub?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(await _key());
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw);
      return j is Map ? NearbyActiveSub.fromJson(Map<String, dynamic>.from(j)) : null;
    } catch (_) {
      return null;
    }
  }

  /// Active plan or null (expired plans return null).
  static Future<NearbyActiveSub?> active() async {
    final s = await load();
    return (s != null && s.isActive) ? s : null;
  }

  static Future<void> save(NearbyActiveSub sub) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _key(), jsonEncode(sub.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _key());
  }

  /// Backend said "no active subscription" → forget an active copy
  /// (an already expired copy is kept to show "expired on …").
  static Future<void> serverSaysNone() async {
    final s = await load();
    if (s != null && s.isActive) await clear();
  }
}

// ============================================================ API
class NearbySubscriptionService {
  NearbySubscriptionService._();

  static const _timeout = Duration(seconds: 30);

  static Future<(int, Map<String, dynamic>)?> _post(String url, Map<String, dynamic> body) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) return (401, <String, dynamic>{});
    final res = await http
        .post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    )
        .timeout(_timeout);
    Map<String, dynamic> j = {};
    try {
      final d = jsonDecode(res.body);
      if (d is Map) j = Map<String, dynamic>.from(d);
    } catch (_) {
      if (_okCode(res.statusCode)) return null; // HTML / broken JSON
    }
    return (res.statusCode, j);
  }

  /// Django often answers 201 Created – any 2xx is success.
  static bool _okCode(int code) => code >= 200 && code < 300;

  static String _msg(Map<String, dynamic> j, String fallback) {
    final m = j['message'] ?? j['detail'] ?? j['error'];
    final s = m == null ? '' : '$m'.trim();
    return s.isEmpty ? fallback : s;
  }

  static Future<NearbyApiResult<T>> _guard<T>(Future<NearbyApiResult<T>> Function() run) async {
    try {
      return await run();
    } on TimeoutException {
      return NearbyApiResult<T>.fail('The server is taking too long. Please try again.');
    } catch (e) {
      final s = e.toString();
      return NearbyApiResult<T>.fail(
        s.contains('SocketException') || s.contains('ClientException')
            ? 'Could not reach the server. Check your internet connection.'
            : 'Something went wrong: $s',
      );
    }
  }

  /// 401 → token is removed so the app asks for login again.
  static Future<NearbyApiResult<T>> _sessionExpired<T>(Map<String, dynamic> j) async {
    await SharedPreferencesHelper.clearAll();
    return NearbyApiResult<T>.fail(_msg(j, 'Your session has expired. Please log in again.'), needsLogin: true);
  }

  // ---------------------------------------------------------- 1. plans
  static Future<NearbyApiResult<NearbyPlansData>> plans() => _guard(() async {
    final r = await _post(ApiUrls.nearbySubscriptionPlansUrl, {});
    if (r == null) return NearbyApiResult.fail('Server error. Please try again.');
    final (code, j) = r;
    if (code == 401) return _sessionExpired(j);
    if (code == 403) return NearbyApiResult.fail(_msg(j, 'You are not allowed to view plans.'));
    if (!_okCode(code) || (j['status'] ?? j['success']) == false || j['data'] is! List) {
      return NearbyApiResult.fail(_msg(j, 'Unable to load plans.'));
    }
    final plans = [
      for (final e in (j['data'] as List).whereType<Map>()) NearbyPlan.fromJson(Map<String, dynamic>.from(e)),
    ].where((p) => p.id.isNotEmpty).toList();

    // Optional: backend tells us which plan is active.
    NearbyActiveSub? server;
    for (final k in ['active_subscription', 'current_subscription', 'subscription']) {
      if (j[k] is Map) {
        server = NearbyActiveSub.fromJson(Map<String, dynamic>.from(j[k]));
        if (server != null) break;
      }
    }
    if (server == null) {
      for (final p in plans) {
        if (p.owned && p.expiresAt != null) {
          final start = p.expiresAt!.subtract(Duration(days: p.durationDays));
          server = NearbyActiveSub(
            planId: p.id,
            planName: p.name,
            price: p.price,
            durationDays: p.durationDays,
            enquiryLimit: p.enquiryLimit,
            startedAt: start,
            expiresAt: p.expiresAt!,
          );
          break;
        }
      }
    }
    if (server != null && server.isActive) await NearbySubscriptionStore.save(server);
    return NearbyApiResult.ok(NearbyPlansData(plans, server));
  });

  // ---------------------------------------------------------- 2. create order
  static Future<NearbyApiResult<NearbyOrder>> createOrder(NearbyPlan plan) => _guard(() async {
    final r = await _post(ApiUrls.nearbySubscriptionCreateOrderUrl, {'plan_id': plan.id});
    if (r == null) return NearbyApiResult.fail('Server error. Please try again.');
    final (code, j) = r;
    if (code == 401) return _sessionExpired(j);
    // Backends differ – look for the fields at the top level, in data,
    // and in data.order / data.razorpay / order / razorpay.
    final maps = _orderMaps(j);
    final orderId = _pick(maps, const ['order_id', 'razorpay_order_id', 'rzp_order_id', 'id']);
    final key = _pick(maps, const ['razorpay_key', 'razorpay_key_id', 'key_id', 'key', 'rzp_key']);
    final st = j['status'] ?? j['success'];
    final failed = !_okCode(code) || st == false || '$st'.toLowerCase() == 'false' || '$st'.toLowerCase() == 'error';
    if (failed) return NearbyApiResult.fail(_msg(j, 'Unable to create order.'));
    if (orderId.isEmpty || key.isEmpty) {
      final got = maps.expand((m) => m.keys).toSet().join(', ');
      return NearbyApiResult.fail(
          'Order was created but the response has no ${orderId.isEmpty ? 'order_id' : ''}'
              '${orderId.isEmpty && key.isEmpty ? ' / ' : ''}${key.isEmpty ? 'razorpay_key' : ''}.\n'
              'Fields received: $got');
    }
    final d = maps.length > 1 ? maps[1] : j;
    final echo = d['plan'] is Map ? Map<String, dynamic>.from(d['plan']) : null;
    final p = echo == null
        ? plan
        : NearbyPlan(
      id: '${echo['id'] ?? plan.id}',
      name: '${echo['name'] ?? plan.name}',
      price: plan.price,
      durationDays: echo['duration_days'] == null ? plan.durationDays : _i(echo['duration_days']),
      enquiryLimit: echo['enquiry_limit'] == null ? plan.enquiryLimit : _i(echo['enquiry_limit']),
    );
    // amount is paise; if the backend sent rupees (= plan price) convert it.
    final paise = _d(_pick(maps, const ['amount_paise', 'amount_in_paise']));
    final amt = _d(_pick(maps, const ['amount']));
    int amountPaise;
    if (paise > 0) {
      amountPaise = paise.round();
    } else if (amt > 0) {
      amountPaise = (plan.price > 0 && (amt - plan.price).abs() < 0.01 && plan.price < 100000)
          ? (amt * 100).round()
          : amt.round();
    } else {
      amountPaise = (plan.price * 100).round();
    }
    final currency = _pick(maps, const ['currency']);
    return NearbyApiResult.ok(NearbyOrder(
      orderId: orderId,
      key: key,
      amountPaise: amountPaise,
      currency: currency.isEmpty ? 'INR' : currency,
      plan: p,
    ));
  });

  /// [top, data, data.order, data.razorpay, order, razorpay, …] – whichever exist.
  static List<Map<String, dynamic>> _orderMaps(Map<String, dynamic> j) {
    final out = <Map<String, dynamic>>[j];
    Map<String, dynamic>? m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    final data = m(j['data']);
    if (data != null) out.add(data);
    for (final src in [if (data != null) data, j]) {
      for (final k in const ['order', 'razorpay_order', 'razorpay', 'payment']) {
        final sub = m(src[k]);
        if (sub != null) out.add(sub);
      }
    }
    return out;
  }

  /// First non-empty value for any of [keys]. 'id' is used only when it looks
  /// like a Razorpay order id ("order_…"), not a payment-record id.
  static String _pick(List<Map<String, dynamic>> maps, List<String> keys) {
    for (final k in keys) {
      for (var i = 0; i < maps.length; i++) {
        final v = maps[i][k];
        if (v == null || v is Map || v is List) continue;
        final t = '$v'.trim();
        if (t.isEmpty || t == 'null') continue;
        if (k == 'id' && !t.startsWith('order_')) continue;
        return t;
      }
    }
    return '';
  }

  // ---------------------------------------------------------- 3. verify
  /// On success the plan is saved as active (today + duration_days).
  static Future<NearbyApiResult<NearbyActiveSub>> verify({
    required NearbyOrder order,
    required String paymentId,
    required String signature,
    String? razorpayOrderId,
  }) =>
      _guard(() async {
        final r = await _post(ApiUrls.nearbySubscriptionVerifyUrl, {
          'razorpay_order_id': (razorpayOrderId == null || razorpayOrderId.isEmpty) ? order.orderId : razorpayOrderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        });
        if (r == null) return NearbyApiResult.fail('Server error while confirming payment.');
        final (code, j) = r;
        if (code == 401) return _sessionExpired(j);
        final st = j['status'] ?? j['success'];
        final good = st == true || '$st'.toLowerCase() == 'true' || '$st'.toLowerCase() == 'success';
        if (!_okCode(code) || !good) {
          return NearbyApiResult.fail(_msg(j, 'Signature verification failed.'));
        }
        // Prefer dates from the backend when it sends them.
        final d = j['data'] is Map ? Map<String, dynamic>.from(j['data']) : j;
        final raw = d['subscription'] is Map ? Map<String, dynamic>.from(d['subscription']) : d;
        final fromServer = NearbyActiveSub.fromJson(raw);
        final p = order.plan;
        final sub = (fromServer != null && fromServer.isActive)
            ? NearbyActiveSub(
          planId: p.id,
          planName: p.name,
          price: p.price,
          durationDays: p.durationDays,
          enquiryLimit: p.enquiryLimit,
          startedAt: fromServer.startedAt,
          expiresAt: fromServer.expiresAt,
          orderId: order.orderId,
        )
            : NearbyActiveSub.fromPlan(p, orderId: order.orderId);
        await NearbySubscriptionStore.save(sub);
        return NearbyApiResult.ok(sub, _msg(j, 'Payment verified. Subscription activated.'));
      });
}
