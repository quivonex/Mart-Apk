import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cart_model.dart';
import '../services/cart_service.dart';
import '../utils/shared_preferences_helper.dart';
import 'checkout_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';

/// Design tokens – QNX MART logo colours: brand #093C71 (all buttons),
/// red = errors, amber/orange = accents & conditions.
class _C {
  static const surface = Color(0xFFF8FAFC);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate900 = Color(0xFF0F172A);
  static const blue50 = Color(0xFFEAF1F9);
  static const blue200 = Color(0xFFC9DBEE);
  static const blue600 = Color(0xFF093C71); // brand
  static const blue700 = Color(0xFF093C71); // brand
  static const blue900 = Color(0xFF062A50);
  static const indigo950 = Color(0xFF1E1B4B);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald600 = Color(0xFF10B981);
  static const emerald700 = Color(0xFF047857);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber200 = Color(0xFFFDE68A);
  static const amber300 = Color(0xFFFCD34D);
  static const amber700 = Color(0xFFB45309); // CTA + accent
  static const amber800 = Color(0xFF92400E);
  static const amber900 = Color(0xFF78350F);
  static const red = Color(0xFFC62828); // logo red – errors
  static const redBg = Color(0xFFFEF2F2);
}

TextStyle _t(double size, FontWeight w, Color c,
    {double? height, double? ls}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: ls);

/// 1359 -> "1,359" ; 1500000 -> "15,00,000" (Indian grouping)
String _inr(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final sign = n < 0 ? '-' : '';
  if (s.length <= 3) return '$sign$s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+$)'),
        (m) => '${m[1]},',
  );
  return '$sign$rest,$last3';
}

/// Turns a raw backend error from shipping-rates into a message a buyer can
/// understand. Example: "could not convert string to float: '1000 kg'" comes
/// from the backend reading a product weight saved as "1000 kg" as a number.
String? _friendlyShipNote(String? raw) {
  if (raw == null || raw.trim().isEmpty) return raw;
  final m = raw.toLowerCase();
  if (m.contains('could not convert') ||
      m.contains('float') ||
      m.contains('invalid literal') ||
      m.contains('weight')) {
    return tr('Shipping could not be calculated for one of the selected products (its weight / size is not set up correctly). The seller has been asked to fix it – shipping will be confirmed at checkout.');
  }
  if (m.contains('traceback') || m.contains('exception') || m.length > 160) {
    return tr('Shipping will be calculated at checkout.');
  }
  return raw;
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItemModel> _cartItems = [];
  bool _isLoading = true;
  bool _isBusy = false; // clear-all in progress
  String? _error;
  int? _userId;

  /// Cart item ids ticked for checkout. New items are ticked by default.
  final Set<int> _selected = {};
  final Set<int> _knownIds = {};

  /// Cart item ids whose quantity is being saved.
  final Set<int> _updating = {};

  // ---- Live shipping estimate ----
  String _shipKey = ''; // ticked product ids the estimate belongs to
  bool _shipLoading = false;
  double? _shipEstimate; // null = calculated at checkout
  String? _shipPincode;
  String? _shipNote;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // STEP 1: user id
      _userId = await SharedPreferencesHelper.getUserId();

      if (_userId == null) {
        if (!mounted) return;
        setState(() {
          _error = tr('User not logged in. Please login first.');
          _isLoading = false;
        });
        return;
      }

      // STEP 2: access token
      final token = await SharedPreferencesHelper.getAccessToken();

      if (token == null) {
        if (!mounted) return;
        setState(() {
          _error = tr('Session expired. Please login again.');
          _isLoading = false;
        });
        return;
      }

      // STEP 3: API call
      final response = await CartService.getCartList(
        GetCartListRequest(userId: _userId!),
      );

      if (!mounted) return;
      setState(() {
        if (response.status) {
          _cartItems = response.cartItems;
          final ids = _cartItems.map((e) => e.id).toSet();
          _selected.removeWhere((id) => !ids.contains(id));
          for (final id in ids) {
            if (_knownIds.add(id)) _selected.add(id); // first time seen -> ticked
          }
          _knownIds.removeWhere((id) => !ids.contains(id));
        } else {
          _error = tr('Failed to load cart items');
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<CartItemModel> get _selectedItems =>
      _cartItems.where((i) => _selected.contains(i.id)).toList();

  bool get _allSelected =>
      _cartItems.isNotEmpty && _selected.length == _cartItems.length;

  int get _selectedUnits => _selectedItems.fold(0, (s, i) => s + i.quantity);

  /// Totals are for the ticked items only.
  double get _subtotal =>
      _selectedItems.fold(0, (sum, item) => sum + item.lineTotal);

  /// Tax is calculated as 12% of Subtotal
  double get _tax => _subtotal * 0.12;

  /// 🆕 Shipping relies completely on API (no more static ₹500)
  double get _shipping => _selectedItems.isEmpty ? 0.0 : (_shipEstimate ?? 0.0);

  /// Total now includes Tax + Shipping
  double get _total => _subtotal + _tax + _shipping;

  /// Re-prices shipping whenever the set of ticked products changes.
  void _syncShipping() {
    final ids = _selectedItems.map((i) => i.productId).where((id) => id > 0).toSet().toList()..sort();
    final key = ids.join(',');
    if (key == _shipKey) return;
    _shipKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchShipping(key, ids));
  }

  Future<void> _fetchShipping(String key, List<int> ids) async {
    if (!mounted) return;
    if (ids.isEmpty) {
      setState(() {
        _shipLoading = false;
        _shipEstimate = null;
        _shipNote = null;
      });
      return;
    }
    setState(() => _shipLoading = true);
    final r = await CartService.shippingEstimate(ids);
    if (!mounted || key != _shipKey) return; // selection changed meanwhile
    setState(() {
      _shipLoading = false;
      _shipEstimate = r.amount;
      _shipPincode = r.pincode;
      _shipNote = _friendlyShipNote(r.note); // no raw backend errors in the UI
    });
  }

  String get _shippingText {
    if (_selectedItems.isEmpty) return '₹0';
    if (_shipLoading) return tr('Calculating…');
    if (_shipEstimate != null) return '₹${_inr(_shipEstimate!)}';
    return tr('At checkout'); // 🆕 Dynamic: If API doesn't provide an estimate
  }

  void _toggleSelect(CartItemModel item) => setState(() {
    if (!_selected.remove(item.id)) _selected.add(item.id);
  });

  void _toggleSelectAll() => setState(() {
    if (_allSelected) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(_cartItems.map((e) => e.id));
    }
  });

  /// +1 / -1 using the add-to-cart API (the backend has no update API).
  /// At quantity 1, "-" asks to remove the item instead.
  Future<void> _changeQuantity(CartItemModel item, int delta) async {
    if (_updating.contains(item.id)) return;
    if (delta < 0 && item.quantity <= 1) {
      await _confirmRemove(item);
      return;
    }

    final index = _cartItems.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    final before = _cartItems[index];

    // Optimistic update
    setState(() {
      _updating.add(item.id);
      _cartItems[index] = before.copyWith(quantity: before.quantity + delta);
    });

    try {
      await CartService.changeQuantity(productId: item.productId, delta: delta);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _cartItems.indexWhere((x) => x.id == item.id);
        if (i != -1) _cartItems[i] = before;
      });
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _updating.remove(item.id));
    }
  }

  Future<void> _confirmRemove(CartItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tr('Remove item?'), style: _t(17, FontWeight.w800, _C.slate900)),
        content: Text(
          tr('{0} will be removed from your cart.', [item.productName]),
          style: _t(13, FontWeight.w500, _C.slate500, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel'), style: _t(13, FontWeight.w700, _C.slate600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Remove'), style: _t(13, FontWeight.w800, _C.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _removeItem(item.id);
  }

  Future<void> _removeItem(int cartId) async {
    // Optimistic update
    final previousItems = List<CartItemModel>.from(_cartItems);
    final wasSelected = _selected.contains(cartId);
    setState(() {
      _cartItems.removeWhere((item) => item.id == cartId);
      _selected.remove(cartId);
      _knownIds.remove(cartId);
    });

    try {
      final response = await CartService.removeFromCart(
        RemoveFromCartRequest(cartItemId: cartId),
      );

      if (response.status) {
        _showSnackBar(response.message);
      } else {
        if (!mounted) return;
        setState(() {
          _cartItems = previousItems;
          _knownIds.add(cartId);
          if (wasSelected) _selected.add(cartId);
        });
        _showSnackBar(response.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cartItems = previousItems;
        _knownIds.add(cartId);
        if (wasSelected) _selected.add(cartId);
      });
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  /// Removes every item (uses the existing remove API, one by one).
  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tr('Clear entire cart?'),
            style: _t(17, FontWeight.w800, _C.slate900)),
        content: Text(
          tr('All {0} items will be removed from your cart.', [_cartItems.length]),
          style: _t(13, FontWeight.w500, _C.slate500, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel'), style: _t(13, FontWeight.w700, _C.slate600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Clear All'), style: _t(13, FontWeight.w800, _C.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final items = List<CartItemModel>.from(_cartItems);
    setState(() => _isBusy = true);

    var failed = 0;
    for (final item in items) {
      try {
        final r = await CartService.removeFromCart(
          RemoveFromCartRequest(cartItemId: item.id),
        );
        if (!r.status) failed++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (failed > 0) {
      _showSnackBar(tr('{0} item(s) could not be removed', [failed]), isError: true);
      await _loadCartItems();
    } else {
      setState(() {
        _cartItems = [];
        _selected.clear();
        _knownIds.clear();
      });
      _showSnackBar(tr('Cart cleared'));
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(message), style: _t(13, FontWeight.w600, Colors.white)),
        backgroundColor: isError ? _C.red : _C.slate900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.surface,
      child: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_C.blue700),
        ),
      )
          : _error != null
          ? _buildErrorWidget()
          : _cartItems.isEmpty
          ? _buildEmptyCart()
          : _buildCartContent(),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty + error
  // ---------------------------------------------------------------------------

  Widget _buildEmptyCart() {
    return RefreshIndicator(
      onRefresh: _loadCartItems,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: _C.blue50,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.blue200),
                      ),
                      child: const Icon(Icons.shopping_cart_outlined,
                          size: 46, color: _C.blue600),
                    ),
                    const SizedBox(height: 22),
                    Text(tr('Your cart is empty'),
                        style: _t(20, FontWeight.w800, _C.slate900, ls: -0.3)),
                    const SizedBox(height: 8),
                    Text(
                      tr('Start adding products from the catalog'),
                      textAlign: TextAlign.center,
                      style: _t(13, FontWeight.w500, _C.slate500),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadCartItems,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.blue600, // buttons: only #093C71
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(tr('Refresh Cart'),
                          style: _t(14, FontWeight.w700, Colors.white)),
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

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: _C.redBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 44, color: _C.red),
            ),
            const SizedBox(height: 20),
            Text(tr('Failed to load cart'),
                style: _t(18, FontWeight.w800, _C.slate900)),
            const SizedBox(height: 8),
            Text(
              tr(_error!),
              textAlign: TextAlign.center,
              style: _t(13, FontWeight.w500, _C.slate500, height: 1.45),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _loadCartItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.blue600, // buttons: only #093C71
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(tr('Retry'), style: _t(14, FontWeight.w700, Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cart content
  // ---------------------------------------------------------------------------

  Widget _buildCartContent() {
    return Column(
      children: [
        if (_isBusy)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: _C.slate100,
            valueColor: AlwaysStoppedAnimation<Color>(_C.blue600),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCartItems,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                _buildTitleRow(),
                const SizedBox(height: 12),
                _buildSelectAllBar(),
                const SizedBox(height: 12),
                _buildGstBanner(),
                const SizedBox(height: 14),
                ..._cartItems.map(
                      (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCartItem(item),
                  ),
                ),
                const SizedBox(height: 2),
                _buildTrustBadges(),
              ],
            ),
          ),
        ),
        _buildSummarySheet(),
      ],
    );
  }

  Widget _buildTitleRow() {
    final count = _cartItems.length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Active B2B Cart'),
                  style: _t(18, FontWeight.w800, _C.slate900, ls: -0.4)),
              const SizedBox(height: 2),
              Text(
                tr('{0} {1} • Factory Direct Verification', [count, count == 1 ? 'Item' : 'Items']),
                style: _t(12, FontWeight.w500, _C.slate500),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _isBusy ? null : _clearAll,
          style: TextButton.styleFrom(
            foregroundColor: _C.blue600,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(tr('Clear All'), style: _t(12, FontWeight.w700, _C.blue600)),
        ),
      ],
    );
  }

  Widget _buildSelectAllBar() {
    final n = _selected.length;
    final total = _cartItems.length;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _toggleSelectAll,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: n > 0 ? _C.blue200 : _C.slate200),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _allSelected ? true : (n == 0 ? false : null),
                tristate: true,
                onChanged: (_) => _toggleSelectAll(),
                activeColor: _C.blue600,
                side: const BorderSide(color: _C.slate300, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  _allSelected ? tr('All items selected') : tr('Select all'),
                  style: _t(13, FontWeight.w700, _C.slate900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: n > 0 ? _C.blue50 : _C.slate100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$n / $total selected',
                    style: _t(11, FontWeight.w800, n > 0 ? _C.blue700 : _C.slate500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGstBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF062A50), Color(0xFF1E5A9C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x40FFFFFF)),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 22, color: _C.amber300),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(tr('GST INPUT ELIGIBLE'),
                          overflow: TextOverflow.ellipsis,
                          style: _t(11, FontWeight.w800, _C.amber300, ls: 0.8)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tr('GST invoice'),
                          style: _t(10, FontWeight.w600, Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: _t(11, FontWeight.w400, const Color(0xFFE2E8F0),
                        height: 1.4),
                    children: [
                      TextSpan(text: tr('Prices include GST. ')),
                      TextSpan(
                        text: tr('Claim input tax credit'),
                        style: _t(11, FontWeight.w800, Colors.white),
                      ),
                      TextSpan(text: tr(' on the GST invoice for this order')),
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

  // ---------------------------------------------------------------------------
  // Cart item card
  // ---------------------------------------------------------------------------

  Widget _buildCartItem(CartItemModel item) {
    final qty = item.quantity;
    final cod = item.codAvailable;
    final selected = _selected.contains(item.id);

    return GestureDetector(
      onTap: () => _toggleSelect(item),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? _C.blue600 : _C.slate200, width: selected ? 1.5 : 1),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Select
                Padding(
                  padding: const EdgeInsets.only(top: 26, right: 4),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => _toggleSelect(item),
                      activeColor: _C.blue600,
                      side: const BorderSide(color: _C.slate300, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Thumbnail
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _C.slate100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.slate200),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.thumbnail.isNotEmpty
                      ? Image.network(
                    item.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                  )
                      : _thumbPlaceholder(),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              trData(item.productName),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _t(14, FontWeight.w800, _C.slate900,
                                  height: 1.3),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _confirmRemove(item),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(6, 0, 0, 6),
                              child: Icon(Icons.delete_outline,
                                  size: 20, color: _C.slate400),
                            ),
                          ),
                        ],
                      ),
                      if (item.productCode.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          tr(item.productCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.robotoMono(
                              fontSize: 10, color: _C.slate500),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('₹${_inr(item.unitPrice)}',
                              style: _t(16, FontWeight.w800, _C.slate900)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _C.amber100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _C.amber200),
                            ),
                            child: Text(tr('B2B Price'),
                                style: _t(10, FontWeight.w700, _C.amber800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$qty × ₹${_inr(item.unitPrice)} = ₹${_inr(item.lineTotal)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(11, FontWeight.w700, selected ? _C.blue700 : _C.slate500),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Footer: COD note + stepper
            const SizedBox(height: 12),
            Container(height: 1, color: _C.slate100),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  cod ? Icons.payments_outlined : Icons.lock_outline,
                  size: 15,
                  color: cod ? _C.emerald600 : _C.slate400,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    cod ? tr('COD Available') : tr('Prepaid only'),
                    style: _t(11, FontWeight.w600,
                        cod ? _C.emerald700 : _C.slate500),
                  ),
                ),
                _buildStepper(item),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return const Center(
      child: Icon(Icons.inventory_2_outlined, size: 30, color: _C.slate400),
    );
  }

  Widget _buildStepper(CartItemModel item) {
    final isLast = item.quantity <= 1;
    final busy = _updating.contains(item.id);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _C.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: isLast ? Icons.delete_outline : Icons.remove,
            color: isLast ? _C.red : _C.slate600,
            tooltip: isLast ? tr('Remove item') : tr('Decrease quantity'),
            onTap: busy ? null : () => _changeQuantity(item, -1),
          ),
          SizedBox(
            width: 38,
            child: busy
                ? const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue600),
              ),
            )
                : Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: _t(13, FontWeight.w800, _C.slate900),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            color: _C.blue600,
            tooltip: tr('Increase quantity'),
            onTap: busy ? null : () => _changeQuantity(item, 1),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trust badges
  // ---------------------------------------------------------------------------

  Widget _buildTrustBadges() {
    Widget badge(IconData icon, Color color, String text) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.slate200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr(text),
                    style: _t(10.5, FontWeight.w600, _C.slate600, height: 1.25)),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        badge(Icons.shield_outlined, _C.emerald600, tr('OnyxSafe Escrow Protected')),
        const SizedBox(width: 8),
        badge(Icons.credit_card_outlined, _C.blue600, tr('Trade Credit: 30 Days')),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Order summary sheet
  // ---------------------------------------------------------------------------

  Widget _buildSummarySheet() {
    _syncShipping();
    final count = _selectedItems.length;
    final units = _selectedUnits;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.slate200)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: _C.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // ── 1. Subtotal Row ──
          _vRow(
            label: count == 0
                ? tr('Subtotal (no items selected)')
                : tr('Subtotal ({0} {1} · {2} qty)', [count, count == 1 ? 'item' : 'items', units]),
            value: '₹${_inr(_subtotal)}',
          ),
          const SizedBox(height: 6),

          // ── 2. Tax Row ──
          _vRow(
            label: tr('Tax (12% GST)'),
            labelTrailing: Tooltip(
              message: tr('Tax is calculated as 12% of the subtotal.'),
              triggerMode: TooltipTriggerMode.tap,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.info_outline, size: 14, color: _C.slate400),
              ),
            ),
            value: '₹${_inr(_tax)}',
          ),
          const SizedBox(height: 6),

          // ── 3. Shipping Row ──
          _vRow(
            label: _shipEstimate != null ? tr('Shipping (estimated)') : tr('Shipping & Freight'),
            labelTrailing: _shipPincode == null && _shipNote == null
                ? null
                : Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: _shipNote ??
                    tr('Live courier rate to your saved address. Final charge is confirmed at checkout.'),
                triggerMode: TooltipTriggerMode.tap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _C.amber50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      _shipPincode != null && _shipPincode!.isNotEmpty
                          ? tr('Bulk Hub')
                          : 'info',
                      style: _t(9, FontWeight.w700, _C.amber700)),
                ),
              ),
            ),
            value: _shippingText,
          ),

          const SizedBox(height: 8),
          Container(height: 1, color: _C.slate200),
          const SizedBox(height: 8),

          // ── 4. Total Row ──
          _vRow(
            label: tr('Total'),
            labelSuffix: tr('Including all statutory taxes'),
            value: '₹${_inr(_total)}',
            isTotal: true,
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: count == 0 ? _C.slate200 : _C.blue600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: count == 0 || _updating.isNotEmpty
                    ? null
                    : () async {
                  final done = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckoutScreen(items: _selectedItems),
                    ),
                  );
                  if (!mounted) return;
                  CartService.resetShippingAddress();
                  setState(() => _shipKey = '');
                  if (done == true) _loadCartItems();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _C.slate500,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        count == 0 ? tr('Select items to checkout') : tr('Proceed to Checkout ({0})', [count]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(13, FontWeight.w800, count == 0 ? _C.slate500 : Colors.white),
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A helper to render prices vertically (stacked) cleanly.
  Widget _vRow({
    required String label,
    required String value,
    Widget? labelTrailing,
    String? labelSuffix,
    bool isTotal = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tr(label),
                      style: _t(
                          isTotal ? 12 : 11.5,
                          isTotal ? FontWeight.w800 : FontWeight.w500,
                          isTotal ? _C.slate900 : _C.slate600
                      ),
                    ),
                  ),
                  if (labelTrailing != null) labelTrailing,
                ],
              ),
              if (labelSuffix != null) ...[
                const SizedBox(height: 2),
                Text(
                  tr(labelSuffix),
                  style: _t(9.5, FontWeight.w500, _C.slate400),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          tr(value),
          style: _t(
            isTotal ? 18 : 11.5,
            isTotal ? FontWeight.w800 : FontWeight.w700,
            _C.slate900,
            ls: isTotal ? -0.5 : null,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Quantity stepper button
// -----------------------------------------------------------------------------

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr(tooltip),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _C.slate200),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 2,
                  offset: Offset(0, 1)),
            ],
          ),
          child: Icon(icon, size: 16, color: onTap == null ? _C.slate300 : color),
        ),
      ),
    );
  }
}




