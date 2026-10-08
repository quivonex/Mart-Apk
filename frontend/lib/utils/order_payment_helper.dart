// lib/utils/order_payment_helper.dart
//
// Pays one ShipOrder online (used by Checkout and by "Pay now" in My Orders):
//   payment/razorpay/create-order/ -> Razorpay checkout -> payment/razorpay/verify-payment/
// On success the backend marks the order paid and CONFIRMED.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/checkout_service.dart';
import 'shared_preferences_helper.dart';

enum OrderPayOutcome { paid, cancelled, failed }

class OrderPaymentHelper {
  OrderPaymentHelper._();

  static bool _busy = false;

  static Future<OrderPayOutcome> pay(
      BuildContext context, {
        required int shipOrderId,
        required String description,
        String? phone,
      }) async {
    if (_busy) return OrderPayOutcome.failed;
    _busy = true;
    try {
      return await _run(context, shipOrderId, description, phone);
    } finally {
      _busy = false;
    }
  }

  static void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? const Color(0xFFDC2626) : null));
  }

  static Future<OrderPayOutcome> _run(
      BuildContext context, int shipOrderId, String description, String? phone) async {
    if (kIsWeb) {
      _snack(context, 'Online payment works in the QNXMart Android app. Open My Orders there to pay.');
      return OrderPayOutcome.failed;
    }

    final created = await CheckoutService.createPayment(shipOrderId);
    if (!context.mounted) return OrderPayOutcome.failed;
    if (!created.ok) {
      // Backend answers "Payment already completed." when it was paid before.
      if (created.message.toLowerCase().contains('already completed')) return OrderPayOutcome.paid;
      _snack(context, created.message, error: true);
      return OrderPayOutcome.failed;
    }
    final d = created.data!;
    final rzpOrderId = '${d['razorpay_order_id'] ?? ''}';
    final key = '${d['key_id'] ?? ''}';
    final amount = d['amount'] is int ? d['amount'] as int : int.tryParse('${d['amount']}') ?? 0;
    if (rzpOrderId.isEmpty || key.isEmpty || amount <= 0) {
      _snack(context, 'Payment could not be started. Please try again.', error: true);
      return OrderPayOutcome.failed;
    }

    final email = await SharedPreferencesHelper.getUserEmail();
    final razorpay = Razorpay();
    final done = Completer<(PaymentSuccessResponse?, PaymentFailureResponse?)>();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!done.isCompleted) done.complete((r, null));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!done.isCompleted) done.complete((null, r));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      if (!done.isCompleted) done.complete((null, null));
    });

    try {
      razorpay.open({
        'key': key,
        'amount': amount,
        'currency': 'INR',
        'order_id': rzpOrderId,
        'name': 'QNX Mart',
        'description': description,
        'prefill': {
          if (phone != null && phone.isNotEmpty) 'contact': phone,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        'theme': {'color': '#1A68FA'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      razorpay.clear();
      if (context.mounted) _snack(context, 'Could not open payment: $e', error: true);
      return OrderPayOutcome.failed;
    }

    final (success, failure) = await done.future;
    razorpay.clear();
    if (!context.mounted) return OrderPayOutcome.failed;

    if (success == null) {
      if (failure != null && failure.code == Razorpay.PAYMENT_CANCELLED) {
        _snack(context, 'Payment cancelled. You can pay later from My Orders.');
        return OrderPayOutcome.cancelled;
      }
      _snack(context, failure?.message?.isNotEmpty == true ? 'Payment failed: ${failure!.message}' : 'Payment failed.',
          error: true);
      return OrderPayOutcome.failed;
    }

    final verify = await CheckoutService.verifyPayment(
      shipOrderId: shipOrderId,
      razorpayOrderId: success.orderId ?? rzpOrderId,
      paymentId: success.paymentId ?? '',
      signature: success.signature ?? '',
    );
    if (!context.mounted) return verify.ok ? OrderPayOutcome.paid : OrderPayOutcome.failed;
    if (verify.ok) return OrderPayOutcome.paid;
    _snack(
      context,
      '${verify.message}\nIf money was deducted, contact support with reference ${success.paymentId}.',
      error: true,
    );
    return OrderPayOutcome.failed;
  }
}