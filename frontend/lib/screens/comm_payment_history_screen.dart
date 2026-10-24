// lib/screens/comm_payment_history_screen.dart
//
// QNX ReMart › Chat & Enquiry Plans › Payment history
//   POST payment/bazaar-communication/history/          (filter: All / Paid / Failed / Not completed)
//   POST olx/bazaar-communication-subscriptions/detail/ (plan detail sheet)
//
// showCommSubscriptionDetail(context, id) is also used by the plans screen
// (tap the active plan / a past plan).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/communication_plan_models.dart';
import '../services/communication_plan_history_service.dart';
import '../services/qnx_api.dart';
import '../widgets/edit_form_kit.dart';
import 'login_screen.dart';

String _rs(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  var n = parts[0];
  if (n.length > 3) {
    final last3 = n.substring(n.length - 3);
    final rest = n.substring(0, n.length - 3).replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
    n = '$rest,$last3';
  }
  return '₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
}

(Color, Color) _payColors(String s) => switch (s) {
      'paid' => (EK.green, const Color(0xFFECFDF5)),
      'failed' => (EK.red, const Color(0xFFFEF2F2)),
      _ => (const Color(0xFFC2410C), const Color(0xFFFFF7ED)),
    };

class CommPaymentHistoryScreen extends StatefulWidget {
  const CommPaymentHistoryScreen({super.key});

  @override
  State<CommPaymentHistoryScreen> createState() => _CommPaymentHistoryScreenState();
}

class _CommPaymentHistoryScreenState extends State<CommPaymentHistoryScreen> {
  static const _filters = <(String?, String)>[
    (null, 'All'),
    ('paid', 'Paid'),
    ('failed', 'Failed'),
    ('created', 'Not completed'),
  ];

  String? _status;
  final List<CommPayment> _items = [];
  int _page = 0;
  int _totalPages = 1;
  int _count = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _seq = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _more();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await CommunicationPlanHistoryService.history(status: _status, page: 1);
    if (!mounted || seq != _seq) return;
    if (r.needsLogin) {
      setState(() {
        _loading = false;
        _error = r.message;
      });
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (mounted) _reload();
      return;
    }
    setState(() {
      _loading = false;
      _items.clear();
      if (r.ok && r.data != null) {
        _items.addAll(r.data!.items);
        _page = r.data!.page;
        _totalPages = r.data!.totalPages;
        _count = r.data!.count;
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _more() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    final seq = _seq;
    setState(() => _loadingMore = true);
    final r = await CommunicationPlanHistoryService.history(status: _status, page: _page + 1);
    if (!mounted || seq != _seq) return;
    setState(() {
      _loadingMore = false;
      if (r.ok && r.data != null) {
        _items.addAll(r.data!.items);
        _page = r.data!.page;
        _totalPages = r.data!.totalPages;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EK.bg,
      appBar: ekAppBar('Payment history', subtitle: _loading ? 'Loading…' : '$_count payment${_count == 1 ? '' : 's'}'),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              children: [
                for (final (v, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == v,
                      showCheckmark: false,
                      selectedColor: EK.brand,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: _status == v ? EK.brand : EK.line),
                      labelStyle: DT.text(
                          size: 12.5, weight: FontWeight.w700, color: _status == v ? Colors.white : EK.brand),
                      onSelected: (_) {
                        if (_status == v) return;
                        setState(() => _status = v);
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const EkState(loading: true);
    if (_error != null && _items.isEmpty) return EkState(error: _error, onRetry: _reload);
    return RefreshIndicator(
      color: EK.brand,
      onRefresh: _reload,
      child: _items.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(32, 70, 32, 32),
              children: [
                const Icon(Icons.receipt_long_outlined, size: 46, color: EK.brand),
                const SizedBox(height: 12),
                Text('No payments yet',
                    textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: EK.ink)),
                const SizedBox(height: 6),
                Text('Chat plan purchases will show up here.',
                    textAlign: TextAlign.center, style: DT.text(size: 13, color: EK.muted)),
              ],
            )
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              itemCount: _items.length + (_page < _totalPages ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: SizedBox(
                            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: EK.brand))),
                  );
                }
                return _tile(_items[i]);
              },
            ),
    );
  }

  Widget _tile(CommPayment p) {
    final (fg, bg) = _payColors(p.status);
    final sid = p.subscriptionId;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _details(p),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EK.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  p.status == 'paid'
                      ? Icons.check_circle_outline_rounded
                      : (p.status == 'failed' ? Icons.error_outline_rounded : Icons.schedule_rounded),
                  color: fg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.planName, style: DT.text(size: 14, weight: FontWeight.w800, color: EK.ink)),
                    const SizedBox(height: 2),
                    Text(qDateLabel(p.when, time: true), style: DT.text(size: 11.5, color: EK.muted)),
                    if (p.status == 'failed' && p.failureReason.isNotEmpty)
                      Text(p.failureReason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11.5, color: EK.red)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_rs(p.amount), style: DT.text(size: 14.5, weight: FontWeight.w900, color: EK.brandDark)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                    child: Text(p.statusLabel, style: DT.text(size: 10.5, weight: FontWeight.w800, color: fg)),
                  ),
                  if (sid != null && p.status == 'paid' && p.active) ...[
                    const SizedBox(height: 4),
                    Text('Active', style: DT.text(size: 10.5, weight: FontWeight.w800, color: EK.green)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _details(CommPayment p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        Widget row(String k, String v, {bool copy = false}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(k, style: DT.text(size: 12.5, color: EK.muted))),
                  Expanded(
                    child: SelectableText(v.isEmpty ? '—' : v,
                        style: DT.text(size: 13, weight: FontWeight.w700, color: EK.ink)),
                  ),
                  if (copy && v.isNotEmpty)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: v));
                        Navigator.pop(ctx);
                        ekSnack(context, 'Copied');
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 16, color: EK.brand),
                      ),
                    ),
                ],
              ),
            );
        final sid = p.subscriptionId;
        return SafeArea(
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
                    decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Payment details', style: DT.text(size: 18, weight: FontWeight.w800, color: EK.ink)),
                const SizedBox(height: 12),
                row('Plan', p.planName),
                row('Amount', '${_rs(p.amount)} ${p.currency == 'INR' ? '' : p.currency}'.trim()),
                row('Status', p.statusLabel),
                row('Date', qDateLabel(p.when, time: true)),
                row('Payment ID', p.paymentId, copy: true),
                row('Order ID', p.orderId, copy: true),
                if (p.failureReason.isNotEmpty) row('Reason', p.failureReason),
                if (sid != null) ...[
                  const SizedBox(height: 14),
                  EkButton(
                    label: 'View plan details',
                    icon: Icons.workspace_premium_outlined,
                    onPressed: () {
                      Navigator.pop(ctx);
                      showCommSubscriptionDetail(context, sid);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet with olx/bazaar-communication-subscriptions/detail/.
Future<void> showCommSubscriptionDetail(BuildContext context, int subscriptionId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _SubscriptionSheet(id: subscriptionId),
  );
}

class _SubscriptionSheet extends StatefulWidget {
  final int id;
  const _SubscriptionSheet({required this.id});

  @override
  State<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<_SubscriptionSheet> {
  CommSubscription? _s;
  bool _loading = true;
  String? _error;

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
    final r = await CommunicationPlanHistoryService.subscriptionDetail(widget.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _s = r.data;
      _error = r.ok ? null : r.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    Widget row(IconData icon, String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: EK.brand),
              const SizedBox(width: 10),
              SizedBox(width: 92, child: Text(k, style: DT.text(size: 12.5, color: EK.muted))),
              Expanded(child: Text(v.isEmpty ? '—' : v, style: DT.text(size: 13, weight: FontWeight.w700, color: EK.ink))),
            ],
          ),
        );
    return SafeArea(
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
                decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: EK.brand)),
              )
            else if (s == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(_error ?? 'Plan details are not available.',
                        textAlign: TextAlign.center, style: DT.text(size: 13.5, color: EK.muted)),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: EK.brand),
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: EK.header, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.planName, style: DT.text(size: 17, weight: FontWeight.w800, color: Colors.white)),
                          Text(
                            s.currentlyValid
                                ? 'Active · ${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} left'
                                : s.statusLabel,
                            style: DT.text(size: 12, color: const Color(0xFFC9DBEE)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              row(Icons.event_available_outlined, 'Started', qDateLabel(s.startsAt)),
              row(Icons.event_busy_outlined, 'Valid till', qDateLabel(s.expiresAt)),
              row(Icons.currency_rupee_rounded, 'Paid', _rs(s.pricePaid)),
              if (s.chatLabel.isNotEmpty) row(Icons.chat_outlined, 'Chats', s.chatLabel),
              if (s.enquiryLabel.isNotEmpty) row(Icons.forum_outlined, 'Enquiries', s.enquiryLabel),
            ],
          ],
        ),
      ),
    );
  }
}
