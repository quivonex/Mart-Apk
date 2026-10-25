// lib/screens/return_orders_screen.dart
//
// Orders › My returns
//   POST shipping/return-orders/       → list (filtered to my orders)
//   POST shipping/return-order/track/  → pickup courier, AWB, timeline
// Tapping a return opens its tracking sheet; "View order" opens the order.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../services/order_extras_service.dart';
import '../services/qnx_api.dart';
import '../widgets/edit_form_kit.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';

String _money(double v) {
  final n = v.round().toString();
  if (n.length <= 3) return '₹$n';
  final last3 = n.substring(n.length - 3);
  final rest = n.substring(0, n.length - 3).replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
  return '₹$rest,$last3';
}

String _pretty(String s) {
  final t = s.replaceAll('_', ' ').trim().toLowerCase();
  return t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1);
}

/// (fg, bg) for a return status.
(Color, Color) _statusColors(String s) {
  final u = s.toUpperCase();
  if (u.contains('REFUND') || u == 'RETURNED' || u.contains('COMPLETE') || u.contains('DELIVERED')) {
    return (const Color(0xFF047857), const Color(0xFFECFDF5));
  }
  if (u.contains('REJECT') || u.contains('CANCEL') || u.contains('FAIL')) {
    return (const Color(0xFFC62828), const Color(0xFFFEF2F2));
  }
  if (u.contains('REQUEST') || u.contains('PENDING')) {
    return (const Color(0xFFC2410C), const Color(0xFFFFF7ED));
  }
  return (EK.brand, EK.tint);
}

class ReturnOrdersScreen extends StatefulWidget {
  const ReturnOrdersScreen({super.key});

  @override
  State<ReturnOrdersScreen> createState() => _ReturnOrdersScreenState();
}

class _ReturnOrdersScreenState extends State<ReturnOrdersScreen> {
  List<ReturnOrderItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    final r = await OrderExtrasService.myReturns();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _items = r.data ?? [];
      } else {
        _error = r.message;
      }
    });
    if (r.needsLogin) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EK.bg,
      appBar: ekAppBar(tr('My returns'),
          subtitle: _loading ? tr('Loading…') : tr('{0} return request{1}', [_items.length, _items.length == 1 ? '' : 's'])),
      body: _loading
          ? const EkState(loading: true)
          : _error != null && _items.isEmpty
              ? EkState(error: _error, onRetry: _load)
              : RefreshIndicator(
                  color: EK.brand,
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
                          children: [
                            const Icon(Icons.assignment_return_outlined, size: 48, color: EK.brand),
                            const SizedBox(height: 12),
                            Text(tr('No return requests'),
                                textAlign: TextAlign.center,
                                style: DT.text(size: 16, weight: FontWeight.w800, color: EK.ink)),
                            const SizedBox(height: 6),
                            Text(tr('Returns you request from a delivered order show up here.'),
                                textAlign: TextAlign.center,
                                style: DT.text(size: 13, color: EK.muted, height: 1.4)),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _card(_items[i]),
                        ),
                ),
    );
  }

  Widget _card(ReturnOrderItem r) {
    final (fg, bg) = _statusColors(r.status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EK.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.returnNumber.isEmpty ? tr('Return #{0}', [r.returnId]) : r.returnNumber,
                    style: DT.text(size: 13.5, weight: FontWeight.w800, color: EK.ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(tr(_pretty(r.status)), style: DT.text(size: 11, weight: FontWeight.w800, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.product.isEmpty ? tr('Product') : r.product,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 14, weight: FontWeight.w700, color: EK.ink, height: 1.3)),
          const SizedBox(height: 4),
          Text(
            [
              tr('Order {0}', [r.orderNumber]),
              tr('Qty {0}', [r.quantity]),
              if (r.createdAt != null) qDateLabel(r.createdAt),
            ].join(' · '),
            style: DT.text(size: 11.5, color: EK.muted),
          ),
          if (r.reasonLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: tr('Reason: '), style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: tr(r.reasonLabel)),
                if (r.reasonNote.isNotEmpty) TextSpan(text: ' – ${r.reasonNote}'),
              ]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 12, color: EK.muted, height: 1.4),
            ),
          ],
          if (r.refundAmount > 0) ...[
            const SizedBox(height: 6),
            Text(tr('Refund {0}', [_money(r.refundAmount)]),
                style: DT.text(size: 13, weight: FontWeight.w800, color: EK.green)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: EK.brand, // buttons: only #093C71
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _track(r),
                    icon: const Icon(Icons.local_shipping_outlined, size: 17),
                    label: Text(tr('Track return'),
                        style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: EK.brand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: r.orderId <= 0
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: r.orderId)),
                            ),
                    icon: const Icon(Icons.receipt_outlined, size: 17),
                    label: Text(tr('View order'),
                        style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _track(ReturnOrderItem r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TrackSheet(item: r),
    );
  }
}

class _TrackSheet extends StatefulWidget {
  final ReturnOrderItem item;
  const _TrackSheet({required this.item});

  @override
  State<_TrackSheet> createState() => _TrackSheetState();
}

class _TrackSheetState extends State<_TrackSheet> {
  ReturnTrackInfo? _info;
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
    final r = await OrderExtrasService.trackReturn(widget.item.returnId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _info = r.data;
      _error = r.ok ? null : r.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(tr('Return tracking'), style: DT.text(size: 18, weight: FontWeight.w800, color: EK.ink)),
            Text(
                widget.item.returnNumber.isEmpty ? tr('Return #{0}', [widget.item.returnId]) : widget.item.returnNumber,
                style: DT.text(size: 12, color: EK.muted)),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(color: EK.brand)),
              )
            else if (i == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error ?? tr('Tracking is not available yet.'),
                        style: DT.text(size: 13, color: const Color(0xFFC2410C), height: 1.4)),
                    const SizedBox(height: 4),
                    Text(tr('Tracking starts once the pickup courier is assigned.'),
                        style: DT.text(size: 12, color: EK.muted)),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: EK.brand),
                      onPressed: _load,
                      child: Text(tr('Try again')),
                    ),
                  ],
                ),
              )
            else ...[
              _infoBox(i),
              const SizedBox(height: 16),
              if (i.events.isEmpty)
                Text(tr('No tracking updates yet.'), style: DT.text(size: 13, color: EK.muted))
              else ...[
                Text(tr('Updates'), style: DT.text(size: 13, weight: FontWeight.w800, color: EK.ink)),
                const SizedBox(height: 10),
                for (var k = 0; k < i.events.length; k++) _event(i.events[k], first: k == 0, last: k == i.events.length - 1),
              ],
              if (i.trackUrl.startsWith('http')) ...[
                const SizedBox(height: 14),
                EkButton(
                  label: tr('Open courier tracking'),
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => launchUrl(Uri.parse(i.trackUrl), mode: LaunchMode.externalApplication),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoBox(ReturnTrackInfo i) {
    Widget row(String k, String v, {bool copy = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 110, child: Text(tr(k), style: DT.text(size: 12.5, color: EK.muted))),
              Expanded(
                child: Text(tr(v.isEmpty ? '—' : v),
                    style: DT.text(size: 13, weight: FontWeight.w700, color: EK.ink)),
              ),
              if (copy && v.isNotEmpty)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: v));
                    ekSnack(context, tr('Copied'));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 16, color: EK.brand),
                  ),
                ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EK.tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EK.line),
      ),
      child: Column(
        children: [
          row(tr('Status'), _pretty(i.trackingStatus.isNotEmpty ? i.trackingStatus : i.status)),
          row(tr('Courier'), i.courier),
          row('AWB', i.awbCode, copy: true),
          if (i.etd.isNotEmpty) row(tr('Expected'), i.etd),
        ],
      ),
    );
  }

  Widget _event(ReturnTrackEvent e, {required bool first, required bool last}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: first ? EK.brand : Colors.white,
                    border: Border.all(color: EK.brand, width: 2),
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: EK.line)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.status.isEmpty ? tr('Update') : e.status,
                      style: DT.text(size: 13, weight: FontWeight.w700, color: EK.ink)),
                  if (e.location.isNotEmpty || e.date.isNotEmpty)
                    Text(tr([e.location, e.date].where((s) => s.isNotEmpty).join(' · ')),
                        style: DT.text(size: 11.5, color: EK.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
