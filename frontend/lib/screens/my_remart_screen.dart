// lib/screens/my_remart_screen.dart
//
// QNX ReMart › My items
//   Tab 1 "My items"      POST olx/my-listings/   (status, expiry, views)
//   Tab 2 "My enquiries"  POST olx/enquiries/     (enquiries I sent to sellers)
// "Sell" opens the add-item form.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../services/remart_edit_service.dart';
import 'remart_edit_screen.dart';
import 'remart_screens.dart';
import 'package:qnx_mart/l10n/app_language.dart';
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

class _MR {
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

String _price(double v) {
  final n = v.round().toString();
  if (n.length <= 3) return '₹$n';
  final last3 = n.substring(n.length - 3);
  final rest = n.substring(0, n.length - 3).replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
  return '₹$rest,$last3';
}

String _date(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${tr(m[l.month - 1])} ${l.year}';
}

(Color, Color, String) _statusStyle(String s) => switch (s.toLowerCase()) {
  'active' => (const Color(0xFF047857), const Color(0xFFECFDF5), tr('Live')),
  'pending' => (const Color(0xFFC2410C), const Color(0xFFFFF7ED), tr('Pending')),
  'draft' => (const Color(0xFF475569), const Color(0xFFF1F5F9), tr('Draft')),
  'expired' => (const Color(0xFFC62828), const Color(0xFFFEF2F2), tr('Expired')),
  'sold' => (const Color(0xFF062A50), const Color(0xFFEAF1F9), tr('Sold')),
  'rejected' => (const Color(0xFFC62828), const Color(0xFFFEF2F2), tr('Rejected')),
  '' => (const Color(0xFF475569), const Color(0xFFF1F5F9), '—'),
  _ => (const Color(0xFF475569), const Color(0xFFF1F5F9), s[0].toUpperCase() + s.substring(1)),
};

class MyRemartScreen extends StatefulWidget {
  final int initialTab;
  const MyRemartScreen({super.key, this.initialTab = 0});

  @override
  State<MyRemartScreen> createState() => _MyRemartScreenState();
}

class _MyRemartScreenState extends State<MyRemartScreen> {
  bool _loadingItems = true;
  bool _loadingEnq = true;
  String? _itemsError;
  String? _enqError;
  List<RemartListing> _items = [];
  List<Map<String, dynamic>> _enquiries = [];
  final Set<int> _soldBusy = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadEnquiries();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loadingItems = true;
      _itemsError = null;
    });
    final (items, err) = await RemartApi.myListings();
    if (!mounted) return;
    setState(() {
      _loadingItems = false;
      _items = items;
      _itemsError = err;
    });
  }

  Future<void> _loadEnquiries() async {
    setState(() {
      _loadingEnq = true;
      _enqError = null;
    });
    final (list, err) = await RemartApi.myEnquiries();
    if (!mounted) return;
    setState(() {
      _loadingEnq = false;
      _enquiries = list;
      _enqError = err;
    });
  }

  Future<void> _sell() async {
    if (await openRemartPosting(context)) _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final live = _items.where((e) => e.status == 'active').length;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        backgroundColor: _MR.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('My ReMart'), style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
              Text(_loadingItems ? tr('Loading…') : tr('{0} items · {1} live', [_items.length, live]),
                  style: DT.text(size: 11.5, color: const Color(0xCCFFFFFF))),
            ],
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xB3FFFFFF),
            labelStyle: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white),
            tabs: [Tab(text: tr('My items')), Tab(text: tr('My enquiries'))],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _sell,
          backgroundColor: _kBrand, // buttons: only #093C71
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('Sell item'), style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: TabBarView(
          children: [
            _itemsTab(),
            _enquiriesTab(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- items
  Widget _itemsTab() {
    if (_loadingItems) return const Center(child: CircularProgressIndicator(color: _MR.brand));
    if (_itemsError != null) {
      return _state(Icons.cloud_off_rounded, tr('Could not load your items'), _itemsError!, onRetry: _loadItems);
    }
    if (_items.isEmpty) {
      return _state(Icons.storefront_outlined, tr('Nothing posted yet'),
          tr('Sell something you no longer need. Your first listing is free!'),
          actionLabel: tr('Sell an item'), onAction: _sell);
    }
    return RefreshIndicator(
      color: _MR.brand,
      onRefresh: _loadItems,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _itemCard(_items[i]),
      ),
    );
  }

  Widget _itemCard(RemartListing l) {
    final (fg, bg, label) = _statusStyle(l.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemartListingDetailScreen(listing: l))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _MR.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: l.images.isEmpty
                          ? Container(color: _MR.tint, child: const Icon(Icons.image_outlined, color: _MR.hint))
                          : Image.network(l.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: _MR.tint)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                              child: Text(tr(label), style: DT.text(size: 10.5, weight: FontWeight.w800, color: fg)),
                            ),
                            const Spacer(),
                            if (l.viewsCount > 0) ...[
                              const Icon(Icons.visibility_outlined, size: 13, color: _MR.hint),
                              const SizedBox(width: 3),
                              Text('${l.viewsCount}', style: DT.text(size: 11, color: _MR.muted)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(trData(l.title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 14, weight: FontWeight.w700, color: _MR.ink, height: 1.3)),
                        const SizedBox(height: 4),
                        Text(tr(_price(l.price)), style: DT.text(size: 15, weight: FontWeight.w900, color: _MR.brandDark)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (l.location.isNotEmpty) l.location,
                            if (l.expiresAt.isNotEmpty) 'till ${_date(l.expiresAt)}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11.5, color: _MR.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: _MR.line),
              const SizedBox(height: 10),
              _itemActions(l),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- edit / sold
  Widget _smallBtn(String label, IconData icon, VoidCallback? onTap) => SizedBox(
        height: 36,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: _kBrand, // buttons: only #093C71
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kBrand.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: Icon(icon, size: 16),
          label: Text(tr(label), style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
        ),
      );

  Widget _itemActions(RemartListing l) {
    final busy = _soldBusy.contains(l.id);
    final canSell = l.status == 'active';
    return Row(
      children: [
        Expanded(child: _smallBtn(tr('Edit'), Icons.edit_outlined, () => _edit(l))),
        if (canSell) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _smallBtn(busy ? tr('Saving…') : tr('Mark as sold'), Icons.sell_outlined,
                busy ? null : () => _markSold(l)),
          ),
        ],
      ],
    );
  }

  Future<void> _edit(RemartListing l) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RemartEditScreen(listingId: l.id, title: tr(l.title))),
    );
    if (saved == true) _loadItems();
  }

  Future<void> _markSold(RemartListing l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Mark as sold?'), style: DT.text(size: 17, weight: FontWeight.w800, color: _MR.ink)),
        content: Text(tr('"{0}" will no longer be shown to buyers.', [l.title]),
            style: DT.text(size: 13.5, color: _MR.muted, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel'), style: DT.text(size: 13.5, weight: FontWeight.w700, color: _MR.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kBrand),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Mark as sold')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _soldBusy.add(l.id));
    final r = await RemartEditService.markSold(l.id);
    if (!mounted) return;
    setState(() => _soldBusy.remove(l.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(r.ok ? tr('Marked as sold') : r.message,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: r.ok ? const Color(0xFF047857) : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    if (r.ok) _loadItems();
  }

  // ---------------------------------------------------------------- enquiries
  Widget _enquiriesTab() {
    if (_loadingEnq) return const Center(child: CircularProgressIndicator(color: _MR.brand));
    if (_enqError != null) {
      return _state(Icons.cloud_off_rounded, tr('Could not load enquiries'), _enqError!, onRetry: _loadEnquiries);
    }
    if (_enquiries.isEmpty) {
      return _state(Icons.forum_outlined, tr('No enquiries yet'), tr('Enquiries you send to sellers will appear here.'));
    }
    return RefreshIndicator(
      color: _MR.brand,
      onRefresh: _loadEnquiries,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _enquiries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final e = _enquiries[i];
          final status = '${e['status'] ?? ''}';
          final (fg, bg, label) = _statusStyle(status);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _MR.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sell_outlined, size: 16, color: _MR.brand),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${e['listing_title'] ?? 'Item'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 14, weight: FontWeight.w700, color: _MR.ink)),
                    ),
                    if (status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                        child: Text(tr(label), style: DT.text(size: 10.5, weight: FontWeight.w800, color: fg)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${e['message'] ?? ''}', style: DT.text(size: 13, color: DT.onyx700, height: 1.45)),
                const SizedBox(height: 8),
                Text(_date('${e['created_at'] ?? ''}'), style: DT.text(size: 11, color: _MR.hint)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- states
  Widget _state(IconData icon, String title, String body,
      {VoidCallback? onRetry, String? actionLabel, VoidCallback? onAction}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: _MR.tint, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: _MR.brand),
          ),
        ),
        const SizedBox(height: 16),
        Text(tr(title), textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _MR.ink)),
        const SizedBox(height: 6),
        Text(tr(body), textAlign: TextAlign.center, style: DT.text(size: 13, color: _MR.muted, height: 1.45)),
        if (onRetry != null || onAction != null) ...[
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kBrand), // buttons: only #093C71
              onPressed: onRetry ?? onAction,
              child: Text(onRetry != null ? tr('Try again') : actionLabel ?? tr('OK')),
            ),
          ),
        ],
      ],
    );
  }
}
