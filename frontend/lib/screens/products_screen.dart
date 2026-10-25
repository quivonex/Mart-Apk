import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../widgets/product_card.dart';
import '../utils/cart_helper.dart';
import 'franchise_plans_screen.dart';
import 'product_enquiry_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';
import 'product_detail_screen.dart'; // 🆕 IMPORT ADD KELA

// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kTint = Color(0xFFEAF1F9);
const _kLine = Color(0xFFC9DBEE);
const _kRed = Color(0xFFC62828);
const _kRedBg = Color(0xFFFEF2F2);
const _kRedLine = Color(0xFFFECACA);
const _kOrange = Color(0xFFF7931E);

// Colours used only on this screen (the rest come from DT).
class _C {
  static const navy3 = Color(0xFF062A50);
  static const blue600 = Color(0xFF093C71);
}

enum _Sort { recommended, priceLow, priceHigh, nameAz, discount }

extension on _Sort {
  String get label => switch (this) {
    _Sort.recommended => tr('Recommended'),
    _Sort.priceLow => tr('Price: low to high'),
    _Sort.priceHigh => tr('Price: high to low'),
    _Sort.nameAz => tr('Name: A to Z'),
    _Sort.discount => tr('Biggest discount'),
  };

  IconData get icon => switch (this) {
    _Sort.recommended => Icons.auto_awesome_outlined,
    _Sort.priceLow => Icons.trending_up_rounded,
    _Sort.priceHigh => Icons.trending_down_rounded,
    _Sort.nameAz => Icons.sort_by_alpha_rounded,
    _Sort.discount => Icons.local_offer_outlined,
  };
}

/// Products tab (shown inside HomeScreen, so no Scaffold here).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  List<String> _categories = ['All'];

  bool _isLoading = true;
  String? _error;

  String _selectedCategory = 'All';
  String _searchQuery = '';
  _Sort _sort = _Sort.recommended;
  bool _franchiseOnly = false;

  /// How many filtered products are currently shown (client-side paging).
  int _visibleCount = _pageSize;

  bool get _hasMore => _visibleCount < _filtered.length;
  bool get _hasActiveFilters =>
      _sort != _Sort.recommended || _franchiseOnly;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // =================================================================
  // DATA
  // =================================================================
  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = _allProducts.isEmpty; // keep grid visible on refresh
      _error = null;
    });

    try {
      final response = await ProductService.getApprovedProductList();
      if (!mounted) return;

      final uniqueCategories = response.data
          .map((p) => p.categoryName)
          .where((c) => c.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _allProducts = response.data;
        _categories = ['All', ...uniqueCategories];
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }
        _isLoading = false;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  double _num(Object? v) =>
      double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  /// Rebuilds [_filtered]. Call inside setState.
  void _applyFilters() {
    final q = _searchQuery;
    var list = _allProducts.where((p) {
      if (_selectedCategory != 'All' && p.categoryName != _selectedCategory) {
        return false;
      }
      if (_franchiseOnly && !p.isFranchiseAvailable) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.companyName.toLowerCase().contains(q) ||
          p.categoryName.toLowerCase().contains(q) ||
          p.brandName.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case _Sort.recommended:
        break;
      case _Sort.priceLow:
        list.sort((a, b) => _num(a.finalPrice).compareTo(_num(b.finalPrice)));
        break;
      case _Sort.priceHigh:
        list.sort((a, b) => _num(b.finalPrice).compareTo(_num(a.finalPrice)));
        break;
      case _Sort.nameAz:
        list.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _Sort.discount:
        list.sort((a, b) =>
            _num(b.discountValue).compareTo(_num(a.discountValue)));
        break;
    }

    _filtered = list;
    _visibleCount = _pageSize;
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q == _searchQuery) return;
    setState(() {
      _searchQuery = q;
      _applyFilters();
    });
    _jumpToTop();
  }

  void _selectCategory(String category) {
    if (category == _selectedCategory) return;
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
    _jumpToTop();
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _sort = _Sort.recommended;
      _franchiseOnly = false;
      _applyFilters();
    });
  }

  void _onScroll() {
    if (!_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      setState(() => _visibleCount += _pageSize);
    }
  }

  void _jumpToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  // =================================================================
  // NAVIGATION
  // =================================================================
  void _openFranchise(Product product) {
    if (!product.isFranchiseAvailable) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FranchisePlansScreen(
          productSlug: product.slug,
          productName: product.name,
        ),
      ),
    );
  }

  void _openEnquiry(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEnquiryScreen(product: product),
      ),
    );
  }

  // 🆕 Detail Screen la navigate karnyachi method add keli
  void _openDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  void _openProductQuickView(Product p) {
    final fp = double.tryParse(p.finalPrice) ?? 0;
    final mrp = double.tryParse(p.price) ?? 0;
    final off = (mrp > fp && fp > 0) ? (((mrp - fp) / mrp) * 100).round() : 0;
    final stock = p.stockQuantity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: p.thumbnail.isEmpty
                        ? Container(color: DT.slate100, child: const Icon(Icons.inventory_2_outlined, size: 48, color: DT.slate300))
                        : Image.network(
                      p.thumbnail,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : Container(color: DT.slate100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kBrand))),
                      errorBuilder: (_, __, ___) => Container(color: DT.slate100, child: const Icon(Icons.broken_image_outlined, size: 40, color: DT.slate300)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr([p.categoryName, p.brandName].where((s) => s.isNotEmpty).join(' · ').toUpperCase()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 10.5, weight: FontWeight.w800, color: DT.slate500, letterSpacing: 0.6),
                    ),
                  ),
                  if (p.isFranchiseAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _kTint, borderRadius: BorderRadius.circular(999)),
                      child: Text(tr('🏪 Franchise'), style: DT.text(size: 10.5, weight: FontWeight.w800, color: _kBrand)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(trData(p.name), style: DT.text(size: 18, weight: FontWeight.w800, color: DT.onyx900, height: 1.25)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${p.finalPrice}', style: DT.text(size: 22, weight: FontWeight.w900, color: DT.onyx900)),
                  if (off > 0) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('₹${p.price}', style: DT.text(size: 13, color: DT.slate400, decoration: TextDecoration.lineThrough)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: DT.emerald50, borderRadius: BorderRadius.circular(4)),
                      child: Text(tr('{0}% off', [off]), style: DT.text(size: 11, weight: FontWeight.w800, color: DT.emerald700)),
                    ),
                  ],
                ],
              ),
              if (stock != null) ...[
                const SizedBox(height: 6),
                Text(
                  stock <= 0 ? tr('Out of stock') : tr('In stock: {0}{1}', [stock, p.unitName.isEmpty ? '' : ' ${p.unitName.toUpperCase()}']),
                  style: DT.text(size: 12.5, weight: FontWeight.w700, color: stock <= 0 ? _kRed : DT.emerald700),
                ),
              ],
              if (p.companyName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.storefront_outlined, size: 15, color: DT.slate400),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(tr('Sold by {0}', [p.companyName]), maxLines: 1, overflow: TextOverflow.ellipsis, style: DT.text(size: 12.5, color: DT.onyx600)),
                  ),
                ]),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  // SORT & FILTER SHEET
  // =================================================================
  Future<void> _openSortSheet() async {
    var sort = _sort;
    var franchiseOnly = _franchiseOnly;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DT.slate200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(tr('Sort & filter'),
                        style: DT.text(size: 17, weight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setSheet(() {
                        sort = _Sort.recommended;
                        franchiseOnly = false;
                      }),
                      child: Text(tr('Reset'),
                          style: DT.text(
                              size: 13,
                              weight: FontWeight.w700,
                              color: _C.blue600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tr('Sort by'),
                    style: DT.text(
                        size: 12, weight: FontWeight.w600, color: DT.slate500)),
                const SizedBox(height: 8),
                for (final s in _Sort.values)
                  _SortOption(
                    sort: s,
                    selected: s == sort,
                    onTap: () => setSheet(() => sort = s),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: DT.slate50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                    border: Border.all(color: DT.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 20, color: _kBrand),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Franchise available only'),
                                style: DT.text(
                                    size: 13, weight: FontWeight.w600)),
                            Text(tr('Show products you can take a franchise of'),
                                style: DT.text(size: 11, color: DT.slate500)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: franchiseOnly,
                        activeColor: _C.blue600,
                        onChanged: (v) => setSheet(() => franchiseOnly = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand, // buttons: only #093C71
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DT.rMd),
                      ),
                    ),
                    child: Text(tr('Show results'),
                        style: DT.text(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied == true && mounted) {
      setState(() {
        _sort = sort;
        _franchiseOnly = franchiseOnly;
        _applyFilters();
      });
      _jumpToTop();
    }
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DT.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // ---------- Sticky header ----------
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: DT.border)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 8),
                _buildFilterButton(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final category = tr(_categories[i]);
                return _CategoryChip(
                  label: tr(category),
                  selected: category == _selectedCategory,
                  onTap: () => _selectCategory(category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: DT.text(size: 13.5, weight: FontWeight.w500),
        cursorColor: _C.blue600,
        decoration: InputDecoration(
          hintText: tr('Search products, brands, suppliers'),
          hintStyle: DT.text(size: 13, color: DT.slate400),
          prefixIcon:
          const Icon(Icons.search_rounded, color: DT.onyx600, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
            tooltip: tr('Clear search'),
            onPressed: _searchController.clear,
            icon: const Icon(Icons.close_rounded,
                color: DT.slate400, size: 18),
          ),
          filled: true,
          fillColor: DT.slate100,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DT.rLg),
            borderSide: const BorderSide(color: DT.slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DT.rLg),
            borderSide: const BorderSide(color: _C.blue600, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    final active = _hasActiveFilters;
    return Tooltip(
      message: tr('Sort & filter'),
      child: Material(
        color: active ? _kBrand : DT.slate100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DT.rLg),
          side: BorderSide(color: active ? _kBrand : DT.slate200),
        ),
        child: InkWell(
          onTap: _openSortSheet,
          borderRadius: BorderRadius.circular(DT.rLg),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.tune_rounded,
                    size: 20, color: active ? Colors.white : DT.onyx700),
                if (active)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _kOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kBrand, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Content ----------
  Widget _buildContent() {
    if (_isLoading) return _buildSkeletonGrid();
    if (_error != null && _allProducts.isEmpty) return _buildErrorState();

    final shown = _filtered.take(_visibleCount).toList();

    return RefreshIndicator(
      color: _C.navy3,
      onRefresh: _loadProducts,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            sliver: SliverToBoxAdapter(child: _buildResultsBar()),
          ),
          if (_error != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              sliver: SliverToBoxAdapter(child: _buildInlineError()),
            ),
          if (_filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // 🆕 Home screen sarkha height kela ahe jene image pori disel aani buttns khali basatil
                  mainAxisExtent: (MediaQuery.of(context).size.width - 44) / 2 + 105,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final p = shown[i];
                    return _productCard(p); // 🆕 Home screen sarkha custom card
                  },
                  childCount: shown.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildListFooter()),
          ],
        ],
      ),
    );
  }

  // 🆕 Home Screen sarkha Product Card (Image purni disnya sathi BoxFit.contain) AANI DETAIL VAR NAVIGATE KARNAYCHA ONTAP ADD KELA
  Widget _productCard(Product p) {
    final fp = double.tryParse(p.finalPrice) ?? 0;
    final mrp = double.tryParse(p.price) ?? 0;
    final showMrp = mrp > fp && fp > 0;
    final stock = p.stockQuantity;
    final sub = [
      if (p.brandName.isNotEmpty) p.brandName,
      if (stock != null)
        stock <= 0 ? tr('Out of stock') : '$stock${p.unitName.isEmpty ? '' : ' ${p.unitName.toUpperCase()}'}'
      else if (p.categoryName.isNotEmpty)
        p.categoryName,
    ].join(' · ');

    Widget placeholder() => Container(
      color: DT.slate100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        tr(p.brandName.isNotEmpty ? p.brandName : p.name),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: DT.text(size: 22, weight: FontWeight.w900, color: DT.onyx800, letterSpacing: -1),
      ),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // 🆕 Ithe onTap madhe _openDetail(p) add kela ahe
        onTap: () => _openDetail(p),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kLine),
            boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 2, offset: Offset(0, 1))],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      p.thumbnail.isEmpty
                          ? placeholder()
                          : Image.network(p.thumbnail,
                          fit: BoxFit.contain, // Image purni disnya sathi
                          loadingBuilder: (_, child, prog) => prog == null ? child : Container(color: DT.slate100),
                          errorBuilder: (_, __, ___) => placeholder()),
                      if (p.isFranchiseAvailable)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: GestureDetector(
                            onTap: () => _openFranchise(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kBrand,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🏪', style: TextStyle(fontSize: 9)),
                                  const SizedBox(width: 4),
                                  Text(tr('Franchise'),
                                      style: DT.text(size: 9.5, weight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(trData(p.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 12.5, weight: FontWeight.w800, color: DT.onyx800)),
              const SizedBox(height: 1),
              Text(tr(sub.isEmpty ? ' ' : sub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 10.5, color: stock != null && stock <= 0 ? _kRed : DT.slate400)),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text('₹${p.finalPrice}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 13, weight: FontWeight.w900, color: DT.onyx900)),
                  ),
                  if (showMrp) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('₹${p.price}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 10, color: DT.slate400, decoration: TextDecoration.lineThrough)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openEnquiry(p),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DT.onyx800,
                        side: const BorderSide(color: DT.slate300),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DT.rMd),
                        ),
                      ),
                      child: Text(tr('Enquiry'),
                          style: DT.text(size: 10, weight: FontWeight.w700, color: DT.onyx800)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => CartHelper.addToCart(context: context, product: p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DT.rMd),
                        ),
                      ),
                      child: Text(tr('Add'),
                          style: DT.text(size: 10, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsBar() {
    final total = _filtered.length;
    final filtersOn = _searchQuery.isNotEmpty ||
        _selectedCategory != 'All' ||
        _hasActiveFilters;

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$total ',
                  style: DT.text(size: 13, weight: FontWeight.w800),
                ),
                TextSpan(
                  text: total == 1 ? 'product' : 'products',
                  style: DT.text(
                      size: 13, weight: FontWeight.w500, color: DT.onyx600),
                ),
                if (_sort != _Sort.recommended)
                  TextSpan(
                    text: '  ·  ${_sort.label}',
                    style: DT.text(
                        size: 12, weight: FontWeight.w500, color: DT.slate500),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_franchiseOnly)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _ActivePill(
              label: tr('Franchise'),
              onRemove: () => setState(() {
                _franchiseOnly = false;
                _applyFilters();
              }),
            ),
          ),
        if (filtersOn)
          TextButton(
            onPressed: _clearAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(tr('Clear all'),
                style: DT.text(
                    size: 12, weight: FontWeight.w700, color: _C.blue600)),
          ),
      ],
    );
  }

  Widget _buildListFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Center(
        child: _hasMore
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: _C.navy3),
        )
            : Text(
          _filtered.length > _pageSize
              ? tr('You\'ve seen all {0} products', [_filtered.length])
              : '',
          style: DT.text(size: 11.5, color: DT.slate400),
        ),
      ),
    );
  }

  // ---------- States ----------
  Widget _buildSkeletonGrid() {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // 🆕 Same as new size
        mainAxisExtent: (MediaQuery.of(context).size.width - 44) / 2 + 105,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DT.rLg),
          border: Border.all(color: DT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: DT.slate100,
                  borderRadius: BorderRadius.circular(DT.rMd),
                ),
              ),
            ),
            const SizedBox(height: 10),
            bar(60, 9),
            const SizedBox(height: 6),
            bar(double.infinity, 11),
            const SizedBox(height: 4),
            bar(90, 11),
            const SizedBox(height: 8),
            bar(70, 14),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: bar(double.infinity, 32)),
                const SizedBox(width: 6),
                Expanded(child: bar(double.infinity, 32)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchQuery.isNotEmpty ||
        _selectedCategory != 'All' ||
        _franchiseOnly;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration:
            const BoxDecoration(color: DT.slate100, shape: BoxShape.circle),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              size: 38,
              color: DT.slate400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searching ? tr('No products match') : tr('No products yet'),
            textAlign: TextAlign.center,
            style: DT.text(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            searching
                ? tr('Try another search term, or clear the filters.')
                : tr('Approved products from suppliers will appear here.'),
            textAlign: TextAlign.center,
            style: DT.text(size: 12.5, color: DT.onyx600, height: 1.5),
          ),
          if (searching) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _clearAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBrand,
                side: const BorderSide(color: _kBrand),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DT.rMd),
                ),
              ),
              child: Text(tr('Clear search & filters'),
                  style: DT.text(
                      size: 12.5, weight: FontWeight.w700, color: _kBrand)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      color: _C.navy3,
      onRefresh: _loadProducts,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                          color: _kRedBg, shape: BoxShape.circle),
                      child: const Icon(Icons.cloud_off_rounded,
                          size: 38, color: _kRed),
                    ),
                    const SizedBox(height: 16),
                    Text(tr("Couldn't load products"),
                        style: DT.text(size: 16, weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      tr(_error ?? ''),
                      textAlign: TextAlign.center,
                      style:
                      DT.text(size: 12.5, color: DT.onyx600, height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _loadProducts,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(tr('Try again'),
                          style: DT.text(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand, // buttons: only #093C71
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DT.rMd),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: _kRedBg,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: _kRedLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr("Couldn't refresh. Showing the last loaded products."),
              style: DT.text(size: 12, weight: FontWeight.w500, color: _kRed),
            ),
          ),
          TextButton(
            onPressed: _loadProducts,
            child: Text(tr('Retry'),
                style: DT.text(
                    size: 12, weight: FontWeight.w700, color: _kRed)),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SMALL WIDGETS
// =====================================================================
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _kBrand : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kBrand : DT.slate200),
          boxShadow: DT.shadowXs,
        ),
        child: Text(
          tr(label),
          style: DT.text(
            size: 12,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : DT.onyx700,
          ),
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActivePill({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        decoration: BoxDecoration(
          color: _kTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(label),
                style: DT.text(
                    size: 11, weight: FontWeight.w600, color: _kBrand)),
            const SizedBox(width: 2),
            const Icon(Icons.close_rounded, size: 13, color: _kBrand),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final _Sort sort;
  final bool selected;
  final VoidCallback onTap;

  const _SortOption({
    required this.sort,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _kTint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DT.rMd),
          side: BorderSide(
            color: selected ? _C.blue600 : DT.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DT.rMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(sort.icon,
                    size: 18, color: selected ? _C.blue600 : DT.slate500),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(sort.label),
                    style: DT.text(
                      size: 13,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _kBrand : DT.onyx800,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: _C.blue600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}