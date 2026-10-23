// lib/utils/razorpay_checkout.dart
//
// One call that opens Razorpay on every platform:
//   • Android / iOS → razorpay_flutter
//   • Web           → Razorpay checkout.js (add the script to web/index.html:
//                     <script src="https://checkout.razorpay.com/v1/checkout.js"></script>)
//
//   final r = await openRazorpayCheckout({'key': …, 'amount': …, 'order_id': …});

import 'razorpay_result.dart';
import 'razorpay_checkout_mobile.dart' if (dart.library.js_interop) 'razorpay_checkout_web.dart' as impl;

export 'razorpay_result.dart';

Future<RzpResult> openRazorpayCheckout(Map<String, dynamic> options) => impl.openCheckout(options);
