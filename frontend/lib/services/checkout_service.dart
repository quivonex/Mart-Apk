// lib/services/checkout_service.dart
//
// Checkout = the website's flow, endpoint for endpoint:
//   POST order/address/list/            {}                                -> {status, data:[Address]}
//   POST order/address/create/          {full_name, mobile_no, address_line1, …, pincode}
//   POST shiprocket/create-order/       {product_id, address_id, quantity, payment_method: COD|PREPAID, notes}
//        -> {success, data:{order_id, order_number, subtotal, shipping_charge, total_amount, …}}
//        (one ShipOrder per product; courier + shipping charge chosen by the backend)
//   POST payment/razorpay/create-order/ {ship_order_id} -> {success, data:{razorpay_order_id, amount(paise), key_id}}
//   POST payment/razorpay/verify-payment/ {ship_order_id, razorpay_order_id, razorpay_payment_id, razorpay_signature}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _i(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

class DeliveryAddress {
  final int id;
  final String fullName;
  final String mobile;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String district;
  final String taluka;
  final String village;
  final String pincode;

  DeliveryAddress({
    required this.id,
    required this.fullName,
    required this.mobile,
    required this.line1,
    this.line2 = '',
    required this.city,
    required this.state,
    this.district = '',
    this.taluka = '',
    this.village = '',
    required this.pincode,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> j) => DeliveryAddress(
    id: _i(j['id']),
    fullName: _s(j['full_name']),
    mobile: _s(j['mobile_no']),
    line1: _s(j['address_line1']),
    line2: _s(j['address_line2']),
    city: _s(j['city']),
    state: _s(j['state']),
    district: _s(j['district']),
    taluka: _s(j['taluka']),
    village: _s(j['village']),
    pincode: _s(j['pincode']),
  );

  String get oneLine => [line1, line2, village, city, district, state]
      .where((x) => x.trim().isNotEmpty)
      .toSet()
      .join(', ');
}

class PlacedOrder {
  final int orderId; // ShipOrder id
  final String orderNumber;
  final String productName;
  final int quantity;
  final double subtotal;
  final double shipping;
  final double total;
  final String paymentMethod; // COD | PREPAID
  bool paid;

  PlacedOrder({
    required this.orderId,
    required this.orderNumber,
    required this.productName,
    required this.quantity,
    required this.subtotal,
    required this.shipping,
    required this.total,
    required this.paymentMethod,
    this.paid = false,
  });

  factory PlacedOrder.fromJson(Map<String, dynamic> j) => PlacedOrder(
    orderId: _i(j['order_id']),
    orderNumber: _s(j['order_number']),
    productName: _s(j['product']),
    quantity: _i(j['quantity']),
    subtotal: _d(j['subtotal']),
    shipping: _d(j['shipping_charge']),
    total: _d(j['total_amount']),
    paymentMethod: _s(j['payment_method']).toUpperCase(),
    paid: j['payment_status'] == true,
  );
}

class CheckoutResult<T> {
  final bool ok;
  final String message;
  final T? data;
  CheckoutResult(this.ok, this.message, [this.data]);
}

class CheckoutService {
  static Future<(int, Map<String, dynamic>)> _post(String path, Map<String, dynamic> body) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) {
      return (401, <String, dynamic>{'message': 'Please log in to continue.'});
    }
    final res = await http
        .post(
      Uri.parse('${ApiUrls.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 45));
    try {
      final d = jsonDecode(res.body);
      return (res.statusCode, d is Map<String, dynamic> ? d : <String, dynamic>{});
    } catch (_) {
      return (res.statusCode, <String, dynamic>{'message': 'Server error (${res.statusCode}).'});
    }
  }

  static String _err(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException')) return 'Could not reach the server.';
    if (e is TimeoutException) return 'The server took too long to respond.';
    return 'Something went wrong: $s';
  }

  static String _msg(Map<String, dynamic> j, String fallback) {
    final errors = j['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final k = errors.keys.first.toString();
      final v = errors[k];
      final t = v is List && v.isNotEmpty ? v.first.toString() : v.toString();
      return '${k.replaceAll('_', ' ')}: $t';
    }
    return (j['message'] ?? j['error'] ?? fallback).toString();
  }

  static bool _ok(int code, Map<String, dynamic> j) =>
      code >= 200 && code < 300 && (j['success'] == true || j['status'] == 'success' || j['status'] == true);

  // ── Addresses ───────────────────────────────────────────
  static Future<CheckoutResult<List<DeliveryAddress>>> addresses() async {
    try {
      final (code, j) = await _post('/order/address/list/', {});
      if (!_ok(code, j)) return CheckoutResult(false, _msg(j, 'Could not load addresses'), const []);
      final list = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => DeliveryAddress.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return CheckoutResult(true, '', list);
    } catch (e) {
      return CheckoutResult(false, _err(e), const []);
    }
  }

  static Future<CheckoutResult<DeliveryAddress>> addAddress(Map<String, String> fields) async {
    try {
      final (code, j) = await _post('/order/address/create/', {...fields, 'country': 'India'});
      if (!_ok(code, j) || j['data'] is! Map) return CheckoutResult(false, _msg(j, 'Could not save address'));
      return CheckoutResult(true, 'Address saved', DeliveryAddress.fromJson(Map<String, dynamic>.from(j['data'])));
    } catch (e) {
      return CheckoutResult(false, _err(e));
    }
  }

  // ── Orders ──────────────────────────────────────────────
  static Future<CheckoutResult<PlacedOrder>> placeOrder({
    required int productId,
    required int addressId,
    required int quantity,
    required bool cod,
    String notes = '',
  }) async {
    try {
      final (code, j) = await _post('/shiprocket/create-order/', {
        'product_id': productId,
        'address_id': addressId,
        'quantity': quantity,
        'payment_method': cod ? 'COD' : 'PREPAID',
        'notes': notes,
      });
      if (!_ok(code, j) || j['data'] is! Map) return CheckoutResult(false, _msg(j, 'Could not place the order'));
      return CheckoutResult(true, 'Order placed', PlacedOrder.fromJson(Map<String, dynamic>.from(j['data'])));
    } catch (e) {
      return CheckoutResult(false, _err(e));
    }
  }

  // ── Online payment (per ShipOrder) ─────────────────────
  static Future<CheckoutResult<Map<String, dynamic>>> createPayment(int shipOrderId) async {
    try {
      final (code, j) = await _post('/payment/razorpay/create-order/', {'ship_order_id': shipOrderId});
      if (!_ok(code, j) || j['data'] is! Map) {
        return CheckoutResult(false, _msg(j, 'Could not start payment'),
            j['data'] is Map ? Map<String, dynamic>.from(j['data']) : null);
      }
      return CheckoutResult(true, '', Map<String, dynamic>.from(j['data']));
    } catch (e) {
      return CheckoutResult(false, _err(e));
    }
  }

  static Future<CheckoutResult<void>> verifyPayment({
    required int shipOrderId,
    required String razorpayOrderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final (code, j) = await _post('/payment/razorpay/verify-payment/', {
        'ship_order_id': shipOrderId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      return _ok(code, j)
          ? CheckoutResult(true, (j['message'] ?? 'Payment verified').toString())
          : CheckoutResult(false, _msg(j, 'Payment could not be verified'));
    } catch (e) {
      return CheckoutResult(false, _err(e));
    }
  }
}