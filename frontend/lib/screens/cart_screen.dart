import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/cart_model.dart';
import '../services/cart_service.dart';
import '../utils/shared_preferences_helper.dart';

/// Design tokens from the HTML design (Tailwind slate / brand / amber).
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
  static const blue50 = Color(0xFFEFF6FF);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue900 = Color(0xFF1E3A8A);
  static const indigo950 = Color(0xFF1E1B4B);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber200 = Color(0xFFFDE68A);
  static const amber300 = Color(0xFFFCD34D);
  static const amber700 = Color(0xFFB45309); // CTA + accent
  static const amber800 = Color(0xFF92400E);
  static const amber900 = Color(0xFF78350F);
  static const red = Color(0xFFDC2626);
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
          _error = 'User not logged in. Please login first.';
          _isLoading = false;
        });
        return;
      }

      // STEP 2: access token
      final token = await SharedPreferencesHelper.getAccessToken();

      if (token == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Session expired. Please login again.';
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
        } else {
          _error = 'Failed to load cart items';
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

  double get _subtotal {
    return _cartItems.fold(
        0, (sum, item) => sum + (item.unitPrice * item.quantity));
  }

  double get _tax => _subtotal * 0.12;
  double get _shipping => _cartItems.isEmpty ? 0.0 : 500.0;
  double get _total => _subtotal + _tax + _shipping;

  Future<void> _updateQuantity(int cartId, int newQuantity) async {
    if (newQuantity <= 0) {
      _removeItem(cartId);
      return;
    }

    // Optimistic update
    final previousItems = List<CartItemModel>.from(_cartItems);
    setState(() {
      final index = _cartItems.indexWhere((item) => item.id == cartId);
      if (index != -1) {
        _cartItems[index] = CartItemModel(
          id: _cartItems[index].id,
          productId: _cartItems[index].productId,
          productName: _cartItems[index].productName,
          productCode: _cartItems[index].productCode,
          thumbnail: _cartItems[index].thumbnail,
          unitPrice: _cartItems[index].unitPrice,
          quantity: newQuantity,
          codAvailable: _cartItems[index].codAvailable,
        );
      }
    });

    try {
      final response = await CartService.updateCartQuantity(
        UpdateCartQuantityRequest(
          cartId: cartId,
          quantity: newQuantity,
        ),
      );

      if (!response.status) {
        if (!mounted) return;
        setState(() => _cartItems = previousItems);
        _showSnackBar(response.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cartItems = previousItems);
      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _removeItem(int cartId) async {
    // Optimistic update
    final previousItems = List<CartItemModel>.from(_cartItems);
    setState(() {
      _cartItems.removeWhere((item) => item.id == cartId);
    });

    try {
      final response = await CartService.removeFromCart(
        RemoveFromCartRequest(cartItemId: cartId),
      );

      if (response.status) {
        _showSnackBar(response.message);
      } else {
        if (!mounted) return;
        setState(() => _cartItems = previousItems);
        _showSnackBar(response.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cartItems = previousItems);
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
        title: Text('Clear entire cart?',
            style: _t(17, FontWeight.w800, _C.slate900)),
        content: Text(
          'All ${_cartItems.length} items will be removed from your cart.',
          style: _t(13, FontWeight.w500, _C.slate500, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: _t(13, FontWeight.w700, _C.slate600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear All', style: _t(13, FontWeight.w800, _C.red)),
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
      _showSnackBar('$failed item(s) could not be removed', isError: true);
      await _loadCartItems();
    } else {
      setState(() => _cartItems = []);
      _showSnackBar('Cart cleared');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _t(13, FontWeight.w600, Colors.white)),
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
                    Text('Your cart is empty',
                        style: _t(20, FontWeight.w800, _C.slate900, ls: -0.3)),
                    const SizedBox(height: 8),
                    Text(
                      'Start adding products from the catalog',
                      textAlign: TextAlign.center,
                      style: _t(13, FontWeight.w500, _C.slate500),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadCartItems,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.slate900,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('Refresh Cart',
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
            Text('Failed to load cart',
                style: _t(18, FontWeight.w800, _C.slate900)),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: _t(13, FontWeight.w500, _C.slate500, height: 1.45),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _loadCartItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.amber700,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Retry', style: _t(14, FontWeight.w700, Colors.white)),
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
            valueColor: AlwaysStoppedAnimation<Color>(_C.amber700),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCartItems,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                _buildTitleRow(),
                const SizedBox(height: 14),
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
              Text('Active B2B Cart',
                  style: _t(18, FontWeight.w800, _C.slate900, ls: -0.4)),
              const SizedBox(height: 2),
              Text(
                '$count ${count == 1 ? 'Item' : 'Items'} • Factory Direct Verification',
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
          child: Text('Clear All', style: _t(12, FontWeight.w700, _C.blue600)),
        ),
      ],
    );
  }

  Widget _buildGstBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_C.blue900, _C.indigo950],
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
              color: const Color(0x4D2563EB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x4D60A5FA)),
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
                      child: Text('GST INPUT ELIGIBLE',
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
                      child: Text('12% ITC',
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
                      const TextSpan(text: 'Claim up to '),
                      TextSpan(
                        text: '₹${_inr(_tax)} ITC',
                        style: _t(11, FontWeight.w800, Colors.white),
                      ),
                      const TextSpan(text: ' on your GST invoice for this order'),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.slate200),
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
                            item.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _t(14, FontWeight.w800, _C.slate900,
                                height: 1.3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _removeItem(item.id),
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
                        item.productCode,
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
                          child: Text('B2B Price',
                              style: _t(10, FontWeight.w700, _C.amber800)),
                        ),
                      ],
                    ),
                    if (qty > 1) ...[
                      const SizedBox(height: 3),
                      Text(
                        '$qty × ₹${_inr(item.unitPrice)} = ₹${_inr(item.unitPrice * qty)}',
                        style: _t(11, FontWeight.w600, _C.slate500),
                      ),
                    ],
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
                  cod ? 'COD Available' : 'Prepaid only',
                  style: _t(11, FontWeight.w600,
                      cod ? _C.emerald700 : _C.slate500),
                ),
              ),
              _buildStepper(item),
            ],
          ),
        ],
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
            tooltip: isLast ? 'Remove item' : 'Decrease quantity',
            onTap: () => _updateQuantity(item.id, item.quantity - 1),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: _t(13, FontWeight.w800, _C.slate900),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            color: _C.blue600,
            tooltip: 'Increase quantity',
            onTap: () => _updateQuantity(item.id, item.quantity + 1),
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
                child: Text(text,
                    style: _t(10.5, FontWeight.w600, _C.slate600, height: 1.25)),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        badge(Icons.shield_outlined, _C.emerald600, 'OnyxSafe Escrow Protected'),
        const SizedBox(width: 8),
        badge(Icons.credit_card_outlined, _C.blue600, 'Trade Credit: 30 Days'),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Order summary sheet
  // ---------------------------------------------------------------------------

  Widget _buildSummarySheet() {
    final count = _cartItems.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _C.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(
            label: 'Subtotal ($count ${count == 1 ? 'item' : 'items'})',
            value: '₹${_inr(_subtotal)}',
          ),
          const SizedBox(height: 7),
          _summaryRow(
            label: 'Tax (12% GST)',
            value: '₹${_inr(_tax)}',
            labelTrailing: const Tooltip(
              message: 'GST is calculated at 12% on the subtotal',
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(Icons.info_outline, size: 14, color: _C.slate400),
            ),
          ),
          const SizedBox(height: 7),
          _summaryRow(
            label: 'Shipping & Freight',
            value: '₹${_inr(_shipping)}',
            labelTrailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _C.amber50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Bulk Hub',
                  style: _t(10, FontWeight.w700, _C.amber700)),
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: _C.slate200),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: _t(14, FontWeight.w800, _C.slate900)),
                    Text('Including all statutory taxes',
                        style: _t(10, FontWeight.w500, _C.slate400)),
                  ],
                ),
              ),
              Text('₹${_inr(_total)}',
                  style: _t(22, FontWeight.w800, _C.slate900, ls: -0.5)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                // TODO: navigate to checkout
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.amber700,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0x66B45309),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Proceed to Checkout',
                      style: _t(15, FontWeight.w800, Colors.white)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 19),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    Widget? labelTrailing,
  }) {
    return Row(
      children: [
        Flexible(
          child: Text(label, style: _t(12.5, FontWeight.w500, _C.slate600)),
        ),
        if (labelTrailing != null) ...[
          const SizedBox(width: 5),
          labelTrailing,
        ],
        const Spacer(),
        Text(value, style: _t(12.5, FontWeight.w700, _C.slate900)),
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
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}