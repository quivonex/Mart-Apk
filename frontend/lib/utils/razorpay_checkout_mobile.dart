// lib/utils/razorpay_checkout_mobile.dart  (Android / iOS)

import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_result.dart';

String _friendly(PaymentFailureResponse r) {
  if (r.code == Razorpay.NETWORK_ERROR) return 'Network error during payment. Please try again.';
  final m = r.message ?? '';
  // Razorpay sometimes sends a JSON string as message.
  final match = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(m);
  if (match != null) return match.group(1)!;
  return m.isNotEmpty ? m : 'Payment failed.';
}

Future<RzpResult> openCheckout(Map<String, dynamic> options) async {
  final razorpay = Razorpay();
  final done = Completer<RzpResult>();

  razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
    if (done.isCompleted) return;
    if ((r.paymentId ?? '').isEmpty) {
      done.complete(const RzpResult.failure('No payment id returned by Razorpay.'));
    } else {
      done.complete(RzpResult.success(
        paymentId: r.paymentId ?? '',
        orderId: r.orderId ?? '',
        signature: r.signature ?? '',
      ));
    }
  });
  razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
    if (done.isCompleted) return;
    done.complete(r.code == Razorpay.PAYMENT_CANCELLED
        ? const RzpResult.cancelled()
        : RzpResult.failure(_friendly(r)));
  });
  razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
    if (done.isCompleted) return;
    done.complete(RzpResult.failure(
        '${r.walletName ?? 'Wallet'} selected. Please pay with UPI / card / net banking inside the app.'));
  });

  try {
    razorpay.open(options);
  } catch (e) {
    razorpay.clear();
    return RzpResult.failure('Could not open payment: $e');
  }
  final result = await done.future;
  razorpay.clear();
  return result;
}
