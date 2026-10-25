// lib/services/communication_plan_history_service.dart
//
// QNX ReMart Communication Plan – payment history + subscription detail
// (separate from communication_plan_service.dart and the Customer Subscription)
//
//   POST payment/bazaar-communication/history/           {status?, page, page_size}
//        status: created | paid | failed
//        -> {success, count, page, page_size, total_pages,
//            data:[{id, plan, plan_name, subscription_id, razorpay_order_id,
//                   razorpay_payment_id, amount (₹), currency, status,
//                   failure_reason, paid_at, is_active, created_at, updated_at}]}
//   POST olx/bazaar-communication-subscriptions/detail/  {subscription_id}
//        -> {success, data:{subscription}}

import '../models/communication_plan_models.dart';
import 'api_urls.dart';
import 'qnx_api.dart';
import 'package:qnx_mart/l10n/app_language.dart';

class CommPayment {
  final int id;
  final String planName;
  final int? subscriptionId;
  final String orderId;
  final String paymentId;
  final double amount;
  final String currency;
  final String status; // created | paid | failed
  final String failureReason;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final bool active;

  const CommPayment({
    required this.id,
    required this.planName,
    required this.subscriptionId,
    required this.orderId,
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.failureReason,
    required this.paidAt,
    required this.createdAt,
    required this.active,
  });

  factory CommPayment.fromJson(Map<String, dynamic> j) => CommPayment(
        id: qInt(j['id']) ?? 0,
        planName: qStr(j['plan_name']).isEmpty ? 'Chat plan' : qStr(j['plan_name']),
        subscriptionId: qInt(j['subscription_id']),
        orderId: qStr(j['razorpay_order_id']),
        paymentId: qStr(j['razorpay_payment_id']),
        amount: qDbl(j['amount']),
        currency: qStr(j['currency']).isEmpty ? 'INR' : qStr(j['currency']),
        status: qStr(j['status']).toLowerCase(),
        failureReason: qStr(j['failure_reason']),
        paidAt: qDate(j['paid_at']),
        createdAt: qDate(j['created_at']),
        active: qBool(j['is_active']),
      );

  String get statusLabel => switch (status) {
        'paid' => tr('Paid'),
        'failed' => tr('Failed'),
        'created' => tr('Not completed'),
        _ => status.isEmpty ? '—' : status[0].toUpperCase() + status.substring(1),
      };

  DateTime? get when => paidAt ?? createdAt;
}

class CommPaymentPage {
  final List<CommPayment> items;
  final int page;
  final int totalPages;
  final int count;
  const CommPaymentPage(this.items, this.page, this.totalPages, this.count);
  bool get hasMore => page < totalPages;
}

class CommunicationPlanHistoryService {
  CommunicationPlanHistoryService._();

  /// [status]: null = all, or created | paid | failed.
  static Future<CommResult<CommPaymentPage>> history({String? status, int page = 1, int pageSize = 20}) async {
    final r = await QnxApi.post(ApiUrls.commPaymentHistoryUrl, {
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
      'page_size': pageSize,
    });
    if (!r.ok) {
      return CommResult.fail(r.error(tr('Could not load payment history.')), needsLogin: r.authFailed);
    }
    final m = r.map;
    final items = r.list.map(CommPayment.fromJson).toList();
    return CommResult.ok(CommPaymentPage(
      items,
      qInt(m['page']) ?? page,
      qInt(m['total_pages']) ?? 1,
      qInt(m['count']) ?? items.length,
    ));
  }

  static Future<CommResult<CommSubscription>> subscriptionDetail(int subscriptionId) async {
    final r = await QnxApi.post(ApiUrls.commSubscriptionDetailUrl, {'subscription_id': subscriptionId});
    if (!r.ok) {
      return CommResult.fail(r.error(tr('Could not load plan details.')), needsLogin: r.authFailed);
    }
    final d = r.map['data'];
    if (d is! Map) return CommResult.fail(tr('Plan details are not available.'));
    return CommResult.ok(CommSubscription.fromJson(Map<String, dynamic>.from(d)));
  }
}
