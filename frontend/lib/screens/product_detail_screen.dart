// lib/screens/product_detail_screen.dart
//
// Product detail screen (buyer view) – shows EVERYTHING the backend sends:
//   photos (all images + zoom viewer), videos, price / MRP / discount / offer,
//   stock & unit, variants (options with own price, stock, SKU, image),
//   description, specifications, product code / HSN, size & weight,
//   manufacturing / expiry / best-before, category, brand, supplier & branch,
//   franchise.
//
// On open it also refreshes the product from
//   POST product/api/products/detail/  {id}  (or {slug})
// so a card coming from a lighter list still gets the full detail.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../constants/design_tokens.dart';
import '../models/product_model.dart';
import '../services/api_urls.dart';
import '../utils/cart_helper.dart';
import '../utils/shared_preferences_helper.dart';
import 'product_enquiry_screen.dart';
import 'franchise_plans_screen.dart';

// Colours used only on this screen (palette: indigo / violet / orange).
class _PD {
  static const brand = Color(0xFF6366F1);
  static const brandDark = Color(0xFF4338CA);
  static const violet = Color(0xFF8B5CF6);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const greenDark = Color(0xFF047857);
  static const greenBg = Color(0xFFECFDF5);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEEF2FF);
  static const tintLine = Color(0xFFC7D2FE);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

double _num(Object? v) =>
    double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

/// 125000 -> "₹1,25,000" (Indian grouping, paise only when present).
String _inr(Object? raw) {
  final v = _num(raw);
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  var n = parts[0];
  if (n.length > 3) {
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final g = <String>[];
    while (rest.length > 2) {
      g.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) g.insert(0, rest);
    n = '${g.join(',')},$last3';
  }
  return '₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// "2026-01-15" -> "15 Jan 2026"
String _date(String raw) {
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// "fuel_type" -> "Fuel Type"
String _label(String key) => key
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const double _galleryHeight = 360;

  late Product _p = widget.product;
  final _scroll = ScrollController();
  final _pager = PageController();
  bool _refreshing = true;
  bool _collapsed = false;
  bool _descOpen = false;
  int _img = 0;
  int? _variant; // index into _p.variants

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final c = _scroll.hasClients && _scroll.offset > _galleryHeight - kToolbarHeight - 30;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
    _loadFullDetail();
    _loadExtras();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pager.dispose();
    super.dispose();
  }

  // =================================================================
  // DATA
  // =================================================================
  Future<void> _loadFullDetail() async {
    final p = widget.product;
    if (p.id <= 0 && p.slug.isEmpty) {
      setState(() => _refreshing = false);
      return;
    }
    try {
      final res = await http
          .post(
        Uri.parse('${ApiUrls.baseUrl}/product/api/products/detail/'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(p.id > 0 ? {'id': p.id} : {'slug': p.slug}),
      )
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(res.body);
      final data = j is Map ? (j['data'] ?? j['product']) : null;
      if (res.statusCode == 200 && data is Map) {
        final full = Product.fromJson(Map<String, dynamic>.from(data));
        if (!mounted) return;
        setState(() {
          _p = full;
          _refreshing = false;
          if (_variant != null && _variant! >= _p.variants.length) _variant = null;
          if (_img >= _gallery.length) _img = 0;
        });
        return;
      }
    } catch (_) {
      // keep the data we already have from the list
    }
    if (mounted) setState(() => _refreshing = false);
  }

  // ---------------------------------------------------------------- extras
  //   POST product/related_products/        {product_id}  -> {products:[{id,name,slug,price,thumbnail}]}
  //   POST product/product/track-view/      {product_id}  (login)
  //   POST product/product/recently-viewed/ {}            (login) -> {data:[product]}
  List<Product> _related = [];
  List<Product> _recent = [];

  Future<void> _loadExtras() async {
    final id = widget.product.id;
    if (id <= 0) return;
    final token = await SharedPreferencesHelper.getAccessToken();
    final auth = token != null && token.isNotEmpty;
    Future<dynamic> post(String path, Map<String, dynamic> body, {bool withAuth = false}) async {
      try {
        final res = await http
            .post(
          Uri.parse('${ApiUrls.baseUrl}$path'),
          headers: {
            'Content-Type': 'application/json',
            if (withAuth && auth) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
            .timeout(const Duration(seconds: 20));
        return res.statusCode == 200 ? jsonDecode(res.body) : null;
      } catch (_) {
        return null;
      }
    }

    if (auth) {
      // Record this view first so it shows up in "recently viewed" next time.
      await post('/product/product/track-view/', {'product_id': id}, withAuth: true);
    }
    final results = await Future.wait([
      post('/product/related_products/', {'product_id': id}),
      if (auth) post('/product/product/recently-viewed/', {}, withAuth: true),
    ]);
    if (!mounted) return;

    List<Product> parse(dynamic j, String key) {
      if (j is! Map || j[key] is! List) return const [];
      return [
        for (final e in (j[key] as List).whereType<Map>())
          Product.fromJson({
            ...Map<String, dynamic>.from(e),
            if (e['final_price'] == null && e['price'] != null) 'final_price': e['price'],
          })
      ].where((p) => p.id > 0 && p.id != id).toList();
    }

    setState(() {
      _related = parse(results[0], 'products');
      if (results.length > 1) _recent = parse(results[1], 'data');
    });
  }

  void _openProduct(Product p) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
  );

  Widget _productStrip(List<Product> items) => SizedBox(
    height: 214,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final p = items[i];
        return SizedBox(
          width: 148,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openProduct(p),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _PD.line),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: p.thumbnail.isEmpty
                            ? Container(color: _PD.tint, child: const Icon(Icons.image_outlined, color: _PD.hint))
                            : Image.network(p.thumbnail,
                            fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _PD.tint)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 12.5, weight: FontWeight.w700, color: _PD.ink, height: 1.25)),
                    const Spacer(),
                    Text(_inr(p.finalPrice), style: DT.text(size: 14, weight: FontWeight.w900, color: _PD.brandDark)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  List<String> get _gallery => _p.gallery;

  ProductVariantInfo? get _selVariant =>
      _variant == null || _variant! >= _p.variants.length ? null : _p.variants[_variant!];

  String get _shownFinal => _selVariant?.finalPrice ?? _p.finalPrice;
  String get _shownMrp => _selVariant?.price ?? _p.price;
  int? get _shownStock => _selVariant?.stockQuantity ?? _p.stockQuantity;

  bool get _hasOldPrice => _num(_shownMrp) > _num(_shownFinal) && _num(_shownFinal) > 0;
  bool get _outOfStock => _shownStock != null && _shownStock! <= 0;

  String? get _discountBadge {
    final v = _num(_p.discountValue);
    if (v > 0) {
      return _p.discountType == 'flat' ? '${_inr(v)} OFF' : '${v % 1 == 0 ? v.toInt() : v}% OFF';
    }
    if (_hasOldPrice) {
      final pct = ((_num(_shownMrp) - _num(_shownFinal)) / _num(_shownMrp) * 100).round();
      if (pct > 0) return '$pct% OFF';
    }
    return null;
  }

  String? get _offerTitle {
    final o = _p.appliedOffer;
    if (o is Map) {
      final t = '${o['title'] ?? ''}'.trim();
      return t.isEmpty ? 'Special offer applied' : t;
    }
    return null;
  }

  // =================================================================
  // ACTIONS
  // =================================================================
  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: _PD.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    _toast('$what copied');
  }

  void _share() {
    final lines = [
      _p.name,
      '${_inr(_shownFinal)}${_hasOldPrice ? '  (MRP ${_inr(_shownMrp)})' : ''}',
      if (_p.brandName.isNotEmpty) 'Brand: ${_p.brandName}',
      if (_p.companyName.isNotEmpty) 'Sold by: ${_p.companyName}',
      'QNX Mart',
    ];
    _copy(lines.join('\n'), 'Product details');
  }

  void _openViewer(int index) {
    if (_gallery.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _PhotoViewer(urls: _gallery, initialIndex: index),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _goTo(int i) {
    if (_pager.hasClients && i >= 0 && i < _gallery.length) {
      _pager.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _selectVariant(int i) {
    setState(() => _variant = _variant == i ? null : i);
    final v = _selVariant;
    if (v == null) return;
    final idx = v.image.isNotEmpty ? _gallery.indexOf(v.image) : -1;
    if (idx >= 0) {
      _goTo(idx);
    } else if (v.imageIndex >= 0 && v.imageIndex < _p.images.length) {
      _goTo(_gallery.indexOf(_p.images[v.imageIndex]));
    }
  }

  void _openVideo(int i) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _VideoPage(urls: _p.videos, initialIndex: i, title: _p.name)),
    );
  }

  void _openFranchise() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => FranchisePlansScreen(productSlug: _p.slug, productName: _p.name)),
  );

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    final details = _detailRows();
    final dims = _dimensionTiles();
    return Scaffold(
      backgroundColor: _PD.bg,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _sliverGallery(),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                decoration: const BoxDecoration(
                  color: _PD.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_refreshing) ...[
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        child: LinearProgressIndicator(
                            minHeight: 3, color: _PD.brand, backgroundColor: _PD.tint),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _headline(),
                    const SizedBox(height: 14),
                    _priceCard(),
                    const SizedBox(height: 12),
                    _quickFacts(),
                    if (_gallery.length > 1) ...[
                      const SizedBox(height: 14),
                      _thumbs(),
                    ],
                    if (_p.variants.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Available options', Icons.style_outlined,
                          trailing: '${_p.variants.length} variant${_p.variants.length == 1 ? '' : 's'}'),
                      const SizedBox(height: 10),
                      _variantsCard(),
                    ],
                    if (_p.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Description', Icons.notes_rounded),
                      const SizedBox(height: 10),
                      _descriptionCard(),
                    ],
                    if (_p.specifications.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Specifications', Icons.tune_rounded),
                      const SizedBox(height: 10),
                      _table(_p.specifications.entries.map((e) => (_label(e.key), e.value)).toList()),
                    ],
                    if (dims.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Size & weight', Icons.straighten_rounded),
                      const SizedBox(height: 10),
                      _dimensions(dims),
                    ],
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Product details', Icons.info_outline_rounded),
                      const SizedBox(height: 10),
                      _table(details),
                    ],
                    if (_p.videos.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Product videos', Icons.play_circle_outline_rounded),
                      const SizedBox(height: 10),
                      _videosCard(),
                    ],
                    const SizedBox(height: 22),
                    _title('Sold by', Icons.storefront_outlined),
                    const SizedBox(height: 10),
                    _supplierCard(),
                    if (_p.isFranchiseAvailable) ...[
                      const SizedBox(height: 14),
                      _franchiseCard(),
                    ],
                    if (_related.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Similar products', Icons.auto_awesome_outlined),
                      const SizedBox(height: 10),
                      _productStrip(_related),
                    ],
                    if (_recent.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Recently viewed', Icons.history_rounded),
                      const SizedBox(height: 10),
                      _productStrip(_recent),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  // ---------------------------------------------------------------- gallery
  Widget _sliverGallery() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: _galleryHeight,
      backgroundColor: _collapsed ? _PD.brand : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          FlexibleSpaceBar(collapseMode: CollapseMode.parallax, background: _galleryView()),
          IgnorePointer(
            ignoring: !_collapsed,
            child: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: const DecoratedBox(decoration: BoxDecoration(gradient: DT.headerGradient)),
            ),
          ),
        ],
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _roundBtn(Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
      ),
      title: AnimatedOpacity(
        opacity: _collapsed ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Text(_p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: 16, weight: FontWeight.w700, color: Colors.white)),
      ),
      actions: [
        _roundBtn(Icons.ios_share_rounded, _share),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => Center(
    child: Material(
      color: _collapsed ? const Color(0x26FFFFFF) : Colors.white,
      shape: const CircleBorder(),
      elevation: _collapsed ? 0 : 2,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
            width: 40, height: 40, child: Icon(icon, size: 20, color: _collapsed ? Colors.white : _PD.ink)),
      ),
    ),
  );

  Widget _galleryView() {
    final g = _gallery;
    if (g.isEmpty) {
      return Container(
        color: Colors.white,
        child: const Center(child: Icon(Icons.image_outlined, size: 72, color: _PD.hint)),
      );
    }
    return Container(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pager,
            itemCount: g.length,
            onPageChanged: (i) => setState(() => _img = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _openViewer(i),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 48),
                child: Image.network(
                  g[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (c, child, p) => p == null
                      ? child
                      : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _PD.brand)),
                  errorBuilder: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: _PD.hint)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 36,
            child: Row(
              children: [
                if (_discountBadge != null) _pill(Icons.local_offer_rounded, _discountBadge!, _PD.orange, Colors.white),
                if (_discountBadge != null && _p.isFeatured) const SizedBox(width: 6),
                if (_p.isFeatured) _pill(Icons.star_rounded, 'Featured', _PD.amber, Colors.white),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 36,
            child: Row(
              children: [
                if (_p.videos.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _openVideo(0),
                    child: _pill(Icons.play_circle_fill_rounded,
                        _p.videos.length == 1 ? 'Video' : '${_p.videos.length} videos', _PD.brand, Colors.white),
                  ),
                  const SizedBox(width: 6),
                ],
                GestureDetector(
                  onTap: () => _openViewer(_img),
                  child: _pill(Icons.photo_library_outlined, '${_img + 1}/${g.length}', const Color(0xB30F172A),
                      Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 4),
        Text(text, style: DT.text(size: 11, weight: FontWeight.w800, color: fg)),
      ],
    ),
  );

  Widget _thumbs() => SizedBox(
    height: 62,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _gallery.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final sel = i == _img;
        return GestureDetector(
          onTap: () => _goTo(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 62,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? _PD.brand : _PD.line, width: sel ? 2 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(_gallery[i],
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _PD.line)),
            ),
          ),
        );
      },
    ),
  );

  // ---------------------------------------------------------------- headline / price
  Widget _headline() {
    final crumbs = [_p.categoryName, _p.subcategoryName].where((s) => s.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumbs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _PD.tint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _PD.tintLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.category_outlined, size: 12, color: _PD.brand),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(crumbs.join(' › '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 11, weight: FontWeight.w700, color: _PD.brandDark)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(_p.name,
            style: DT.text(size: 20, weight: FontWeight.w800, color: _PD.ink, height: 1.3, letterSpacing: -0.3)),
        if (_p.brandName.isNotEmpty || _p.productCode.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_p.brandName.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_outlined, size: 14, color: _PD.brand),
                    const SizedBox(width: 4),
                    Text('by ${_p.brandName}', style: DT.text(size: 12.5, weight: FontWeight.w700, color: _PD.brandDark)),
                  ],
                ),
              if (_p.productCode.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _copy(_p.productCode, 'Product code'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Code: ${_p.productCode}', style: DT.text(size: 12, color: _PD.muted)),
                      const SizedBox(width: 3),
                      const Icon(Icons.copy_rounded, size: 12, color: _PD.hint),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _priceCard() {
    final badge = _discountBadge;
    final offer = _offerTitle;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), _PD.brandDark, _PD.violet],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x406366F1), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_selVariant == null ? 'PRICE' : 'PRICE · ${_selVariant!.label.toUpperCase()}',
                  style: DT.text(size: 10, weight: FontWeight.w700, color: const Color(0xB3FFFFFF), letterSpacing: 1.1)),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _PD.orange, borderRadius: BorderRadius.circular(20)),
                  child: Text(badge, style: DT.text(size: 10.5, weight: FontWeight.w800, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(_inr(_shownFinal),
                  style: DT.text(size: 28, weight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              if (_hasOldPrice)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('MRP ${_inr(_shownMrp)}',
                      style: DT.text(
                          size: 13,
                          weight: FontWeight.w600,
                          color: const Color(0xB3FFFFFF),
                          decoration: TextDecoration.lineThrough)),
                ),
            ],
          ),
          if (_hasOldPrice)
            Text('You save ${_inr(_num(_shownMrp) - _num(_shownFinal))}',
                style: DT.text(size: 12, weight: FontWeight.w700, color: const Color(0xFF6EE7B7))),
          const SizedBox(height: 2),
          Text(
              'Inclusive of all taxes${_p.unitName.isNotEmpty ? ' · per ${_p.unitName}' : ''}',
              style: DT.text(size: 11, color: const Color(0xB3FFFFFF))),
          if (offer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration_rounded, size: 16, color: Color(0xFFFCD34D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(offer,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 12, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickFacts() {
    final stock = _shownStock;
    final tiles = <(IconData, String, String, Color)>[
      (
      _outOfStock ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined,
      'Stock',
      stock == null ? '—' : (_outOfStock ? 'Out of stock' : '$stock available'),
      _outOfStock ? _PD.red : _PD.green,
      ),
      (Icons.straighten_rounded, 'Unit', _p.unitName.isEmpty ? '—' : _p.unitName, _PD.brand),
      (Icons.sell_outlined, 'Brand', _p.brandName.isEmpty ? '—' : _p.brandName, _PD.violet),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _PD.line),
              ),
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tiles[i].$4.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(tiles[i].$1, size: 18, color: tiles[i].$4),
                  ),
                  const SizedBox(height: 6),
                  Text(tiles[i].$2, style: DT.text(size: 10.5, weight: FontWeight.w600, color: _PD.muted)),
                  const SizedBox(height: 1),
                  Text(tiles[i].$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DT.text(
                          size: 12.5, weight: FontWeight.w800, color: i == 0 ? tiles[i].$4 : _PD.ink)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- sections
  Widget _title(String text, IconData icon, {String? trailing}) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: _PD.tint, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _PD.brand),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: DT.text(size: 16, weight: FontWeight.w800, color: _PD.ink, letterSpacing: -0.2)),
      ),
      if (trailing != null) Text(trailing, style: DT.text(size: 11.5, weight: FontWeight.w600, color: _PD.muted)),
    ],
  );

  BoxDecoration get _card => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _PD.line),
    boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
  );

  Widget _variantsCard() {
    final v = _selVariant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _p.variants.length; i++) _variantChip(i),
            ],
          ),
          if (v != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _PD.tint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _PD.tintLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in v.attributes.entries)
                    if (e.value.isNotEmpty) _miniRow(_label(e.key), e.value),
                  if (v.sku.isNotEmpty) _miniRow('SKU', v.sku),
                  _miniRow('Price', _inr(v.finalPrice)),
                  _miniRow('Stock', v.stockQuantity > 0 ? '${v.stockQuantity} available' : 'Out of stock',
                      color: v.stockQuantity > 0 ? _PD.greenDark : _PD.red),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('Tap an option to see its price, stock and photo.',
                style: DT.text(size: 11.5, color: _PD.muted)),
          ],
        ],
      ),
    );
  }

  Widget _variantChip(int i) {
    final v = _p.variants[i];
    final sel = _variant == i;
    final out = v.stockQuantity <= 0;
    return GestureDetector(
      onTap: () => _selectVariant(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: sel ? _PD.tint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _PD.brand : _PD.line, width: sel ? 1.6 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (v.image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(v.image,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 34, height: 34, color: _PD.line)),
              ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(v.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(
                          size: 12.5,
                          weight: FontWeight.w700,
                          color: out ? _PD.hint : (sel ? _PD.brandDark : _PD.ink),
                          decoration: out ? TextDecoration.lineThrough : null)),
                ),
                Text(out ? 'Out of stock' : _inr(v.finalPrice),
                    style: DT.text(size: 11, weight: FontWeight.w600, color: out ? _PD.red : _PD.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniRow(String k, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: Text(k, style: DT.text(size: 12, color: _PD.muted))),
        Expanded(
          flex: 6,
          child: Text(v,
              textAlign: TextAlign.right,
              style: DT.text(size: 12.5, weight: FontWeight.w700, color: color ?? _PD.ink)),
        ),
      ],
    ),
  );

  Widget _descriptionCard() {
    final text = _p.description.trim();
    final long = text.length > 260;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Text(
              text,
              maxLines: long && !_descOpen ? 6 : null,
              overflow: long && !_descOpen ? TextOverflow.ellipsis : TextOverflow.visible,
              style: DT.text(size: 13.5, color: _PD.body, height: 1.6),
            ),
          ),
          if (long)
            GestureDetector(
              onTap: () => setState(() => _descOpen = !_descOpen),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_descOpen ? 'Show less' : 'Read more',
                        style: DT.text(size: 12.5, weight: FontWeight.w800, color: _PD.brand)),
                    Icon(_descOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18, color: _PD.brand),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Zebra table of (label, value) rows.
  Widget _table(List<(String, String)> rows) {
    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              color: i.isEven ? Colors.white : _PD.bg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(rows[i].$1, style: DT.text(size: 12.5, weight: FontWeight.w500, color: _PD.muted)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: Text(rows[i].$2,
                        textAlign: TextAlign.right,
                        style: DT.text(size: 13, weight: FontWeight.w700, color: _PD.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<(String, String)> _detailRows() => [
    if (_p.productCode.isNotEmpty) ('Product code', _p.productCode),
    if (_p.hsnCode.isNotEmpty) ('HSN code', _p.hsnCode),
    if (_p.categoryName.isNotEmpty) ('Category', _p.categoryName),
    if (_p.subcategoryName.isNotEmpty) ('Subcategory', _p.subcategoryName),
    if (_p.brandName.isNotEmpty) ('Brand', _p.brandName),
    if (_p.unitName.isNotEmpty) ('Unit', _p.unitName),
    if (_p.manufacturingDate.isNotEmpty) ('Manufactured on', _date(_p.manufacturingDate)),
    if (_p.expiryDate.isNotEmpty) ('Expiry date', _date(_p.expiryDate)),
    if (_p.bestBeforeDuration.isNotEmpty) ('Best before', _p.bestBeforeDuration),
    if (_p.createdAt.isNotEmpty) ('Listed on', _date(_p.createdAt)),
  ];

  List<(IconData, String, String)> _dimensionTiles() => [
    if (_p.length.isNotEmpty && _num(_p.length) > 0) (Icons.swap_horiz_rounded, 'Length', _p.length),
    if (_p.width.isNotEmpty && _num(_p.width) > 0) (Icons.width_normal_outlined, 'Width', _p.width),
    if (_p.height.isNotEmpty && _num(_p.height) > 0) (Icons.height_rounded, 'Height', _p.height),
    if (_p.weight.isNotEmpty && _num(_p.weight) > 0) (Icons.scale_outlined, 'Weight', _p.weight),
  ];

  Widget _dimensions(List<(IconData, String, String)> tiles) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final cols = tiles.length >= 4 && c.maxWidth >= 360 ? 4 : 2;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in tiles)
            Container(
              width: w,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: _card,
              child: Column(
                children: [
                  Icon(t.$1, size: 20, color: _PD.brand),
                  const SizedBox(height: 6),
                  Text(t.$2, style: DT.text(size: 10.5, weight: FontWeight.w600, color: _PD.muted)),
                  const SizedBox(height: 2),
                  Text(t.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 13, weight: FontWeight.w800, color: _PD.ink)),
                ],
              ),
            ),
        ],
      );
    });
  }

  Widget _videosCard() {
    return Column(
      children: [
        for (var i = 0; i < _p.videos.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openVideo(i),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _PD.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF312E81), _PD.violet],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Product video ${i + 1}',
                              style: DT.text(size: 13.5, weight: FontWeight.w700, color: _PD.ink)),
                          Text('Tap to play', style: DT.text(size: 11.5, color: _PD.muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _PD.hint),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _supplierCard() {
    final name = _p.companyName.trim().isEmpty ? 'Supplier' : _p.companyName.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_PD.brand, _PD.violet]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(name[0].toUpperCase(),
                  style: DT.text(size: 21, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 14.5, weight: FontWeight.w800, color: _PD.ink)),
                if (_p.branchName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: _PD.muted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text('Branch: ${_p.branchName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 12, color: _PD.muted)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _PD.greenBg, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: _PD.greenDark),
                      const SizedBox(width: 3),
                      Text('Verified supplier',
                          style: DT.text(size: 10.5, weight: FontWeight.w700, color: _PD.greenDark)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _franchiseCard() {
    return Material(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openFranchise,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: _PD.orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Franchise available',
                        style: DT.text(size: 14, weight: FontWeight.w800, color: const Color(0xFF7C2D12))),
                    const SizedBox(height: 2),
                    Text('Start your own business with this product',
                        style: DT.text(size: 11.5, color: const Color(0xFF9A3412))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: _PD.orange),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bottom bar
  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x1A0F172A), blurRadius: 20, offset: Offset(0, -6))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductEnquiryScreen(product: _p)),
                  ),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: Text('Enquiry',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 14, weight: FontWeight.w800, color: _PD.brandDark)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _PD.brandDark,
                    backgroundColor: _PD.tint,
                    side: const BorderSide(color: _PD.tintLine, width: 1.4),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _outOfStock ? null : DT.ctaGradient,
                    color: _outOfStock ? _PD.line : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _outOfStock ? null : () => CartHelper.addToCart(context: context, product: _p),
                    icon: Icon(_outOfStock ? Icons.block_rounded : Icons.shopping_cart_outlined,
                        size: 18, color: _outOfStock ? _PD.muted : Colors.white),
                    label: Text(_outOfStock ? 'Out of stock' : 'Add to cart',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(
                            size: 14.5, weight: FontWeight.w800, color: _outOfStock ? _PD.muted : Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
}

// =====================================================================
// FULL-SCREEN PHOTO VIEWER (pinch to zoom)
// =====================================================================
class _PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _PhotoViewer({required this.urls, required this.initialIndex});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  late int _i = widget.initialIndex;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(widget.urls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined, size: 56, color: Colors.white38)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
                    child: Text('${_i + 1} / ${widget.urls.length}',
                        style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// PRODUCT VIDEO PLAYER (video_player, "Open in browser" fallback)
// =====================================================================
class _VideoPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String title;
  const _VideoPage({required this.urls, required this.initialIndex, required this.title});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _c;
  late int _i = widget.initialIndex;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load(_i);
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  Future<void> _load(int i) async {
    final old = _c;
    old?.removeListener(_tick);
    setState(() {
      _i = i;
      _c = null;
      _loading = true;
      _failed = false;
    });
    await old?.dispose();
    final uri = Uri.tryParse(widget.urls[i]);
    if (uri == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    final c = VideoPlayerController.networkUrl(uri);
    try {
      await c.initialize().timeout(const Duration(seconds: 40));
      if (!mounted || _i != i) {
        await c.dispose();
        return;
      }
      c.addListener(_tick);
      await c.play();
      setState(() {
        _c = c;
        _loading = false;
      });
    } catch (_) {
      await c.dispose();
      if (!mounted || _i != i) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _external() async {
    final uri = Uri.tryParse(widget.urls[_i]);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: DT.headerGradient)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: 15.5, weight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(tooltip: 'Open in browser', onPressed: _external, icon: const Icon(Icons.open_in_new_rounded)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator(color: _PD.brand)
                  : _failed || c == null
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 44),
                  const SizedBox(height: 10),
                  Text('This video could not be played here.',
                      style: DT.text(size: 13.5, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _external,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open in browser'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _PD.brand, foregroundColor: Colors.white, elevation: 0),
                  ),
                ],
              )
                  : GestureDetector(
                onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
                      child: VideoPlayer(c),
                    ),
                    if (!c.value.isPlaying)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [_PD.brand, _PD.violet]),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (c != null && !_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: _PD.orange,
                  bufferedColor: Color(0x55FFFFFF),
                  backgroundColor: Color(0x22FFFFFF),
                ),
              ),
            ),
          if (widget.urls.length > 1)
            SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  itemCount: widget.urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text('Video ${i + 1}'),
                    selected: i == _i,
                    onSelected: (_) => i == _i ? null : _load(i),
                    selectedColor: _PD.brand,
                    backgroundColor: const Color(0xFF1E1B4B),
                    labelStyle: DT.text(size: 12, weight: FontWeight.w700, color: Colors.white),
                    showCheckmark: false,
                    side: BorderSide.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
