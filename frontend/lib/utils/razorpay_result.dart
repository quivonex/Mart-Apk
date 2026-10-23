// lib/utils/razorpay_result.dart
//
// Result of one Razorpay checkout (same shape on Android/iOS and web).

class RzpResult {
  final bool ok;
  final bool cancelled;
  final String paymentId;
  final String orderId;
  final String signature;
  final String error;

  const RzpResult._({
    this.ok = false,
    this.cancelled = false,
    this.paymentId = '',
    this.orderId = '',
    this.signature = '',
    this.error = '',
  });

  const RzpResult.success({required String paymentId, required String orderId, required String signature})
      : this._(ok: true, paymentId: paymentId, orderId: orderId, signature: signature);

  const RzpResult.cancelled([String error = ''])
      : this._(cancelled: true, error: error);

  const RzpResult.failure(String error) : this._(error: error);
}
