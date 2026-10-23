// lib/screens/my_properties_screen.dart
//
// QNX Mart › Real Estate › My Properties
//   • Every property the user posted, with approval + listing status
//     (free period / paid subscription, days left), views and enquiries.
//   • "Activate / Renew" → choose a listing plan → Razorpay → verify.
//   • "Add property" opens the property form.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/design_tokens.dart';
import '../services/my_property_service.dart';
import '../utils/shared_preferences_helper.dart';
import 'property_create_screen.dart';
import 'property_detail_screen.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kRed = Color(0xFFC62828);
const _kRedBg = Color(0xFFFEF2F2);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _MP {
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const violet = Color(0xFF1E5A9C);
  static const orange = Color(0xFFF7931E);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const tintLine = Color(0xFFC9DBEE);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

String _inr(double v) {
  final n = v.round().toString();
  if (n.length <= 3) return '₹$n';
  final last3 = n.substring(n.length - 3);
  final rest = n.substring(0, n.length - 3).replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
  return '₹$rest,$last3';
}

String _date(DateTime? d) {
  if (d == null) return '—';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

String _label(String key) => key
    .replaceAll('_', ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  bool _loading = true;
  String? _error;
  List<MyProperty> _items = [];
  int? _payingId;

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
    final r = await MyPropertyService.myProperties();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = r.data ?? [];
      _error = r.ok ? null : r.message;
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? _kRed : _MP.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _add() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const PropertyCreateScreen()));
    if (created == true) _load();
  }

  void _open(MyProperty p) {
    if (p.slug.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PremiumPropertyDetailScreen(slug: p.slug, previewName: p.title)),
    );
  }

  // ---------------------------------------------------------------- pay
  Future<void> _activate(MyProperty p) async {
    if (kIsWeb) {
      _snack('Online payment works in the QNX Mart Android app.', error: true);
      return;
    }
    final plan = await showModalBottomSheet<PropertyPlan>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanSheet(propertyTitle: p.title),
    );
    if (plan == null || !mounted) return;

    setState(() => _payingId = p.id);
    final created = await MyPropertyService.createOrder(p.id, plan.id);
    if (!mounted) return;
    final d = created.data;
    final orderId = '${d?['order_id'] ?? ''}';
    final key = '${d?['key'] ?? ''}';
    final amount = (d?['amount_paise'] as int?) ?? 0;
    if (!created.ok || orderId.isEmpty || key.isEmpty || amount <= 0) {
      setState(() => _payingId = null);
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
        'name': 'QNX Mart Real Estate',
        'description': '${plan.name} · ${p.title}',
        'prefill': {if (email != null && email.isNotEmpty) 'email': email},
        'theme': {'color': '#093C71'},
      });
    } catch (e) {
      razorpay.clear();
      if (mounted) setState(() => _payingId = null);
      if (mounted) _snack('Could not open payment: $e', error: true);
      return;
    }
    final (success, failure) = await done.future;
    razorpay.clear();
    if (!mounted) return;
    if (success == null) {
      setState(() => _payingId = null);
      final cancelled = failure != null && failure.code == Razorpay.PAYMENT_CANCELLED;
      _snack(cancelled ? 'Payment was cancelled.' : 'Payment failed.', error: true);
      return;
    }
    final v = await MyPropertyService.verify(
      orderId: success.orderId ?? orderId,
      paymentId: success.paymentId ?? '',
      signature: success.signature ?? '',
    );
    if (!mounted) return;
    setState(() => _payingId = null);
    if (!v.ok) {
      _snack('${v.message}. If money was deducted, contact support with ${success.paymentId}.', error: true);
      return;
    }
    _snack('${p.title} is active for ${plan.days} days.');
    _load();
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final live = _items.where((e) => e.isRunning && e.approved).length;
    return Scaffold(
      backgroundColor: _MP.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Properties', style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
            Text(_loading ? 'Loading…' : '${_items.length} listed · $live live',
                style: DT.text(size: 11.5, color: const Color(0xCCFFFFFF))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: _kBrand, // buttons: only #093C71
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_home_work_outlined),
        label: Text('Add property', style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _MP.brand))
          : _error != null
          ? _state(Icons.cloud_off_rounded, 'Could not load your properties', _error!, retry: true)
          : _items.isEmpty
          ? _state(Icons.home_work_outlined, 'No properties yet',
          'List your flat, plot or shop – the first days are free.')
          : RefreshIndicator(
        color: _MP.brand,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) => _card(_items[i]),
        ),
      ),
    );
  }

  Widget _state(IconData icon, String title, String body, {bool retry = false}) => ListView(
    padding: const EdgeInsets.fromLTRB(32, 70, 32, 32),
    children: [
      Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(color: _MP.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 38, color: _MP.brand),
        ),
      ),
      const SizedBox(height: 16),
      Text(title, textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _MP.ink)),
      const SizedBox(height: 6),
      Text(body, textAlign: TextAlign.center, style: DT.text(size: 13, color: _MP.muted, height: 1.45)),
      const SizedBox(height: 18),
      Center(
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kBrand), // buttons: only #093C71
          onPressed: retry ? _load : _add,
          child: Text(retry ? 'Try again' : 'Add property'),
        ),
      ),
    ],
  );

  Widget _card(MyProperty p) {
    final days = p.daysLeft;
    final running = p.isRunning;
    final (approvalFg, approvalBg, approvalText) = p.approved
        ? (const Color(0xFF047857), const Color(0xFFECFDF5), 'Approved')
        : (const Color(0xFFB45309), const Color(0xFFFFFBEB), 'Under review');
    final String period;
    if (p.source == 'admin') {
      period = 'Managed by QNX Mart';
    } else if (p.subscriptionActive && running) {
      period = 'Paid plan · ${days ?? '—'} days left (till ${_date(p.subscriptionExpiry)})';
    } else if (running && p.freeExpiry != null) {
      period = 'Free period · ${days ?? '—'} days left';
    } else {
      period = 'Not live – activate a plan to show buyers';
    }
    final paying = _payingId == p.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MP.line),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _open(p),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: p.image.isEmpty
                          ? Container(color: _MP.tint, child: const Icon(Icons.apartment_rounded, color: _MP.hint))
                          : Image.network(p.image,
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _MP.tint)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _pill(approvalText, approvalFg, approvalBg),
                            _pill(running ? 'Live' : 'Not live', running ? const Color(0xFF047857) : _kRed,
                                running ? const Color(0xFFECFDF5) : _kRedBg),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(p.title.isEmpty ? 'Untitled property' : p.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 14.5, weight: FontWeight.w800, color: _MP.ink, height: 1.3)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (p.propertyType.isNotEmpty) _label(p.propertyType),
                            if (p.transactionType.isNotEmpty) _label(p.transactionType),
                            if (p.location.isNotEmpty) p.location,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11.5, color: _MP.muted),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 13, color: _MP.hint),
                            const SizedBox(width: 3),
                            Text('${p.views}', style: DT.text(size: 11.5, color: _MP.muted)),
                            const SizedBox(width: 12),
                            const Icon(Icons.forum_outlined, size: 13, color: _MP.hint),
                            const SizedBox(width: 3),
                            Text('${p.enquiries} enquiries', style: DT.text(size: 11.5, color: _MP.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: running ? _MP.tint : const Color(0xFFFFF7ED),
              border: Border(top: BorderSide(color: running ? _MP.tintLine : const Color(0xFFFED7AA))),
            ),
            child: Row(
              children: [
                Icon(running ? Icons.timer_outlined : Icons.warning_amber_rounded,
                    size: 18, color: running ? _MP.brand : _MP.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(period,
                      style: DT.text(
                          size: 12,
                          weight: FontWeight.w600,
                          color: running ? _MP.brandDark : const Color(0xFF9A3412))),
                ),
                if (p.canPay)
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: _payingId != null ? null : () => _activate(p),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBrand, // buttons: only #093C71
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: paying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(running ? 'Extend' : 'Activate',
                          style: DT.text(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: DT.text(size: 10.5, weight: FontWeight.w800, color: fg)),
  );
}

// =====================================================================
// PLAN PICKER SHEET
// =====================================================================
class _PlanSheet extends StatefulWidget {
  final String propertyTitle;
  const _PlanSheet({required this.propertyTitle});

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  bool _loading = true;
  String? _error;
  List<PropertyPlan> _plans = [];
  int? _sel;

  @override
  void initState() {
    super.initState();
    MyPropertyService.plans().then((r) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _plans = r.data ?? [];
        _error = r.ok ? null : r.message;
        if (_plans.isNotEmpty) _sel = _plans.first.id;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sel = _plans.where((p) => p.id == _sel).firstOrNull;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
              decoration: const BoxDecoration(gradient: _kHeader),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Choose a listing plan',
                                style: DT.text(size: 16.5, weight: FontWeight.w800, color: Colors.white)),
                            Text(widget.propertyTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(size: 12, color: const Color(0xD9FFFFFF))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: _MP.brand)),
              )
                  : _error != null || _plans.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? 'No plans are available right now.',
                    textAlign: TextAlign.center, style: DT.text(size: 13, color: _MP.muted)),
              )
                  : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  for (final p in _plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _planTile(p),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: sel == null ? _MP.line : _kBrand, // buttons: only #093C71
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: sel == null ? null : () => Navigator.pop(context, sel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(sel == null ? 'Select a plan' : 'Pay ${_inr(sel.price)}',
                          style: DT.text(size: 14.5, weight: FontWeight.w800, color: sel == null ? _MP.muted : Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planTile(PropertyPlan p) {
    final s = p.id == _sel;
    return GestureDetector(
      onTap: () => setState(() => _sel = p.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s ? _MP.tint : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s ? _MP.brand : _MP.line, width: s ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(s ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: s ? _MP.brand : _MP.hint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: DT.text(size: 14.5, weight: FontWeight.w800, color: _MP.ink)),
                  Text('${p.days} days on QNX Mart', style: DT.text(size: 12, color: _MP.muted)),
                ],
              ),
            ),
            Text(_inr(p.price), style: DT.text(size: 17, weight: FontWeight.w900, color: s ? _MP.brandDark : _MP.ink)),
          ],
        ),
      ),
    );
  }
}
