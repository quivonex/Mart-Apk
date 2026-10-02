// lib/screens/company_stock_screen.dart
//
// Tab 1: POST /company/company/stock/      (stock, sold, remaining per product)
// Tab 2: POST /company/company/low-stock/  (products with stock_quantity <= 10)

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../models/company_stock_model.dart';
import '../services/company_service.dart';
import '../widgets/company_ui.dart';

class CompanyStockScreen extends StatefulWidget {
  final Company company;

  const CompanyStockScreen({super.key, required this.company});

  @override
  State<CompanyStockScreen> createState() => _CompanyStockScreenState();
}

class _CompanyStockScreenState extends State<CompanyStockScreen> {
  CompanyStockResponse? _stock;
  LowStockResponse? _low;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _stock == null);
    final results = await Future.wait([
      CompanyService.getStock(companyId: widget.company.id),
      CompanyService.getLowStock(companyId: widget.company.id),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _stock = results[0] as CompanyStockResponse;
      _low = results[1] as LowStockResponse;
    });
  }

  /// The current backend always uses the user's FIRST company.
  bool get _companyMismatch {
    final name = _stock?.companyName ?? '';
    return name.isNotEmpty &&
        name.trim().toLowerCase() != widget.company.name.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final lowCount = _low?.isSuccess == true ? _low!.count : 0;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: CompanyTopBar(
          title: 'Stock',
          subtitle: widget.company.name,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: DT.onyx700),
            ),
          ],
          bottom: TabBar(
            labelColor: DT.blue800,
            unselectedLabelColor: DT.slate500,
            indicatorColor: DT.blue800,
            indicatorWeight: 2.5,
            labelStyle: DT.text(size: 13, weight: FontWeight.w700),
            unselectedLabelStyle: DT.text(size: 13, weight: FontWeight.w600),
            tabs: [
              const Tab(text: 'All stock'),
              Tab(text: lowCount > 0 ? 'Low stock ($lowCount)' : 'Low stock'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: DT.blue800))
            : TabBarView(children: [_allTab(), _lowTab()]),
      ),
    );
  }

  // =================================================================
  // ALL STOCK
  // =================================================================
  Widget _allTab() {
    final s = _stock!;
    if (!s.isSuccess) {
      return StateView(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load stock',
        message: s.message ?? 'Try again in a moment.',
        actionLabel: 'Try again',
        onAction: _load,
        isError: true,
      );
    }
    if (s.products.isEmpty) {
      return const StateView(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'Stock levels show up here once you add products to this company.',
      );
    }

    final sorted = [...s.products]..sort((a, b) => a.remainingStock.compareTo(b.remainingStock));

    return RefreshIndicator(
      color: DT.blue800,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_companyMismatch) ...[_mismatchNote(s.companyName), const SizedBox(height: 12)],
          _summary(s),
          const SizedBox(height: 14),
          Text('Lowest remaining first',
              style: DT.text(size: 12, color: DT.slate500, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final p in sorted) ...[_StockRow(item: p), const SizedBox(height: 8)],
        ],
      ),
    );
  }

  Widget _summary(CompanyStockResponse s) {
    Widget cell(String label, int value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: DT.text(size: 22, weight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: DT.text(size: 11.5, color: DT.slate500, weight: FontWeight.w600)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.border),
      ),
      child: Row(children: [
        cell('Total stock', s.totalStock, DT.onyx900),
        cell('Sold', s.totalSold, DT.emerald700),
        cell('Remaining', s.totalRemaining, DT.blue800),
      ]),
    );
  }

  Widget _mismatchNote(String backendName) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: DT.amber50,
      borderRadius: BorderRadius.circular(DT.rMd),
      border: Border.all(color: DT.amber200),
    ),
    child: Text(
      'Showing stock for $backendName. The server currently returns stock for '
          'your first company only.',
      style: DT.text(size: 12, color: DT.amber900, height: 1.45),
    ),
  );

  // =================================================================
  // LOW STOCK
  // =================================================================
  Widget _lowTab() {
    final l = _low!;
    if (!l.isSuccess) {
      return StateView(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load low stock',
        message: l.message ?? 'Try again in a moment.',
        actionLabel: 'Try again',
        onAction: _load,
        isError: true,
      );
    }
    if (l.products.isEmpty) {
      return const StateView(
        icon: Icons.check_circle_outline_rounded,
        title: 'Stock levels look healthy',
        message: 'Products with 10 or fewer units left will appear here.',
      );
    }
    final sorted = [...l.products]..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
    return RefreshIndicator(
      color: DT.blue800,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _LowStockRow(item: sorted[i]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _StockRow extends StatelessWidget {
  final StockItem item;
  const _StockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isOut
        ? DT.error
        : item.isLow
        ? DT.amber700
        : DT.emerald700;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 13.5, weight: FontWeight.w700, height: 1.3)),
              ),
              const SizedBox(width: 10),
              Text(item.isOut ? 'Out of stock' : '${item.remainingStock} left',
                  style: DT.text(size: 13, weight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.soldRatio,
              minHeight: 6,
              backgroundColor: DT.slate100,
              color: DT.blue800,
            ),
          ),
          const SizedBox(height: 6),
          Text('${item.soldQuantity} sold of ${item.stockQuantity}',
              style: DT.text(size: 11.5, color: DT.slate500)),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final LowStockItem item;
  const _LowStockRow({required this.item});

  String _money(double v) =>
      v == v.roundToDouble() ? '₹${v.toInt()}' : '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final out = item.stockQuantity <= 0;
    final thumbFallback = Container(
      color: DT.slate100,
      child: const Icon(Icons.inventory_2_outlined, color: DT.slate400),
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: out ? DT.errorBorder : DT.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DT.rSm),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.thumbnail.isEmpty
                  ? thumbFallback
                  : Image.network(item.thumbnail,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => thumbFallback),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 13.5, weight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_money(item.finalPrice > 0 ? item.finalPrice : item.price),
                        style: DT.text(size: 12.5, weight: FontWeight.w700)),
                    if (item.finalPrice > 0 && item.price > item.finalPrice) ...[
                      const SizedBox(width: 6),
                      Text(_money(item.price),
                          style: DT.text(
                              size: 11.5,
                              color: DT.slate400,
                              decoration: TextDecoration.lineThrough)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: out ? DT.errorBg : DT.amber50,
              borderRadius: BorderRadius.circular(DT.rSm),
            ),
            child: Column(
              children: [
                Text('${item.stockQuantity}',
                    style: DT.text(
                        size: 16,
                        weight: FontWeight.w800,
                        color: out ? DT.error : DT.amber800)),
                Text('left',
                    style: DT.text(size: 10, color: out ? DT.error : DT.amber800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}