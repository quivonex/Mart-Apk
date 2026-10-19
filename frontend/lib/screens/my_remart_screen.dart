// lib/screens/my_remart_screen.dart
//
// QNX ReMart › My items
//   Tab 1 "My items"      POST olx/my-listings/   (status, expiry, views)
//   Tab 2 "My enquiries"  POST olx/enquiries/     (enquiries I sent to sellers)
// "Sell" opens the add-item form.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import 'remart_screens.dart';

class _MR {
  static const brand = Color(0xFF6366F1);
  static const brandDark = Color(0xFF4338CA);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEEF2FF);
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
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

(Color, Color, String) _statusStyle(String s) => switch (s.toLowerCase()) {
  'active' => (const Color(0xFF047857), const Color(0xFFECFDF5), 'Live'),
  'pending' => (const Color(0xFFB45309), const Color(0xFFFFFBEB), 'Pending'),
  'draft' => (const Color(0xFF475569), const Color(0xFFF1F5F9), 'Draft'),
  'expired' => (const Color(0xFFB91C1C), const Color(0xFFFEF2F2), 'Expired'),
  'sold' => (const Color(0xFF4338CA), const Color(0xFFEEF2FF), 'Sold'),
  'rejected' => (const Color(0xFFB91C1C), const Color(0xFFFEF2F2), 'Rejected'),
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
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: DT.headerGradient)),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My ReMart', style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
              Text(_loadingItems ? 'Loading…' : '${_items.length} items · $live live',
                  style: DT.text(size: 11.5, color: const Color(0xCCFFFFFF))),
            ],
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xB3FFFFFF),
            labelStyle: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white),
            tabs: const [Tab(text: 'My items'), Tab(text: 'My enquiries')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _sell,
          backgroundColor: const Color(0xFFF97316),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Sell item', style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
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
      return _state(Icons.cloud_off_rounded, 'Could not load your items', _itemsError!, onRetry: _loadItems);
    }
    if (_items.isEmpty) {
      return _state(Icons.storefront_outlined, 'Nothing posted yet',
          'Sell something you no longer need. Your first listing is free!',
          actionLabel: 'Sell an item', onAction: _sell);
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
          child: Row(
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
                          child: Text(label, style: DT.text(size: 10.5, weight: FontWeight.w800, color: fg)),
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
                    Text(l.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14, weight: FontWeight.w700, color: _MR.ink, height: 1.3)),
                    const SizedBox(height: 4),
                    Text(_price(l.price), style: DT.text(size: 15, weight: FontWeight.w900, color: _MR.brandDark)),
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
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- enquiries
  Widget _enquiriesTab() {
    if (_loadingEnq) return const Center(child: CircularProgressIndicator(color: _MR.brand));
    if (_enqError != null) {
      return _state(Icons.cloud_off_rounded, 'Could not load enquiries', _enqError!, onRetry: _loadEnquiries);
    }
    if (_enquiries.isEmpty) {
      return _state(Icons.forum_outlined, 'No enquiries yet', 'Enquiries you send to sellers will appear here.');
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
                        child: Text(label, style: DT.text(size: 10.5, weight: FontWeight.w800, color: fg)),
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
        Text(title, textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _MR.ink)),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: DT.text(size: 13, color: _MR.muted, height: 1.45)),
        if (onRetry != null || onAction != null) ...[
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _MR.brand),
              onPressed: onRetry ?? onAction,
              child: Text(onRetry != null ? 'Try again' : actionLabel ?? 'OK'),
            ),
          ),
        ],
      ],
    );
  }
}
