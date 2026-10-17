// lib/screens/reorder_screen.dart
//
// Re-order a product from My Orders.
//   • shows the product from the old order (photo, name, seller, last order)
//   • quantity stepper (starts at the old quantity)
//   • "Add to cart"  -> cart/add/ with the chosen quantity
//   • "Buy now"      -> puts exactly this quantity in the cart, then opens Checkout
//                       with only this item
// Pops with `true` when an order was placed from here.
//
// Prices can change after the first order: the estimate uses the old price,
// Checkout shows the current one.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';
import '../services/cart_service.dart';
import '../utils/shared_preferences_helper.dart';
import 'checkout_screen.dart';

const _brand = Color(0xFF6366F1);
const _violet = Color(0xFF8B5CF6);
const _accent = Color(0xFFF97316);
const _green = Color(0xFF10B981);

class ReorderScreen extends StatefulWidget {
  final OrderData order;

  const ReorderScreen({super.key, required this.order});

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  late int _qty = widget.order.product.quantity < 1 ? 1 : widget.order.product.quantity;
  bool _adding = false;
  bool _buying = false;

  OrderData get _o => widget.order;
  int get _productId => _o.product.id;
  bool get _busy => _adding || _buying;

  /// Price per unit on the old order (total / quantity).
  double get _oldUnitPrice {
    final q = _o.product.quantity;
    return q > 0 ? _o.totalAmount / q : _o.totalAmount;
  }

  double get _estimate => _oldUnitPrice * _qty;

  // ===================================================================
  // ACTIONS
  // ===================================================================
  Future<int?> _userId() async {
    final id = await SharedPreferencesHelper.getUserId();
    if (id == null && mounted) _snack('Please login to re-order', error: true);
    return id;
  }

  Future<void> _addToCart() async {
    if (_busy) return;
    final userId = await _userId();
    if (userId == null) return;
    setState(() => _adding = true);
    try {
      final r = await CartService.addToCart(
        AddToCartRequest(productId: _productId, userId: userId, quantity: _qty),
      );
      if (!mounted) return;
      if (!r.status) {
        _snack(r.message, error: true);
        return;
      }
      await _addedDialog();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// Make the cart hold exactly [_qty] of this product, then checkout only it.
  Future<void> _buyNow() async {
    if (_busy) return;
    final userId = await _userId();
    if (userId == null) return;
    setState(() => _buying = true);
    try {
      // 1. What is in the cart already?
      var cart = await CartService.getCartList(GetCartListRequest(userId: userId));
      final existing = cart.cartItems.where((c) => c.productId == _productId).firstOrNull;

      // 2. cart/add/ adds to the existing row, so send only the difference.
      final delta = _qty - (existing?.quantity ?? 0);
      if (delta != 0) {
        final r = await CartService.addToCart(
          AddToCartRequest(productId: _productId, userId: userId, quantity: delta),
        );
        if (!r.status) throw Exception(r.message);
        cart = await CartService.getCartList(GetCartListRequest(userId: userId));
      }

      final item = cart.cartItems.where((c) => c.productId == _productId).firstOrNull;
      if (!mounted) return;
      if (item == null) {
        _snack('Could not add this product to your cart. It may no longer be available.',
            error: true);
        return;
      }

      // 3. Checkout with only this item.
      setState(() => _buying = false);
      final placed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => CheckoutScreen(items: [item])),
      );
      if (placed == true && mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted && _buying) setState(() => _buying = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? DT.error : DT.onyx900,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _addedDialog() async {
    final goBack = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: DT.emerald50, shape: BoxShape.circle),
          child: const Icon(Icons.shopping_cart_checkout_rounded, color: _green, size: 28),
        ),
        title: Text('Added to cart',
            textAlign: TextAlign.center, style: DT.text(size: 17, weight: FontWeight.w800)),
        content: Text(
          '$_qty × ${_o.product.name} is in your cart. Open the Cart tab to checkout.',
          textAlign: TextAlign.center,
          style: DT.text(size: 13, color: DT.slate500, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: DT.onyx700,
                    side: const BorderSide(color: DT.slate200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Stay here'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to orders'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (goBack == true && mounted) Navigator.pop(context, false);
  }

  // ===================================================================
  // BUILD
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    final missing = _productId <= 0;
    return Scaffold(
      backgroundColor: DT.background,
      appBar: _appBar(),
      body: missing
          ? _unavailable()
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _productCard(),
          const SizedBox(height: 14),
          _lastOrderCard(),
          const SizedBox(height: 14),
          _quantityCard(),
          const SizedBox(height: 14),
          _priceNote(),
        ],
      ),
      bottomNavigationBar: missing ? null : _bottomBar(),
    );
  }

  PreferredSizeWidget _appBar() => PreferredSize(
    preferredSize: const Size.fromHeight(64),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4F46E5), _brand, _violet]),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Re-order',
                        style: DT.text(size: 18, weight: FontWeight.w700, color: Colors.white)),
                    Text('From order ${_o.orderNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 12, color: const Color(0xFFE0E7FF))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: DT.slate200),
      boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
    ),
    child: child,
  );

  Widget _productCard() {
    final img = _o.product.thumbnailS3Key;
    return _card(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 92,
              height: 92,
              color: DT.slate100,
              child: img.startsWith('http')
                  ? Image.network(img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const Icon(Icons.inventory_2_outlined, color: DT.slate400, size: 32))
                  : const Icon(Icons.inventory_2_outlined, color: DT.slate400, size: 32),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_o.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 15.5, weight: FontWeight.w800, color: DT.onyx900, height: 1.3)),
                if (_o.company.name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 14, color: DT.slate400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(_o.company.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 12, color: DT.slate500)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text('${_rupees(_oldUnitPrice)} / unit',
                    style: DT.text(size: 16, weight: FontWeight.w900, color: _brand)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastOrderCard() => _card(
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: DT.blue50, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.history_rounded, color: _brand, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Last ordered ${_o.formattedDate}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 13.5, weight: FontWeight.w700, color: DT.onyx900)),
              const SizedBox(height: 2),
              Text('${_o.product.quantity} unit${_o.product.quantity == 1 ? '' : 's'} · ${_rupees(_o.totalAmount)}',
                  style: DT.text(size: 12, color: DT.slate500)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: DT.slate100, borderRadius: BorderRadius.circular(999)),
          child: Text(_o.statusLabel,
              style: DT.text(size: 10.5, weight: FontWeight.w700, color: DT.onyx700)),
        ),
      ],
    ),
  );

  Widget _quantityCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quantity', style: DT.text(size: 14.5, weight: FontWeight.w800)),
                  Text('Same as last time, or change it',
                      style: DT.text(size: 12, color: DT.slate500)),
                ],
              ),
            ),
            _stepper(),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in {_o.product.quantity < 1 ? 1 : _o.product.quantity, 5, 10, 25, 50}.toList()..sort())
              ChoiceChip(
                label: Text(q == _o.product.quantity ? '$q (last)' : '$q'),
                selected: _qty == q,
                showCheckmark: false,
                selectedColor: _brand,
                backgroundColor: Colors.white,
                side: BorderSide(color: _qty == q ? _brand : DT.slate200),
                shape: const StadiumBorder(),
                labelStyle: DT.text(
                    size: 12.5, weight: FontWeight.w700, color: _qty == q ? Colors.white : DT.onyx700),
                onSelected: _busy ? null : (_) => setState(() => _qty = q),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _stepper() {
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
      color: onTap == null ? DT.slate100 : DT.blue50,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 20, color: onTap == null ? DT.slate300 : _brand),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, _qty > 1 && !_busy ? () => setState(() => _qty--) : null),
        SizedBox(
          width: 48,
          child: Text('$_qty',
              textAlign: TextAlign.center, style: DT.text(size: 18, weight: FontWeight.w900)),
        ),
        btn(Icons.add_rounded, _qty < 9999 && !_busy ? () => setState(() => _qty++) : null),
      ],
    );
  }

  Widget _priceNote() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: DT.amber50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: DT.amber200),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: DT.amber700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'The estimate uses your last price. Checkout shows today\'s price, tax and delivery.',
            style: DT.text(size: 12, color: DT.amber900, height: 1.45),
          ),
        ),
      ],
    ),
  );

  Widget _bottomBar() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: DT.slate200)),
      boxShadow: [BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, -4))],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Estimated total', style: DT.text(size: 12, color: DT.slate500)),
                const Spacer(),
                Text(_rupees(_estimate), style: DT.text(size: 18, weight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _addToCart,
                      icon: _adding
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _brand))
                          : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: Text(_adding ? 'Adding…' : 'Add to cart',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: const BorderSide(color: _brand, width: 1.4),
                        textStyle: DT.text(size: 14, weight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_brand, _violet, _accent]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _buyNow,
                        icon: _buying
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.flash_on_rounded, size: 18),
                        label: Text(_buying ? 'Please wait…' : 'Buy now',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                          textStyle: DT.text(size: 14, weight: FontWeight.w800, color: Colors.white),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _unavailable() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: DT.slate100, shape: BoxShape.circle),
            child: const Icon(Icons.remove_shopping_cart_outlined, size: 38, color: DT.slate400),
          ),
          const SizedBox(height: 16),
          Text('Product not available',
              textAlign: TextAlign.center, style: DT.text(size: 17, weight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('This product can\'t be ordered again. It may have been removed by the seller.',
              textAlign: TextAlign.center,
              style: DT.text(size: 13, color: DT.slate500, height: 1.45)),
        ],
      ),
    ),
  );
}

String _rupees(double v) {
  final n = v.round();
  final s = n.abs().toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  final rest = s
      .substring(0, s.length - 3)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
  return '₹$rest,$last3';
}
