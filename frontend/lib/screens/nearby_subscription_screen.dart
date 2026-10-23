// lib/screens/nearby_subscription_screen.dart
//
// QNX Mart › Nearby Search › Subscription
//
//   Active plan  → green card (plan, valid till, days left) – NO plans shown.
//                  New plans appear only after this plan ends.
//   No plan / expired → plan cards → Buy Now → Razorpay → verify → active.
//
// Opened from the "Plan" button in the Nearby Search header.
// Pops `true` when a plan is active (Nearby Search then re-runs the search).
//
// APIs: admin_profile/subscription-plans/list/, subscription/create-order/,
//       place_subscription/sub_payment_verify/  (see nearby_subscription_service.dart)

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../services/nearby_subscription_service.dart';
import '../utils/razorpay_checkout.dart';
import '../utils/shared_preferences_helper.dart';
import 'login_screen.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _SC {
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const tintLine = Color(0xFFC9DBEE);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const green = Color(0xFF047857);
  static const greenBg = Color(0xFFECFDF5);
  static const greenLine = Color(0xFFA7F3D0);
  static const orangeText = Color(0xFFC2410C);
  static const orangeBg = Color(0xFFFFF7ED);
  static const orangeLine = Color(0xFFFED7AA);
  static const orange = Color(0xFFF7931E);
  static const red = Color(0xFFC62828);
  static const redBg = Color(0xFFFDECEC);
}

class NearbySubscriptionScreen extends StatefulWidget {
  const NearbySubscriptionScreen({super.key});

  @override
  State<NearbySubscriptionScreen> createState() => _NearbySubscriptionScreenState();
}

class _NearbySubscriptionScreenState extends State<NearbySubscriptionScreen> {
  bool _loading = true;
  String? _error;
  bool _needsLogin = false;
  List<NearbyPlan> _plans = [];
  NearbyActiveSub? _saved; // active OR last expired plan
  String? _buyingId;

  bool get _active => _saved != null && _saved!.isActive;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _needsLogin = true;
        _error = 'Please log in to see the Nearby Search plans.';
      });
      return;
    }
    final r = await NearbySubscriptionService.plans(); // also saves a server-side active plan
    final saved = await NearbySubscriptionStore.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _saved = saved;
      _plans = r.data?.plans ?? const [];
      _needsLogin = r.needsLogin;
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _openLogin() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (mounted) _load();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? _SC.red : _SC.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  // ------------------------------------------------------------ buy flow
  Future<void> _buy(NearbyPlan plan) async {
    if (_buyingId != null) return;
    // One plan at a time – the next one only after the current plan ends.
    final current = await NearbySubscriptionStore.active();
    if (!mounted) return;
    if (current != null) {
      setState(() => _saved = current);
      _snack('Your ${current.planName} plan is active till ${nearbyDate(current.expiresAt)}.');
      return;
    }

    setState(() => _buyingId = plan.id);
    try {
      // 1. create order
      final o = await NearbySubscriptionService.createOrder(plan);
      if (!mounted) return;
      if (!o.ok || o.data == null) {
        if (o.needsLogin) {
          setState(() {
            _needsLogin = true;
            _error = o.message;
          });
        } else {
          await _alert('Could not start payment', o.message, error: true);
        }
        return;
      }
      final order = o.data!;

      // 2. Razorpay checkout
      final email = await SharedPreferencesHelper.getUserEmail();
      final name = await SharedPreferencesHelper.getUsername();
      final pay = await openRazorpayCheckout({
        'key': order.key,
        'amount': order.amountPaise,
        'currency': order.currency,
        'order_id': order.orderId,
        'name': 'QNX Mart B2B',
        'description': 'Nearby Search – ${order.plan.name} (${order.plan.durationDays} days)',
        'prefill': {
          if (name != null && name.isNotEmpty) 'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        'notes': {'plan_id': order.plan.id},
        'theme': {'color': '#093C71'},
        'retry': {'enabled': true, 'max_count': 2},
      });
      if (!mounted) return;
      if (pay.cancelled) {
        _snack('Payment cancelled.');
        return;
      }
      if (!pay.ok) {
        await _alert('Payment failed', pay.error, error: true);
        return;
      }

      // 3. verify on backend
      final v = await NearbySubscriptionService.verify(
        order: order,
        paymentId: pay.paymentId,
        signature: pay.signature,
        razorpayOrderId: pay.orderId,
      );
      if (!mounted) return;
      if (v.ok && v.data != null) {
        setState(() => _saved = v.data);
        await _alert(
          'Subscription activated',
          '${v.message}\n\n${v.data!.planName} plan is active till ${nearbyDate(v.data!.expiresAt)}.\n'
              'Reference: ${pay.paymentId}',
        );
        if (mounted) _load(); // refresh plans (ownership flags, if any)
      } else if (v.needsLogin) {
        setState(() {
          _needsLogin = true;
          _error = v.message;
        });
      } else {
        await _alert(
          'Payment not confirmed',
          '${v.message}\n\nIf money was deducted, keep this reference and contact support:\n${pay.paymentId}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  Future<void> _alert(String title, String body, {bool error = false}) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: error ? _SC.redBg : _SC.greenBg, shape: BoxShape.circle),
        child: Icon(error ? Icons.error_outline_rounded : Icons.check_rounded,
            color: error ? _SC.red : _SC.green, size: 30),
      ),
      title: Text(title,
          textAlign: TextAlign.center, style: DT.text(size: 17, weight: FontWeight.w800, color: _SC.ink)),
      content: Text(body,
          textAlign: TextAlign.center, style: DT.text(size: 13, color: _SC.body, height: 1.5)),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_active);
      },
      child: Scaffold(
        backgroundColor: _SC.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('Nearby Search Plans',
              style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: _kBrand,
          onRefresh: _load,
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 3)),
        ],
      );
    }
    if (_needsLogin) {
      return _message(Icons.lock_outline_rounded, 'Login required',
          _error ?? 'Please log in again.', 'Login', _openLogin);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _hero(),
        const SizedBox(height: 16),
        if (_active) ...[
          _activeCard(_saved!),
          const SizedBox(height: 12),
          _condition(Icons.info_outline_rounded,
              'You can buy a new plan after the current plan ends on ${nearbyDate(_saved!.expiresAt)}.'),
        ] else ...[
          if (_saved != null) ...[
            _condition(Icons.history_rounded,
                'Your ${_saved!.planName} plan ended on ${nearbyDate(_saved!.expiresAt)}. Choose a plan to continue searching.'),
            const SizedBox(height: 12),
          ],
          if (_error != null)
            _errorBox(_error!)
          else if (_plans.isEmpty)
            _emptyBox()
          else ...[
              Text('Choose a plan', style: DT.text(size: 15, weight: FontWeight.w800, color: _SC.ink)),
              const SizedBox(height: 10),
              for (final p in _plans) ...[
                _planCard(p),
                const SizedBox(height: 12),
              ],
            ],
        ],
      ],
    );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(gradient: _kHeader, borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Find businesses near you',
                  style: DT.text(size: 16, weight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Transport, warehouses, shops and more – with map, directions and WhatsApp contact.',
                  style: DT.text(size: 12.5, color: Colors.white.withValues(alpha: 0.85), height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _activeCard(NearbyActiveSub s) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _SC.greenLine, width: 1.4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _SC.greenBg, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: _SC.green),
                  const SizedBox(width: 4),
                  Text('ACTIVE PLAN', style: DT.text(size: 10.5, weight: FontWeight.w800, color: _SC.green)),
                ],
              ),
            ),
            const Spacer(),
            Text('${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} left',
                style: DT.text(size: 12.5, weight: FontWeight.w800, color: _SC.green)),
          ],
        ),
        const SizedBox(height: 12),
        Text(s.planName, style: DT.text(size: 20, weight: FontWeight.w800, color: _SC.ink)),
        const SizedBox(height: 4),
        Text('Valid till ${nearbyDate(s.expiresAt)}',
            style: DT.text(size: 13, weight: FontWeight.w600, color: _SC.body)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: 1 - s.usedFraction,
            minHeight: 8,
            backgroundColor: _SC.tint,
            color: _SC.green,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Started ${nearbyDate(s.startedAt)}', style: DT.text(size: 11.5, color: _SC.muted)),
            const Spacer(),
            if (s.enquiryLimit > 0)
              Text('Up to ${s.enquiryLimit} enquiries', style: DT.text(size: 11.5, color: _SC.muted)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _kBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.search_rounded, size: 20),
            label: Text('Start searching',
                style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    ),
  );

  Widget _planCard(NearbyPlan p) {
    final busy = _buyingId == p.id;
    final otherBusy = _buyingId != null && !busy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _SC.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: _SC.tint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.workspace_premium_rounded, color: _kBrand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: DT.text(size: 16, weight: FontWeight.w800, color: _SC.ink)),
                    if (p.durationLabel.isNotEmpty)
                      Text(p.durationLabel, style: DT.text(size: 12, color: _SC.muted)),
                  ],
                ),
              ),
              Text(p.priceLabel, style: DT.text(size: 18, weight: FontWeight.w800, color: _kBrand)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _SC.line),
          const SizedBox(height: 10),
          _feature(Icons.event_available_rounded, 'Valid for ${p.durationDays} days'),
          if (p.enquiryLimit > 0) _feature(Icons.forum_outlined, 'Up to ${p.enquiryLimit} enquiries'),
          _feature(Icons.calendar_month_rounded, 'Valid until ${nearbyDate(p.validUntilIfBoughtNow)} if bought today'),
          _feature(Icons.map_outlined, 'Map, directions & WhatsApp contact'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kBrand,
                disabledBackgroundColor: _kBrand.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (busy || otherBusy) ? null : () => _buy(p),
              child: busy
                  ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Text('Buy Now · ${p.priceLabel}',
                  style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _kBrandLight),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: DT.text(size: 12.5, color: _SC.body))),
      ],
    ),
  );

  Widget _condition(IconData icon, String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _SC.orangeBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _SC.orangeLine),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _SC.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: DT.text(size: 12.5, weight: FontWeight.w600, color: _SC.orangeText, height: 1.4)),
        ),
      ],
    ),
  );

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _SC.red.withValues(alpha: 0.35)),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 34, color: _SC.red),
        const SizedBox(height: 8),
        Text(msg, textAlign: TextAlign.center, style: DT.text(size: 13, color: _SC.body, height: 1.45)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kBrand),
          onPressed: _load,
          child: const Text('Try again'),
        ),
      ],
    ),
  );

  Widget _emptyBox() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _SC.tint,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _SC.tintLine),
    ),
    child: Column(
      children: [
        const Icon(Icons.inventory_2_outlined, size: 34, color: _kBrand),
        const SizedBox(height: 8),
        Text('No plans available right now',
            style: DT.text(size: 14, weight: FontWeight.w800, color: _SC.ink)),
        const SizedBox(height: 4),
        Text('Please check again later.', style: DT.text(size: 12.5, color: _SC.muted)),
      ],
    ),
  );

  Widget _message(IconData icon, String title, String body, String button, VoidCallback onTap) => ListView(
    padding: const EdgeInsets.fromLTRB(32, 80, 32, 24),
    children: [
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: _SC.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: _kBrand),
        ),
      ),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _SC.ink)),
      const SizedBox(height: 4),
      Text(body, textAlign: TextAlign.center, style: DT.text(size: 13, color: _SC.muted, height: 1.45)),
      const SizedBox(height: 14),
      Center(
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kBrand),
          onPressed: onTap,
          child: Text(button),
        ),
      ),
    ],
  );
}
