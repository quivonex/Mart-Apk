// lib/utils/razorpay_checkout_web.dart  (web)
//
// Uses window.Razorpay from https://checkout.razorpay.com/v1/checkout.js
// (the script is added to the page automatically when it is missing)
//   success      → options.handler(response)
//   payment.failed → remembered (Razorpay keeps the window open for a retry)
//   window closed  → modal.ondismiss → cancelled / last failure

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'razorpay_result.dart';
import 'package:qnx_mart/l10n/app_language.dart';

const _scriptUrl = 'https://checkout.razorpay.com/v1/checkout.js';

/// Adds <script src=checkout.js> to <head> once and waits for it.
Future<bool> _ensureScript() async {
  if (globalContext.has(tr('Razorpay'))) return true;
  try {
    final doc = globalContext['document'] as JSObject;
    final script = doc.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
    final loaded = Completer<bool>();
    script['src'] = _scriptUrl.toJS;
    script['async'] = true.toJS;
    script['onload'] = ((JSAny? _) {
      if (!loaded.isCompleted) loaded.complete(true);
    }).toJS;
    script['onerror'] = ((JSAny? _) {
      if (!loaded.isCompleted) loaded.complete(false);
    }).toJS;
    final head = doc['head'] as JSObject;
    head.callMethod<JSAny?>('appendChild'.toJS, script);
    final ok = await loaded.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
    return ok && globalContext.has(tr('Razorpay'));
  } catch (_) {
    return false;
  }
}

Future<RzpResult> openCheckout(Map<String, dynamic> options) async {
  if (!await _ensureScript()) {
    return RzpResult.failure(
        tr('Payment window could not load. Check your internet connection (checkout.razorpay.com) and try again.'));
  }
  return _open(options);
}

Future<RzpResult> _open(Map<String, dynamic> options) {
  final done = Completer<RzpResult>();
  void finish(RzpResult r) {
    if (!done.isCompleted) done.complete(r);
  }

  var lastError = '';
  try {
    final opts = options.jsify() as JSObject;

    opts['handler'] = ((JSAny? resp) {
      final m = resp.dartify();
      final map = m is Map ? m : const {};
      final pid = '${map['razorpay_payment_id'] ?? ''}';
      finish(pid.isEmpty
          ? RzpResult.failure(tr('No payment id returned by Razorpay.'))
          : RzpResult.success(
              paymentId: pid,
              orderId: '${map['razorpay_order_id'] ?? ''}',
              signature: '${map['razorpay_signature'] ?? ''}',
            ));
    }).toJS;

    final modal = <String, dynamic>{}.jsify() as JSObject;
    modal['ondismiss'] = (() {
      finish(lastError.isEmpty ? const RzpResult.cancelled() : RzpResult.failure(lastError));
    }).toJS;
    opts['modal'] = modal;

    final ctor = globalContext['Razorpay'] as JSFunction;
    final rzp = ctor.callAsConstructor<JSObject>(opts);
    rzp.callMethod<JSAny?>(
      'on'.toJS,
      'payment.failed'.toJS,
      ((JSAny? resp) {
        final m = resp.dartify();
        final err = (m is Map && m['error'] is Map) ? m['error'] as Map : const {};
        final d = '${err['description'] ?? ''}'.trim();
        final r = '${err['reason'] ?? ''}'.trim();
        lastError = d.isNotEmpty ? d : (r.isNotEmpty ? r : tr('Payment failed.'));
      }).toJS,
    );
    rzp.callMethod<JSAny?>('open'.toJS);
  } catch (e) {
    finish(RzpResult.failure(tr('Could not open payment: {0}', [e])));
  }
  return done.future;
}
