// lib/screens/catalog/my_products_screen.dart
//
// "My Products" – seller inventory list (design: My Products - Onyx Industrial Commerce).
//
//   Dark header: title + B2B badge, search / sort / more, metric chips
//   Search + filter chips: All · Approved · In review · Rejected · Hidden · Low stock
//   Product cards: photo, name, category • brand, price / MRP / % off,
//                  status + stock pills, product code, Edit details + Restock
//   Dark "Add Product" FAB
//
// Data: POST /product/company/products-list/ {company_id?, include_all: true}
// Needs the backend patch in product/views.py (include_all + has_pending_update).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/my_product_model.dart';
import '../services/catalog_service.dart';
import '../widgets/company_ui.dart';
import '../widgets/product_ui.dart';
import 'category_screens.dart';
import 'product_create_screen.dart';
import 'unit_screens.dart';
import 'branch_screens.dart';

enum _Filter { all, approved, review, rejected, hidden, lowStock }

enum _Sort { newest, nameAz, priceLow, priceHigh, stockLow }

class MyProductsScreen extends StatefulWidget {
  /// Show one company's products; null = all of the user's companies.
  final int? companyId;
  final String? companyName;

  const MyProductsScreen({super.key, this.companyId, this.companyName});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<MyProduct> _items = [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.newest;
  String _query = '';
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    final r = await CatalogService.getMyProducts(companyId: widget.companyId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _items = r.items;
      } else {
        _error = r.message ?? 'Could not load products';
      }
    });
  }

  // ── counts / filtering ──────────────────────────────────
  int _count(_Filter f) => _items.where((p) => _matches(p, f)).length;

  bool _matches(MyProduct p, _Filter f) => switch (f) {
    _Filter.all => true,
    _Filter.approved => p.review == ProductReviewStatus.approved && p.isActive,
    _Filter.review => p.review == ProductReviewStatus.pending || p.hasPendingUpdate,
    _Filter.rejected => p.review == ProductReviewStatus.rejected,
    _Filter.hidden => !p.isActive,
    _Filter.lowStock => p.isLowStock,
  };

  List<MyProduct> get _visible {
    final q = _query.trim().toLowerCase();
    final list = _items.where((p) => _matches(p, _filter)).where((p) {
      if (q.isEmpty) return true;
      return [p.name, p.productCode, p.categoryName, p.subcategoryName, p.brandName]
          .any((s) => s.toLowerCase().contains(q));
    }).toList();

    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => b.id.compareTo(a.id));
      case _Sort.nameAz:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.priceLow:
        list.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
      case _Sort.priceHigh:
        list.sort((a, b) => b.finalPrice.compareTo(a.finalPrice));
      case _Sort.stockLow:
        list.sort((a, b) => a.stock.compareTo(b.stock));
    }
    return list;
  }

  // ── actions ─────────────────────────────────────────────
  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductCreateScreen(companyId: widget.companyId)),
    );
    if (created == true) _load();
  }

  Future<void> _openEdit(MyProduct p) async {
    if (p.hasPendingUpdate) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
          title: Text('Update already in review',
              style: DT.text(size: 17, weight: FontWeight.w800)),
          content: Text(
            'Changes to ${p.name} are waiting for admin approval. You can edit again once '
                'that request is approved or rejected.',
            style: DT.text(size: 13, color: DT.onyx600, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK',
                  style: DT.text(size: 14, weight: FontWeight.w700, color: PX.royal600)),
            ),
          ],
        ),
      );
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductCreateScreen(existing: p)),
    );
    if (saved == true) _load();
  }

  Future<void> _restock(MyProduct p) async {
    if (p.hasPendingUpdate) {
      showCompanySnack(context, 'An update for this product is already in review.',
          error: true);
      return;
    }
    final newStock = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (_) => _RestockSheet(product: p),
    );
    if (newStock == null || !mounted) return;

    setState(() => _busyIds.add(p.id));
    final res = await CatalogService.requestRestock(p.id, newStock);
    if (!mounted) return;
    setState(() => _busyIds.remove(p.id));
    showCompanySnack(
      context,
      res.ok ? 'Stock update to $newStock sent for approval' : res.message,
      error: !res.ok,
    );
    if (res.ok) _load();
  }

  Future<void> _toggleActive(MyProduct p) async {
    final hide = p.isActive;
    final ok = await confirmAction(
      context,
      title: hide ? 'Hide ${p.name}?' : 'Show ${p.name}?',
      message: hide
          ? 'Buyers will not see this product until you show it again.'
          : 'The product will be visible to buyers again (if approved).',
      confirmLabel: hide ? 'Hide product' : 'Show product',
      destructive: hide,
    );
    if (!ok || !mounted) return;
    setState(() => _busyIds.add(p.id));
    final res = await CatalogService.setProductActive(p.id, !p.isActive);
    if (!mounted) return;
    setState(() => _busyIds.remove(p.id));
    showCompanySnack(context, res.message, error: !res.ok);
    if (res.ok) _load();
  }

  Future<void> _openSort() async {
    final picked = await showModalBottomSheet<_Sort>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (ctx) {
        Widget opt(_Sort s, String label, IconData icon) => ListTile(
          leading: Icon(icon, color: _sort == s ? PX.royal600 : DT.slate500),
          title: Text(label,
              style: DT.text(
                  size: 14,
                  weight: _sort == s ? FontWeight.w700 : FontWeight.w500,
                  color: _sort == s ? PX.royal600 : DT.onyx900)),
          trailing: _sort == s
              ? const Icon(Icons.check_circle_rounded, color: PX.royal600)
              : null,
          onTap: () => Navigator.pop(ctx, s),
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sort products', style: DT.text(size: 16, weight: FontWeight.w800)),
                ),
              ),
              opt(_Sort.newest, 'Newest first', Icons.schedule_rounded),
              opt(_Sort.nameAz, 'Name A–Z', Icons.sort_by_alpha_rounded),
              opt(_Sort.priceLow, 'Price: low to high', Icons.trending_up_rounded),
              opt(_Sort.priceHigh, 'Price: high to low', Icons.trending_down_rounded),
              opt(_Sort.stockLow, 'Stock: lowest first', Icons.inventory_2_outlined),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) setState(() => _sort = picked);
  }

  Future<void> _openMore() async {
    final companyId = widget.companyId ?? _items.firstOrNull?.companyId;
    final companyName = widget.companyName ??
        _items.where((p) => p.companyId == companyId).firstOrNull?.companyName ??
        'Company';
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            if (companyId != null) ...[
              ListTile(
                leading: const Icon(Icons.category_outlined, color: PX.royal600),
                title: Text('Categories & subcategories',
                    style: DT.text(size: 14, weight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'categories'),
              ),
              ListTile(
                leading: const Icon(Icons.store_mall_directory_outlined, color: PX.royal600),
                title: Text('Branches', style: DT.text(size: 14, weight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, 'branches'),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.straighten_rounded, color: PX.royal600),
              title: Text('Units', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'units'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: PX.royal600),
              title: Text('Refresh', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'refresh'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'categories':
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    CategoryManageScreen(companyId: companyId!, companyName: companyName)));
      case 'branches':
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    BranchManageScreen(companyId: companyId!, companyName: companyName)));
      case 'units':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const UnitManageScreen()));
      case 'refresh':
        _load();
    }
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.slate50,
      body: Column(
        children: [
          _header(),
          _searchAndFilters(),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: _fab(),
    );
  }

  // ── Dark header ─────────────────────────────────────────
  Widget _header() {
    final subtitle = widget.companyName ?? 'Merchant inventory & catalog';
    return Container(
      decoration: const BoxDecoration(
        color: DT.onyx900,
        boxShadow: [BoxShadow(color: Color(0x260F172A), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Row(
                children: [
                  _headerIcon(Icons.arrow_back_rounded, 'Back', () => Navigator.maybePop(context),
                      color: Colors.white),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('My Products',
                                style: DT.text(
                                    size: 18,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.3)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: PX.royal600,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('B2B',
                                  style: DT.text(
                                      size: 10,
                                      weight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 12, color: DT.slate400)),
                      ],
                    ),
                  ),
                  _headerIcon(Icons.search_rounded, 'Search', () => _searchFocus.requestFocus()),
                  Stack(
                    children: [
                      _headerIcon(Icons.filter_list_rounded, 'Sort', _openSort),
                      if (_sort != _Sort.newest)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: DT.onyx900, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _headerIcon(Icons.more_vert_rounded, 'More', _openMore),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                children: [
                  _metric('Total', '${_items.length} items', null, _Filter.all,
                      const Color(0xCC1E293B), const Color(0x99334155), DT.slate400, Colors.white),
                  _metric('Approved', '${_count(_Filter.approved)}', PX.emerald500,
                      _Filter.approved, const Color(0x99022C22), const Color(0x99065F46),
                      DT.emerald300, const Color(0xFFD1FAE5)),
                  _metric('In review', '${_count(_Filter.review)}', PX.amber400, _Filter.review,
                      const Color(0x99451A03), const Color(0x9992400E), DT.amber300,
                      DT.amber100),
                  _metric('Low stock', '${_count(_Filter.lowStock)}', PX.rose400,
                      _Filter.lowStock, const Color(0xCC1E293B), const Color(0x99334155),
                      const Color(0xFFFDA4AF), const Color(0xFFFFE4E6)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerIcon(IconData icon, String tip, VoidCallback onTap, {Color color = DT.slate300}) =>
      IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 22),
        splashRadius: 20,
      );

  Widget _metric(String label, String value, Color? dot, _Filter f, Color bg, Color border,
      Color labelColor, Color valueColor) {
    final sel = _filter == f && f != _Filter.all;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = f),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DT.rSm),
            border: Border.all(color: sel ? Colors.white70 : border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                    width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text('$label: ', style: DT.text(size: 12, weight: FontWeight.w500, color: labelColor)),
              Text(value, style: DT.text(size: 12, weight: FontWeight.w700, color: valueColor)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search + filter chips ───────────────────────────────
  Widget _searchAndFilters() {
    final chips = <(_Filter, String)>[
      (_Filter.all, 'All products'),
      (_Filter.approved, 'Approved'),
      (_Filter.review, 'In review'),
      (_Filter.rejected, 'Rejected'),
      (_Filter.hidden, 'Hidden'),
      (_Filter.lowStock, 'Low stock'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v),
              style: DT.text(size: 13.5, weight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search by name, product code or category…',
                hintStyle: DT.text(size: 13.5, color: DT.slate400),
                prefixIcon: const Icon(Icons.search_rounded, color: DT.slate400, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded, color: DT.slate400, size: 18),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
                filled: true,
                fillColor: const Color(0xE6F1F5F9),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DT.rMd),
                  borderSide: const BorderSide(color: DT.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DT.rMd),
                  borderSide: const BorderSide(color: PX.royal600, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (f, label) in chips)
                  if (f == _Filter.all || _count(f) > 0 || _filter == f)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip(f, label),
                    ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(_Filter f, String label) {
    final sel = _filter == f;
    final count = _count(f);
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? PX.royal600 : DT.slate100,
          borderRadius: BorderRadius.circular(DT.rSm),
          border: Border.all(color: sel ? PX.royal600 : DT.slate200),
          boxShadow: sel ? const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 2)] : null,
        ),
        child: Row(
          children: [
            Text(label,
                style: DT.text(
                    size: 12, weight: FontWeight.w600, color: sel ? Colors.white : DT.onyx700)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF1E40AF) : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: DT.text(
                      size: 10, weight: FontWeight.w700, color: sel ? Colors.white : DT.slate500)),
            ),
          ],
        ),
      ),
    );
  }

  // ── List body ───────────────────────────────────────────
  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: PX.royal600));
    }
    if (_error != null && _items.isEmpty) {
      return StateView(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load products',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
        isError: true,
      );
    }
    if (_items.isEmpty) {
      return StateView(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'Add your first product. It goes live once the admin approves it.',
        actionLabel: 'Add product',
        onAction: _openCreate,
      );
    }

    final list = _visible;
    return RefreshIndicator(
      color: PX.royal600,
      onRefresh: _load,
      child: list.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.search_off_rounded, size: 40, color: DT.slate300),
          const SizedBox(height: 10),
          Text(
            _query.isNotEmpty ? 'No products match "$_query"' : 'Nothing in this filter',
            textAlign: TextAlign.center,
            style: DT.text(size: 13.5, color: DT.slate500),
          ),
        ],
      )
          : ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _ProductCard(
          product: list[i],
          busy: _busyIds.contains(list[i].id),
          onEdit: () => _openEdit(list[i]),
          onRestock: () => _restock(list[i]),
          onToggleActive: () => _toggleActive(list[i]),
        ),
      ),
    );
  }

  Widget _fab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DT.rLg),
        boxShadow: PX.fabShadow,
      ),
      child: Material(
        color: DT.onyx900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DT.rLg),
          side: const BorderSide(color: Color(0x99334155)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(DT.rLg),
          onTap: _openCreate,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: PX.royal600,
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Add Product',
                    style: DT.text(
                        size: 14, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// PRODUCT CARD
// ===========================================================================
class _ProductCard extends StatelessWidget {
  final MyProduct product;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRestock;
  final VoidCallback onToggleActive;

  const _ProductCard({
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onRestock,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Opacity(
      opacity: p.isActive ? 1 : 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: DT.slate200),
          boxShadow: const [
            BoxShadow(color: Color(0x140F172A), blurRadius: 3, spreadRadius: 1, offset: Offset(0, 1)),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _thumb(),
                      const SizedBox(width: 14),
                      Expanded(child: _details(context)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: DT.slate100),
                  ),
                  _actions(),
                ],
              ),
            ),
            if (busy)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(DT.rLg),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: PX.royal600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    final p = product;
    Widget fallback() => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 24, color: PX.royal600),
        if (p.brandName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(p.brandName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(size: 8.5, weight: FontWeight.w700, color: DT.slate500)),
          ),
        ],
      ],
    );
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: p.thumbnail.isEmpty
          ? fallback()
          : Image.network(
        p.thumbnail,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
        loadingBuilder: (c, child, progress) => progress == null
            ? child
            : const Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: DT.slate300))),
      ),
    );
  }

  Widget _details(BuildContext context) {
    final p = product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 14, weight: FontWeight.w700, height: 1.25)),
            ),
            SizedBox(
              width: 28,
              height: 24,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz_rounded, color: DT.slate400, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                    case 'restock':
                      onRestock();
                    case 'toggle':
                      onToggleActive();
                    case 'code':
                      Clipboard.setData(ClipboardData(text: p.productCode));
                      showCompanySnack(context, 'Product code copied');
                  }
                },
                itemBuilder: (_) => [
                  _menuItem('edit', Icons.edit_outlined, 'Edit details'),
                  _menuItem('restock', Icons.autorenew_rounded, 'Restock'),
                  if (p.productCode.isNotEmpty)
                    _menuItem('code', Icons.copy_rounded, 'Copy product code'),
                  _menuItem(
                    'toggle',
                    p.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    p.isActive ? 'Hide from buyers' : 'Show to buyers',
                    color: p.isActive ? DT.error : PX.emerald600,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text.rich(
          TextSpan(
            text: p.catalogLine.isEmpty ? 'Uncategorised' : p.catalogLine,
            style: DT.text(size: 12, weight: FontWeight.w500, color: DT.slate500),
            children: [
              if (p.brandName.isNotEmpty) ...[
                const TextSpan(text: ' • '),
                TextSpan(
                    text: p.brandName,
                    style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700)),
              ],
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(formatRupees(p.finalPrice),
                style: DT.text(size: 16, weight: FontWeight.w800, color: DT.onyx900)),
            if (p.hasDiscount)
              Padding(
                padding: const EdgeInsets.only(bottom: 1.5),
                child: Text(formatRupees(p.price),
                    style: DT.text(
                        size: 12, color: DT.slate400, decoration: TextDecoration.lineThrough)),
              ),
            if (p.hasDiscount && p.discountPercent > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: DT.emerald50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${p.discountPercent}% off',
                    style: DT.text(size: 11, weight: FontWeight.w700, color: PX.emerald600)),
              ),
            if (p.unitName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 1.5),
                child: Text('/ ${p.unitName.toLowerCase()}',
                    style: DT.text(size: 11.5, color: DT.slate400)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusPill(),
            if (!p.isActive)
              const PxPill(
                  text: 'hidden',
                  bg: DT.slate100,
                  fg: DT.onyx600,
                  icon: Icons.visibility_off_outlined,
                  border: DT.slate200),
            if (p.hasPendingUpdate)
              const PxPill(
                  text: 'update in review',
                  bg: PX.royal50,
                  fg: PX.royal700,
                  icon: Icons.sync_rounded,
                  border: PX.royal200),
            _stockPill(),
          ],
        ),
        if (p.productCode.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('CODE: ${p.productCode}',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: -0.2,
                  color: DT.slate400)),
        ],
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String v, IconData icon, String label, {Color? color}) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? DT.onyx700),
            const SizedBox(width: 10),
            Text(label,
                style: DT.text(size: 13.5, weight: FontWeight.w600, color: color ?? DT.onyx900)),
          ],
        ),
      );

  Widget _statusPill() => switch (product.review) {
    ProductReviewStatus.approved => const PxPill(
        text: 'approved', bg: PX.emerald100, fg: DT.emerald700, icon: Icons.check_rounded),
    ProductReviewStatus.pending => const PxPill(
        text: 'in review', bg: DT.amber100, fg: DT.amber700, icon: Icons.schedule_rounded),
    ProductReviewStatus.rejected =>
    const PxPill(text: 'rejected', bg: PX.rose50, fg: DT.error, icon: Icons.close_rounded),
  };

  Widget _stockPill() {
    final p = product;
    final low = p.isLowStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: low ? PX.rose50 : DT.slate100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: low ? const Color(0xFFFECDD3) : DT.slate200),
      ),
      child: Text.rich(
        TextSpan(
          text: p.isOutOfStock ? 'Out of stock' : 'Stock: ',
          style: DT.text(size: 11, weight: FontWeight.w600, color: low ? DT.error : DT.onyx700),
          children: [
            if (!p.isOutOfStock)
              TextSpan(
                  text: '${p.stock}',
                  style: DT.text(
                      size: 11, weight: FontWeight.w800, color: low ? DT.error : DT.onyx900)),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    Widget btn({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
      bool primary = false,
    }) =>
        Material(
          color: primary ? Colors.white : DT.slate50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
            side: BorderSide(color: primary ? DT.slate300 : DT.slate200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(DT.rMd),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: primary ? PX.royal600 : DT.onyx600),
                  const SizedBox(width: 6),
                  Text(label,
                      style: DT.text(
                          size: 12,
                          weight: primary ? FontWeight.w700 : FontWeight.w600,
                          color: primary ? DT.onyx800 : DT.onyx700)),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        Expanded(
          child: btn(
              label: 'Edit details', icon: Icons.edit_outlined, onTap: onEdit, primary: true),
        ),
        const SizedBox(width: 8),
        btn(label: 'Restock', icon: Icons.autorenew_rounded, onTap: onRestock),
      ],
    );
  }
}

// ===========================================================================
// RESTOCK SHEET
// ===========================================================================
class _RestockSheet extends StatefulWidget {
  final MyProduct product;
  const _RestockSheet({required this.product});

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  late final _ctrl = TextEditingController(text: '${widget.product.stock}');
  String? _error;

  int get _value => int.tryParse(_ctrl.text.trim()) ?? -1;

  void _add(int n) {
    final v = (_value < 0 ? widget.product.stock : _value) + n;
    setState(() {
      _ctrl.text = '$v';
      _error = null;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _value;
    if (v < 0) {
      setState(() => _error = 'Enter the new stock quantity');
      return;
    }
    if (v == widget.product.stock) {
      setState(() => _error = 'Stock is already $v');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
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
                  decoration:
                  BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Restock', style: DT.text(size: 18, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 12.5, color: DT.slate500)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Current stock', style: DT.text(size: 12.5, color: DT.slate500)),
                  const Spacer(),
                  Text('${p.stock}${p.unitName.isEmpty ? '' : ' ${p.unitName.toLowerCase()}'}',
                      style: DT.text(size: 13.5, weight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              const PxLabel('New stock quantity', required: true),
              PxTextField(
                controller: _ctrl,
                icon: Icons.inventory_outlined,
                iconColor: PX.royal600,
                bold: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                suffixText: p.unitName.isEmpty ? null : p.unitName.toLowerCase(),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: DT.text(size: 11.5, color: DT.error)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in const [10, 50, 100, 500])
                    ActionChip(
                      label: Text('+$n',
                          style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.onyx700)),
                      backgroundColor: DT.slate50,
                      side: const BorderSide(color: DT.slate200),
                      onPressed: () => _add(n),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PX.royal50,
                  borderRadius: BorderRadius.circular(DT.rMd),
                  border: Border.all(color: PX.royal200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: PX.royal600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stock changes are sent to the admin as an update request and apply '
                            'once approved.',
                        style: DT.text(size: 12, color: DT.blue900, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PX.royal600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                  ),
                  child: Text('Send stock update',
                      style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}