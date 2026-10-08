// lib/utils/company_payment_helper.dart
//
// Company registration payment flow:
//   1. POST create-company-payment-order/  -> Razorpay order_id + key + amount
//   2. Open Razorpay checkout
//   3. POST verify-payment/ with payment_id, order_id, signature, company_id
//
// Usage:
//   final paid = await CompanyPaymentHelper.pay(context, company);
//   if (paid) reload();

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';

class CompanyPaymentHelper {
  CompanyPaymentHelper._();

  static bool _busy = false;

  /// Returns true only when the backend confirms payment_status = "paid".
  static Future<bool> pay(BuildContext context, Company company) async {
    if (_busy) return false;
    _busy = true;
    try {
      return await _run(context, company);
    } finally {
      _busy = false;
    }
  }

  static Future<bool> _run(BuildContext context, Company company) async {
    // razorpay_flutter is Android/iOS only; on web open() never returns.
    if (kIsWeb) {
      _snack(context,
          'Online payment works in the QNX Mart Android app. Open My Companies on your phone to pay.');
      return false;
    }

    // ---------- 1. Create order ----------
    _showLoader(context, 'Preparing payment…');
    final order = await CompanyService.createPaymentOrder(company.id);
    if (!context.mounted) return false;
    _hideLoader(context);

    // Already paid, or a previous captured payment was recovered by the server.
    if (order.status && order.alreadyPaid) {
      await _showSuccess(context, company, order, order.paymentId ?? '');
      return true;
    }

    if (!order.isSuccess) {
      _snack(context, order.message ?? 'Could not start payment', error: true);
      return false;
    }

    // Let the user see the amount before the gateway opens.
    final go = await _confirmAmount(context, company, order);
    if (!go || !context.mounted) return false;

    // ---------- 2. Razorpay checkout ----------
    final razorpay = Razorpay();
    final completer = Completer<_CheckoutResult>();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!completer.isCompleted) completer.complete(_CheckoutResult.success(r));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!completer.isCompleted) completer.complete(_CheckoutResult.failure(r));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      if (!completer.isCompleted) {
        completer.complete(_CheckoutResult.wallet(r.walletName ?? 'wallet'));
      }
    });

    try {
      razorpay.open({
        'key': order.key,
        'amount': order.amountInPaise,
        'currency': order.currency,
        'order_id': order.orderId,
        'name': 'QNX Mart B2B',
        'description': 'Company registration – ${company.name}',
        'prefill': {
          if (company.phoneNumber.isNotEmpty) 'contact': company.phoneNumber,
          if (company.email.isNotEmpty) 'email': company.email,
        },
        'notes': {'company_id': company.id.toString()},
        'theme': {'color': '#1E3A8A'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      razorpay.clear();
      if (context.mounted) _snack(context, 'Could not open payment: $e', error: true);
      return false;
    }

    final result = await completer.future;
    razorpay.clear();
    if (!context.mounted) return false;

    if (result.cancelled) {
      _snack(context, 'Payment cancelled. You can pay later from My Companies.');
      return false;
    }
    if (result.walletName != null) {
      _snack(context,
          '${result.walletName} selected. Complete the payment there, then pull to refresh.');
      return false;
    }
    if (!result.ok) {
      _snack(context, result.errorMessage ?? 'Payment failed', error: true);
      return false;
    }

    // ---------- 3. Verify on backend ----------
    _showLoader(context, 'Confirming payment…');
    final verify = await CompanyService.verifyPayment(
      paymentId: result.paymentId!,
      orderId: result.orderId ?? order.orderId!,
      signature: result.signature ?? '',
      companyId: company.id,
    );
    if (!context.mounted) return verify.isSuccess;
    _hideLoader(context);

    if (verify.isSuccess) {
      await _showSuccess(context, company, order, result.paymentId!);
      return true;
    }

    // Money may already be captured; give the user the reference.
    await _showVerifyFailed(context, verify.message, result.paymentId!);
    return false;
  }

  // =================================================================
  // UI pieces
  // =================================================================
  static void _showLoader(BuildContext context, String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: DT.blue800),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(text,
                      style: DT.text(size: 14, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _hideLoader(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  static Future<bool> _confirmAmount(
      BuildContext context,
      Company company,
      CompanyPaymentOrderResponse order,
      ) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DT.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Registration fee',
                  style: DT.text(size: 13, color: DT.slate500, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(order.amountLabel,
                  style: DT.text(size: 32, weight: FontWeight.w800, letterSpacing: -0.8)),
              const SizedBox(height: 4),
              Text(
                'One-time fee to activate ${company.name} on QNX Mart B2B. '
                    'Your company admin panel and pickup location are set up after payment.',
                style: DT.text(size: 12.5, color: DT.onyx600, height: 1.45),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.amber600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DT.rMd)),
                  ),
                  child: Text('Pay ${order.amountLabel}',
                      style: DT.text(
                          size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Not now',
                    style: DT.text(size: 13, weight: FontWeight.w600, color: DT.slate500)),
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  static Future<void> _showSuccess(
      BuildContext context,
      Company company,
      CompanyPaymentOrderResponse order,
      String paymentId,
      ) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: DT.emerald50, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: DT.emerald700, size: 32),
        ),
        title: Text('Payment received',
            textAlign: TextAlign.center,
            style: DT.text(size: 18, weight: FontWeight.w800)),
        content: Text(
          order.alreadyPaid
              ? '${company.name} is registered.'
              '${paymentId.isNotEmpty ? '\nReference: $paymentId' : ''}'
              : '${company.name} is now registered. ${order.amountLabel} paid.\n'
              'Reference: $paymentId',
          textAlign: TextAlign.center,
          style: DT.text(size: 13, color: DT.onyx600, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.blue800,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
              ),
              child: Text('Done',
                  style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showVerifyFailed(
      BuildContext context,
      String? message,
      String paymentId,
      ) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
        title: Text('Payment not confirmed yet',
            style: DT.text(size: 17, weight: FontWeight.w800)),
        content: Text(
          '${message ?? 'We could not confirm your payment with the server.'}\n\n'
              'If money was deducted, keep this reference and contact support:\n$paymentId',
          style: DT.text(size: 13, color: DT.onyx600, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: DT.text(size: 14, weight: FontWeight.w700, color: DT.blue800)),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg,
            style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? DT.error : DT.onyx900,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
      ));
  }
}

class _CheckoutResult {
  final bool ok;
  final bool cancelled;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final String? walletName;

  _CheckoutResult._({
    this.ok = false,
    this.cancelled = false,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
    this.walletName,
  });

  factory _CheckoutResult.success(PaymentSuccessResponse r) => _CheckoutResult._(
    ok: r.paymentId != null,
    paymentId: r.paymentId,
    orderId: r.orderId,
    signature: r.signature,
    errorMessage: r.paymentId == null ? 'No payment id returned' : null,
  );

  factory _CheckoutResult.failure(PaymentFailureResponse r) => _CheckoutResult._(
    cancelled: r.code == Razorpay.PAYMENT_CANCELLED,
    errorMessage: _friendly(r),
  );

  factory _CheckoutResult.wallet(String name) => _CheckoutResult._(walletName: name);

  static String _friendly(PaymentFailureResponse r) {
    if (r.code == Razorpay.NETWORK_ERROR) return 'Network error during payment. Try again.';
    final m = r.message ?? '';
    // Razorpay sometimes sends a JSON string as message.
    final match = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(m);
    if (match != null) return match.group(1)!;
    return m.isNotEmpty ? m : 'Payment failed';
  }
}