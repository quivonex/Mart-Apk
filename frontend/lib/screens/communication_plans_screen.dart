// lib/screens/communication_plans_screen.dart
//
// QNX ReMart › Chat & Enquiry Plans
//
//   [Usage]   Chats used 7 / 20 (this month) · Enquiries used 3 / 10
//   [Active]  current subscription (plan, valid till, limits)
//   [Plans]   Starter / Pro …  → Buy → Razorpay → verify → refresh
//   [History] my subscriptions (expired / old)
//
// Opened from My Chats ("Plans" button) and from the "chat limit reached" dialog.
// Pops `true` after a successful purchase.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/communication_plan_models.dart';
import '../services/communication_plan_service..dart';
import '../utils/razorpay_checkout.dart';
import '../utils/shared_preferences_helper.dart';
import 'chat_screen.dart' show ChatColors, chatRupees;
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

String _date(DateTime? d) {
  if (d == null) return '—';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class CommunicationPlansScreen extends StatefulWidget {
  const CommunicationPlansScreen({super.key});

  @override
  State<CommunicationPlansScreen> createState() => _CommunicationPlansScreenState();
}

class _CommunicationPlansScreenState extends State<CommunicationPlansScreen> {
  bool _loading = true;
  bool _needsLogin = false;
  String? _error;
  List<CommPlan> _plans = [];
  List<CommSubscription> _subs = [];
  CommUsage? _chatUsage;
  CommUsage? _enquiryUsage;
  int? _buyingId;
  bool _bought = false;

  CommSubscription? get _active {
    for (final s in _subs) {
      if (s.currentlyValid) return s;
    }
    return null;
  }

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
        _error = 'Please login to see the chat plans.';
      });
      return;
    }
    final plansF = CommunicationPlanService.plans();
    final subsF = CommunicationPlanService.mySubscriptions();
    final chatF = CommunicationPlanService.chatUsage();
    final enqF = CommunicationPlanService.enquiryUsage();
    final plans = await plansF;
    final subs = await subsF;
    final chat = await chatF;
    final enq = await enqF;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _plans = plans.data ?? const [];
      _subs = subs.data ?? const [];
      _chatUsage = chat;
      _enquiryUsage = enq;
      _needsLogin = plans.needsLogin || subs.needsLogin;
      _error = plans.ok ? null : plans.message;
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? ChatColors.red : ChatColors.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  // ---------------------------------------------------------------- buy
  Future<void> _buy(CommPlan plan) async {
    if (_buyingId != null) return;
    final a = _active;
    if (a != null) {
      final go = await _confirm(
        'You already have a plan',
        'Your ${a.planName} plan is active till ${_date(a.expiresAt)}. Buy ${plan.name} anyway?',
        'Buy ${plan.name}',
      );
      if (!go || !mounted) return;
    }
    setState(() => _buyingId = plan.id);
    try {
      final o = await CommunicationPlanService.createOrder(plan);
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
      final email = await SharedPreferencesHelper.getUserEmail();
      final name = await SharedPreferencesHelper.getUsername();
      final pay = await openRazorpayCheckout({
        'key': order.key,
        'amount': order.amountPaise,
        'currency': order.currency,
        'order_id': order.orderId,
        'name': 'QNX ReMart',
        'description': 'Chat & enquiry plan – ${order.planName}',
        'prefill': {
          if (name != null && name.isNotEmpty) 'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        'notes': {'plan_id': '${plan.id}'},
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
      final v = await CommunicationPlanService.verify(
        orderId: pay.orderId.isNotEmpty ? pay.orderId : order.orderId,
        paymentId: pay.paymentId,
        signature: pay.signature,
      );
      if (!mounted) return;
      if (v.ok) {
        _bought = true;
        await _alert('Plan activated', '${v.data}\n\nReference: ${pay.paymentId}');
        if (mounted) _load();
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

  Future<bool> _confirm(String title, String body, String yes) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: DT.text(size: 17, weight: FontWeight.w800, color: ChatColors.ink)),
        content: Text(body, style: DT.text(size: 13.5, color: ChatColors.body, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: DT.text(size: 14, weight: FontWeight.w700, color: ChatColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kBrand),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return r == true;
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
        decoration: BoxDecoration(color: error ? ChatColors.redBg : ChatColors.greenBg, shape: BoxShape.circle),
        child: Icon(error ? Icons.error_outline_rounded : Icons.check_rounded,
            color: error ? ChatColors.red : ChatColors.green, size: 30),
      ),
      title: Text(title,
          textAlign: TextAlign.center, style: DT.text(size: 17, weight: FontWeight.w800, color: ChatColors.ink)),
      content: Text(body,
          textAlign: TextAlign.center, style: DT.text(size: 13, color: ChatColors.body, height: 1.5)),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kBrand),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_bought);
      },
      child: Scaffold(
        backgroundColor: ChatColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('Chat & Enquiry Plans', style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(color: _kBrand, onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading && _plans.isEmpty && _subs.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 160),
        Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 3)),
      ]);
    }
    if (_needsLogin) {
      return _state(Icons.lock_outline_rounded, 'Login required', _error ?? 'Please login again.', 'Login',
              () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            if (mounted) _load();
          });
    }
    final active = _active;
    final history = _subs.where((s) => !s.currentlyValid).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _usageCard(),
        const SizedBox(height: 14),
        if (active != null) ...[
          _activeCard(active),
          const SizedBox(height: 14),
        ],
        Text(active == null ? 'Choose a plan' : 'Upgrade / renew',
            style: DT.text(size: 15, weight: FontWeight.w800, color: ChatColors.ink)),
        const SizedBox(height: 10),
        if (_error != null)
          _errorBox(_error!)
        else if (_plans.isEmpty)
          _note(Icons.inventory_2_outlined, 'No plans available right now. Please check again later.')
        else
          for (final p in _plans) ...[_planCard(p, active), const SizedBox(height: 12)],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Past plans', style: DT.text(size: 15, weight: FontWeight.w800, color: ChatColors.ink)),
          const SizedBox(height: 10),
          for (final s in history) _historyTile(s),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- usage
  Widget _usageCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(gradient: _kHeader, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Your usage', style: DT.text(size: 15, weight: FontWeight.w800, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        _usageRow('Chats', Icons.chat_rounded, _chatUsage),
        const SizedBox(height: 12),
        _usageRow('Enquiries', Icons.forum_rounded, _enquiryUsage),
      ],
    ),
  );

  Widget _usageRow(String label, IconData icon, CommUsage? u) {
    String value;
    String sub = '';
    if (u == null) {
      value = 'No active plan';
    } else if (u.unlimited) {
      value = 'Unlimited · ${u.used} used';
    } else {
      value = '${u.used} / ${u.limit ?? 0} used';
      sub = '${u.remaining ?? 0} left${u.periodEnd == null ? '' : ' · resets ${_date(u.periodEnd)}'}';
    }
    final exhausted = u?.exhausted ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Text(label, style: DT.text(size: 13, weight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            Text(value,
                style: DT.text(
                    size: 13, weight: FontWeight.w800, color: exhausted ? const Color(0xFFFED7AA) : Colors.white)),
          ],
        ),
        if (u != null && !u.unlimited) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: u.fraction,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: exhausted ? const Color(0xFFF7931E) : Colors.white,
            ),
          ),
        ],
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sub, style: DT.text(size: 11, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- active
  Widget _activeCard(CommSubscription s) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: ChatColors.greenBg, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: ChatColors.green),
                  const SizedBox(width: 4),
                  Text('ACTIVE PLAN', style: DT.text(size: 10.5, weight: FontWeight.w800, color: ChatColors.green)),
                ],
              ),
            ),
            const Spacer(),
            Text('${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} left',
                style: DT.text(size: 12.5, weight: FontWeight.w800, color: ChatColors.green)),
          ],
        ),
        const SizedBox(height: 10),
        Text(s.planName, style: DT.text(size: 20, weight: FontWeight.w800, color: ChatColors.ink)),
        const SizedBox(height: 2),
        Text('${_date(s.startsAt)} – ${_date(s.expiresAt)}',
            style: DT.text(size: 12.5, weight: FontWeight.w600, color: ChatColors.body)),
        const SizedBox(height: 10),
        if (s.chatLabel.isNotEmpty) _feature(Icons.chat_rounded, s.chatLabel),
        if (s.enquiryLabel.isNotEmpty) _feature(Icons.forum_outlined, s.enquiryLabel),
      ],
    ),
  );

  // ---------------------------------------------------------------- plan card
  Widget _planCard(CommPlan p, CommSubscription? active) {
    final busy = _buyingId == p.id;
    final otherBusy = _buyingId != null && !busy;
    final current = active != null && active.planName.toLowerCase() == p.name.toLowerCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: current ? ChatColors.tintLine : ChatColors.line, width: current ? 1.6 : 1),
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
                decoration: BoxDecoration(color: ChatColors.tint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.workspace_premium_rounded, color: _kBrand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.name, style: DT.text(size: 16, weight: FontWeight.w800, color: ChatColors.ink)),
                        ),
                        if (current) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration:
                            BoxDecoration(color: ChatColors.greenBg, borderRadius: BorderRadius.circular(6)),
                            child: Text('Current',
                                style: DT.text(size: 10, weight: FontWeight.w800, color: ChatColors.green)),
                          ),
                        ],
                      ],
                    ),
                    if (p.durationLabel.isNotEmpty)
                      Text(p.durationLabel, style: DT.text(size: 12, color: ChatColors.muted)),
                  ],
                ),
              ),
              Text(chatRupees(p.price), style: DT.text(size: 18, weight: FontWeight.w800, color: _kBrand)),
            ],
          ),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.description, style: DT.text(size: 12.5, color: ChatColors.body, height: 1.4)),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: ChatColors.line),
          const SizedBox(height: 8),
          if (p.chatLabel.isNotEmpty) _feature(Icons.chat_rounded, p.chatLabel),
          if (p.enquiryLabel.isNotEmpty) _feature(Icons.forum_outlined, p.enquiryLabel),
          if (p.durationDays > 0)
            _feature(Icons.event_available_rounded, 'Valid for ${p.durationDays} days'),
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
                  : Text('${current ? 'Renew' : 'Buy'} · ${chatRupees(p.price)}',
                  style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(CommSubscription s) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ChatColors.line),
    ),
    child: Row(
      children: [
        const Icon(Icons.history_rounded, color: ChatColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.planName, style: DT.text(size: 14, weight: FontWeight.w800, color: ChatColors.ink)),
              Text('${_date(s.startsAt)} – ${_date(s.expiresAt)} · ${chatRupees(s.pricePaid)}',
                  style: DT.text(size: 11.5, color: ChatColors.muted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: ChatColors.orangeBg, borderRadius: BorderRadius.circular(20)),
          child: Text(s.statusLabel,
              style: DT.text(size: 10.5, weight: FontWeight.w800, color: ChatColors.orangeText)),
        ),
      ],
    ),
  );

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _kBrandLight),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: DT.text(size: 12.5, color: ChatColors.body))),
      ],
    ),
  );

  Widget _note(IconData icon, String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ChatColors.tint,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ChatColors.tintLine),
    ),
    child: Row(
      children: [
        Icon(icon, color: _kBrand),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: DT.text(size: 13, color: ChatColors.body))),
      ],
    ),
  );

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ChatColors.red.withValues(alpha: 0.35)),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 34, color: ChatColors.red),
        const SizedBox(height: 8),
        Text(msg, textAlign: TextAlign.center, style: DT.text(size: 13, color: ChatColors.body, height: 1.45)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kBrand),
          onPressed: _load,
          child: const Text('Try again'),
        ),
      ],
    ),
  );

  Widget _state(IconData icon, String title, String body, String button, VoidCallback onTap) => ListView(
    padding: const EdgeInsets.fromLTRB(32, 90, 32, 24),
    children: [
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: ChatColors.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: _kBrand),
        ),
      ),
      const SizedBox(height: 12),
      Text(title,
          textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: ChatColors.ink)),
      const SizedBox(height: 4),
      Text(body, textAlign: TextAlign.center, style: DT.text(size: 13, color: ChatColors.muted, height: 1.45)),
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

/// Opens the plans screen. Returns true when a plan was bought.
Future<bool> openCommunicationPlans(BuildContext context) async {
  final r = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const CommunicationPlansScreen()),
  );
  return r == true;
}

