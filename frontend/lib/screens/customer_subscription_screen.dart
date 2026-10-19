// lib/screens/customer_subscription_screen.dart
//
// QNX Mart › My Subscription (customer enquiry plans).
//
//   • Current plan: enquiries left, validity, progress.
//   • Plans to buy (Razorpay on Android/iOS; on web it asks to use the app).
//   • History of earlier subscriptions.
//
// Open it from anywhere – it returns true when a plan was bought:
//   final bought = await openCustomerSubscription(context,
//       reason: 'A subscription is needed to send enquiries on this property.');

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/design_tokens.dart';
import '../services/customer_subscription_service.dart';
import '../utils/login_gate.dart';
import '../utils/shared_preferences_helper.dart';

class _CS {
  static const brand = Color(0xFF6366F1);
  static const brandDark = Color(0xFF4338CA);
  static const violet = Color(0xFF8B5CF6);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const greenDark = Color(0xFF047857);
  static const greenBg = Color(0xFFECFDF5);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEEF2FF);
  static const tintLine = Color(0xFFC7D2FE);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

String _inr(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  var n = parts[0];
  if (n.length > 3) {
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final g = <String>[];
    while (rest.length > 2) {
      g.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) g.insert(0, rest);
    n = '${g.join(',')},$last3';
  }
  return '₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String _date(DateTime? d) {
  if (d == null) return '—';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

/// Opens the subscription screen (asks to log in first). True = a plan was bought.
Future<bool> openCustomerSubscription(BuildContext context, {String? reason}) async {
  if (!await ensureLoggedIn(context, reason: 'buy a subscription')) return false;
  if (!context.mounted) return false;
  final bought = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => CustomerSubscriptionScreen(reason: reason)),
  );
  return bought == true;
}

class CustomerSubscriptionScreen extends StatefulWidget {
  /// Optional banner text, e.g. why the user was sent here.
  final String? reason;
  const CustomerSubscriptionScreen({super.key, this.reason});

  @override
  State<CustomerSubscriptionScreen> createState() => _CustomerSubscriptionScreenState();
}

class _CustomerSubscriptionScreenState extends State<CustomerSubscriptionScreen> {
  bool _loading = true;
  String? _error;
  List<CustomerPlan> _plans = [];
  CustomerSubscriptionInfo? _current;
  List<CustomerSubscriptionInfo> _history = [];
  int? _buyingPlanId;
  bool _bought = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      CustomerSubscriptionService.plans(),
      CustomerSubscriptionService.mySubscriptions(),
    ]);
    if (!mounted) return;
    final p = results[0] as SubscriptionResult<List<CustomerPlan>>;
    final m = results[1] as SubscriptionResult<(CustomerSubscriptionInfo?, List<CustomerSubscriptionInfo>)>;
    setState(() {
      _loading = false;
      _plans = p.data ?? [];
      _current = m.data?.$1;
      _history = m.data?.$2 ?? [];
      if (!p.ok && !m.ok) _error = p.message;
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? DT.error : _CS.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  // ---------------------------------------------------------------- buy
  Future<void> _buy(CustomerPlan plan) async {
    if (_buyingPlanId != null) return;
    if (kIsWeb) {
      _snack('Online payment works in the QNX Mart Android app.', error: true);
      return;
    }
    setState(() => _buyingPlanId = plan.id);
    final created = await CustomerSubscriptionService.createOrder(plan.id);
    if (!mounted) return;
    final d = created.data;
    final orderId = '${d?['order_id'] ?? ''}';
    final key = '${d?['key'] ?? ''}';
    final amount = (d?['amount_paise'] as int?) ?? 0;
    if (!created.ok || orderId.isEmpty || key.isEmpty || amount <= 0) {
      setState(() => _buyingPlanId = null);
      _snack(created.ok ? 'Payment could not be started.' : created.message, error: true);
      return;
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
        'order_id': orderId,
        'name': 'QNX Mart',
        'description': '${plan.name} · ${plan.enquiryLimit} enquiries',
        'prefill': {if (email != null && email.isNotEmpty) 'email': email},
        'theme': {'color': '#6366F1'},
      });
    } catch (e) {
      razorpay.clear();
      if (mounted) setState(() => _buyingPlanId = null);
      if (mounted) _snack('Could not open payment: $e', error: true);
      return;
    }

    final (success, failure) = await done.future;
    razorpay.clear();
    if (!mounted) return;
    if (success == null) {
      setState(() => _buyingPlanId = null);
      final cancelled = failure != null && failure.code == Razorpay.PAYMENT_CANCELLED;
      _snack(cancelled ? 'Payment was cancelled.' : 'Payment failed${failure?.message != null ? ': ${failure!.message}' : '.'}',
          error: true);
      return;
    }

    final v = await CustomerSubscriptionService.verify(
      orderId: success.orderId ?? orderId,
      paymentId: success.paymentId ?? '',
      signature: success.signature ?? '',
    );
    if (!mounted) return;
    setState(() => _buyingPlanId = null);
    if (!v.ok) {
      _snack('${v.message}. If money was deducted, contact support with ${success.paymentId}.', error: true);
      return;
    }
    _bought = true;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(color: _CS.greenBg, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: _CS.greenDark, size: 34),
        ),
        title: Text('Subscription active!', textAlign: TextAlign.center, style: DT.text(size: 18, weight: FontWeight.w800)),
        content: Text('${plan.name}: ${plan.enquiryLimit} enquiries for ${plan.durationDays} days.',
            textAlign: TextAlign.center, style: DT.text(size: 13, color: _CS.muted, height: 1.45)),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _CS.brand, minimumSize: const Size.fromHeight(46)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (widget.reason != null) {
      Navigator.pop(context, true); // back to the enquiry that needed it
    } else {
      _load();
    }
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _bought);
      },
      child: Scaffold(
        backgroundColor: _CS.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: DT.headerGradient)),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('My Subscription', style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _CS.brand))
            : RefreshIndicator(
          color: _CS.brand,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (widget.reason != null) ...[_reasonBanner(widget.reason!), const SizedBox(height: 14)],
              if (_error != null) ...[_errorBox(_error!), const SizedBox(height: 14)],
              _currentCard(),
              const SizedBox(height: 22),
              _sectionTitle(_current == null ? 'Choose a plan' : 'Upgrade / renew', Icons.workspace_premium_outlined),
              const SizedBox(height: 10),
              if (_plans.isEmpty)
                _emptyBox('No plans are available right now.')
              else
                for (final p in _plans) ...[_planCard(p), const SizedBox(height: 12)],
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionTitle('History', Icons.history_rounded),
                const SizedBox(height: 10),
                for (final h in _history) _historyRow(h),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _reasonBanner(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFED7AA)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: _CS.orange, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: DT.text(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF9A3412), height: 1.4))),
      ],
    ),
  );

  Widget _errorBox(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: DT.errorBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: DT.errorBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: DT.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: DT.text(size: 12.5, weight: FontWeight.w600, color: DT.error))),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  Widget _emptyBox(String text) => Container(
    padding: const EdgeInsets.all(20),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _CS.line),
    ),
    child: Text(text, style: DT.text(size: 13, color: _CS.muted)),
  );

  Widget _sectionTitle(String text, IconData icon) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: _CS.tint, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _CS.brand),
      ),
      const SizedBox(width: 8),
      Text(text, style: DT.text(size: 16, weight: FontWeight.w800, color: _CS.ink)),
    ],
  );

  Widget _currentCard() {
    final c = _current;
    if (c == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _CS.line),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: _CS.tint, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.card_membership_rounded, color: _CS.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No active subscription', style: DT.text(size: 15, weight: FontWeight.w800, color: _CS.ink)),
                  const SizedBox(height: 2),
                  Text('Buy a plan to send enquiries on properties posted by owners and agents.',
                      style: DT.text(size: 12, color: _CS.muted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final used = c.enquiryLimit == 0 ? 0.0 : (c.enquiryUsed / c.enquiryLimit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), _CS.brandDark, _CS.violet],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x406366F1), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.planName,
                    style: DT.text(size: 18, weight: FontWeight.w800, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: _CS.green, borderRadius: BorderRadius.circular(20)),
                child: Text('ACTIVE', style: DT.text(size: 10, weight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${c.remaining}', style: DT.text(size: 34, weight: FontWeight.w900, color: Colors.white, height: 1)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('of ${c.enquiryLimit} enquiries left',
                    style: DT.text(size: 12.5, weight: FontWeight.w600, color: const Color(0xCCFFFFFF))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 1 - used,
              minHeight: 8,
              color: const Color(0xFF6EE7B7),
              backgroundColor: const Color(0x33FFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          Text('Valid till ${_date(c.endDate)}',
              style: DT.text(size: 12, weight: FontWeight.w600, color: const Color(0xCCFFFFFF))),
        ],
      ),
    );
  }

  Widget _planCard(CustomerPlan p) {
    final busy = _buyingPlanId == p.id;
    final perEnquiry = p.enquiryLimit > 0 ? p.price / p.enquiryLimit : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CS.tintLine),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: DT.text(size: 16, weight: FontWeight.w800, color: _CS.ink)),
                    const SizedBox(height: 2),
                    Text('${p.durationDays} days validity', style: DT.text(size: 12, color: _CS.muted)),
                  ],
                ),
              ),
              Text(_inr(p.price), style: DT.text(size: 22, weight: FontWeight.w900, color: _CS.brandDark)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.forum_outlined, '${p.enquiryLimit} enquiries'),
              _chip(Icons.event_available_outlined, '${p.durationDays} days'),
              if (perEnquiry > 0) _chip(Icons.sell_outlined, '${_inr(perEnquiry)} / enquiry'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: DT.ctaGradient, borderRadius: BorderRadius.circular(14)),
              child: ElevatedButton(
                onPressed: _buyingPlanId != null ? null : () => _buy(p),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Buy for ${_inr(p.price)}',
                    style: DT.text(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: _CS.tint, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _CS.brand),
        const SizedBox(width: 4),
        Text(text, style: DT.text(size: 11.5, weight: FontWeight.w700, color: _CS.brandDark)),
      ],
    ),
  );

  Widget _historyRow(CustomerSubscriptionInfo h) {
    final color = h.isActive ? _CS.green : (h.status == 'expired' ? _CS.hint : DT.amber500);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CS.line),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.planName, style: DT.text(size: 13.5, weight: FontWeight.w700, color: _CS.ink)),
                Text('${_date(h.startDate)} – ${_date(h.endDate)} · ${h.enquiryUsed}/${h.enquiryLimit} used',
                    style: DT.text(size: 11.5, color: _CS.muted)),
              ],
            ),
          ),
          Text(h.status.isEmpty ? '' : h.status[0].toUpperCase() + h.status.substring(1),
              style: DT.text(size: 11.5, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
