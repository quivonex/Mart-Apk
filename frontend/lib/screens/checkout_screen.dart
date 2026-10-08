// lib/screens/checkout_screen.dart
//
// Cart -> Proceed to checkout -> this screen.
//   1. Delivery address (saved addresses or add new)
//   2. Items
//   3. Payment: Cash on delivery (only if every product allows COD) or Pay online (Razorpay)
//   4. Place order -> one order per product (backend picks courier + shipping)
//      -> ordered items removed from cart -> online payment -> result screen
// Online orders that weren't paid stay in My Orders with "Pay now".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/cart_model.dart';
import '../services/cart_service.dart';
import '../services/checkout_service.dart';
import '../utils/order_payment_helper.dart';
import '../utils/shared_preferences_helper.dart';
import '../widgets/product_ui.dart';
import 'order_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItemModel> items;
  const CheckoutScreen({super.key, required this.items});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<DeliveryAddress> _addresses = [];
  DeliveryAddress? _address;
  bool _loadingAddresses = true;
  String? _addressError;
  bool _cod = false;
  bool _placing = false;
  final _notes = TextEditingController();

  bool get _codAllowed => widget.items.every((i) => i.codAvailable);
  double get _subtotal => widget.items.fold(0, (s, i) => s + i.unitPrice * i.quantity);

  @override
  void initState() {
    super.initState();
    _cod = false;
    _loadAddresses();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses({int? select}) async {
    setState(() {
      _loadingAddresses = true;
      _addressError = null;
    });
    final r = await CheckoutService.addresses();
    if (!mounted) return;
    setState(() {
      _loadingAddresses = false;
      _addresses = r.data ?? const [];
      _addressError = r.ok ? null : r.message;
      _address = _addresses.where((a) => a.id == (select ?? _address?.id)).firstOrNull ??
          (_addresses.isNotEmpty ? _addresses.first : null);
    });
  }

  String _inr(double v) => formatRupees(v);

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? DT.error : null));
  }

  // ── Address pickers ─────────────────────────────────────
  Future<void> _addAddress() async {
    final saved = await showModalBottomSheet<DeliveryAddress>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddressSheet(),
    );
    if (saved != null) await _loadAddresses(select: saved.id);
  }

  Future<void> _chooseAddress() async {
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(children: [
                  Expanded(child: Text('Deliver to', style: DT.text(size: 17, weight: FontWeight.w800))),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final a in _addresses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _addressTile(a, selected: a.id == _address?.id, onTap: () => Navigator.pop(ctx, a)),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'add'),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add a new address'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (picked == 'add') {
      _addAddress();
    } else if (picked is DeliveryAddress) {
      setState(() => _address = picked);
    }
  }

  // ── Place order ─────────────────────────────────────────
  Future<void> _placeOrder() async {
    final address = _address;
    if (address == null) {
      _snack('Add a delivery address first', error: true);
      return;
    }
    setState(() => _placing = true);

    final progress = ValueNotifier<String>('Placing your order…');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, __) => Text(v, style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx800)),
              ),
            ),
          ]),
        ),
      ),
    );

    final placed = <PlacedOrder>[];
    final failed = <(String, String)>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      progress.value = widget.items.length == 1
          ? 'Placing your order…'
          : 'Placing order ${i + 1} of ${widget.items.length}…';
      final r = await CheckoutService.placeOrder(
        productId: item.productId,
        addressId: address.id,
        quantity: item.quantity,
        cod: _cod,
        notes: _notes.text.trim(),
      );
      if (r.ok && r.data != null) {
        placed.add(r.data!);
        // Ordered -> remove from cart (the backend doesn't clear it).
        try {
          await CartService.removeFromCart(RemoveFromCartRequest(cartItemId: item.id));
        } catch (_) {}
      } else {
        failed.add((item.productName, r.message));
      }
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // progress dialog
    setState(() => _placing = false);

    if (placed.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Order not placed'),
          content: Text(failed.map((f) => '• ${f.$1}: ${f.$2}').join('\n')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    // Online: pay each order (one Razorpay payment per order, as on the website).
    if (!_cod) {
      for (var i = 0; i < placed.length; i++) {
        if (!mounted) return;
        final o = placed[i];
        final outcome = await OrderPaymentHelper.pay(
          context,
          shipOrderId: o.orderId,
          description: placed.length == 1
              ? 'Order ${o.orderNumber}'
              : 'Order ${o.orderNumber} (${i + 1} of ${placed.length})',
          phone: address.mobile,
        );
        if (outcome == OrderPayOutcome.paid) o.paid = true;
        if (outcome == OrderPayOutcome.cancelled) break; // rest can be paid later
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _OrderResultScreen(orders: placed, failed: failed, phone: address.mobile)),
    );
    if (mounted) Navigator.pop(context, true); // back to cart -> it reloads
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _addressSection(),
          const SizedBox(height: 16),
          _itemsSection(),
          const SizedBox(height: 16),
          _paymentSection(),
          const SizedBox(height: 16),
          _summarySection(),
        ],
      ),
      bottomNavigationBar: _footer(),
    );
  }

  Widget _addressTile(DeliveryAddress a, {required bool selected, VoidCallback? onTap}) => Material(
    color: selected ? PX.royal50 : Colors.white,
    borderRadius: BorderRadius.circular(DT.rMd),
    child: InkWell(
      borderRadius: BorderRadius.circular(DT.rMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: selected ? PX.royal600 : DT.slate200, width: selected ? 1.5 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? PX.royal600 : DT.slate400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.fullName} · ${a.mobile}', style: DT.text(size: 13.5, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${a.oneLine} – ${a.pincode}', style: DT.text(size: 12.5, color: DT.onyx600, height: 1.4)),
            ]),
          ),
        ]),
      ),
    ),
  );

  Widget _addressSection() => PxSection(
    title: 'Delivery address',
    icon: Icons.location_on_outlined,
    compact: true,
    trailing: _addresses.isNotEmpty
        ? PxLinkButton(label: 'Change', onTap: _chooseAddress)
        : null,
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _loadingAddresses
          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          : _address != null
          ? _addressTile(_address!, selected: true, onTap: _chooseAddress)
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_addressError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_addressError!, style: DT.text(size: 12, color: DT.error)),
          ),
        ElevatedButton.icon(
          onPressed: _addAddress,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add delivery address'),
        ),
      ]),
    ),
  );

  Widget _itemsSection() => PxSection(
    title: '${widget.items.length} item${widget.items.length == 1 ? '' : 's'}',
    icon: Icons.shopping_bag_outlined,
    compact: true,
    child: Column(children: [
      for (final i in widget.items)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(DT.rSm),
              child: SizedBox(
                width: 52,
                height: 52,
                child: i.thumbnail.isEmpty
                    ? const ColoredBox(color: DT.slate100, child: Icon(Icons.inventory_2_outlined, color: DT.slate400))
                    : Image.network(i.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: DT.slate100, child: Icon(Icons.inventory_2_outlined))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.productName, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 13.5, weight: FontWeight.w700)),
                Text('${i.quantity} × ${_inr(i.unitPrice)}', style: DT.text(size: 12, color: DT.slate500)),
              ]),
            ),
            Text(_inr(i.unitPrice * i.quantity), style: DT.text(size: 13.5, weight: FontWeight.w800)),
          ]),
        ),
    ]),
  );

  Widget _payOption({
    required bool selected,
    required bool enabled,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: selected ? PX.royal50 : Colors.white,
          borderRadius: BorderRadius.circular(DT.rMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(DT.rMd),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: selected ? PX.royal600 : DT.slate200, width: selected ? 1.5 : 1),
              ),
              child: Row(children: [
                Icon(icon, color: selected ? PX.royal600 : DT.slate500),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: DT.text(size: 14, weight: FontWeight.w800)),
                    Text(subtitle, style: DT.text(size: 12, color: DT.slate500)),
                  ]),
                ),
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? PX.royal600 : DT.slate400),
              ]),
            ),
          ),
        ),
      );

  Widget _paymentSection() => PxSection(
    title: 'Payment',
    icon: Icons.payments_outlined,
    compact: true,
    child: Column(children: [
      const SizedBox(height: 10),
      _payOption(
        selected: !_cod,
        enabled: true,
        icon: Icons.account_balance_wallet_outlined,
        title: 'Pay online',
        subtitle: 'UPI, cards, net banking – secured by Razorpay',
        onTap: () => setState(() => _cod = false),
      ),
      const SizedBox(height: 8),
      _payOption(
        selected: _cod,
        enabled: _codAllowed,
        icon: Icons.local_atm_rounded,
        title: 'Cash on delivery',
        subtitle: _codAllowed ? 'Pay when your order arrives' : 'Not available for some items in your cart',
        onTap: () => setState(() => _cod = true),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notes,
        maxLines: 2,
        decoration: pxInputDecoration(hint: 'Note for the seller (optional)', icon: Icons.sticky_note_2_outlined),
      ),
    ]),
  );

  Widget _summarySection() => PxSection(
    title: 'Summary',
    icon: Icons.receipt_long_outlined,
    compact: true,
    child: Column(children: [
      const SizedBox(height: 8),
      _row('Items', _inr(_subtotal)),
      _row('Shipping', 'Added by courier per order'),
      const Divider(height: 20),
      _row('To pay now', _cod ? 'On delivery' : '${_inr(_subtotal)} + shipping', bold: true),
      const SizedBox(height: 8),
      if (widget.items.length > 1)
        Text('Each product ships as a separate order from its seller.',
            style: DT.text(size: 11.5, color: DT.slate500)),
    ]),
  );

  Widget _row(String a, String b, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(a, style: DT.text(size: 13, color: bold ? DT.onyx900 : DT.onyx600, weight: bold ? FontWeight.w800 : FontWeight.w500))),
      Text(b, style: DT.text(size: bold ? 14.5 : 13, weight: bold ? FontWeight.w900 : FontWeight.w600)),
    ]),
  );

  Widget _footer() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: DT.slate200)),
      boxShadow: PX.stickyShadow,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Items total', style: DT.text(size: 11, color: DT.slate500)),
            Text(_inr(_subtotal), style: DT.text(size: 18, weight: FontWeight.w900)),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _placing || _address == null ? null : _placeOrder,
                child: Text(_cod ? 'Place order (COD)' : 'Place order & pay',
                    style: DT.text(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

// =====================================================================
// ADD ADDRESS SHEET  (order/address/create/)
// =====================================================================
class _AddressSheet extends StatefulWidget {
  const _AddressSheet();

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _c = {
    for (final k in ['full_name', 'mobile_no', 'address_line1', 'address_line2', 'village', 'taluka', 'district', 'city', 'state', 'pincode'])
      k: TextEditingController(),
  };
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SharedPreferencesHelper.getUsername().then((n) {
      if (mounted && n != null && _c['full_name']!.text.isEmpty) _c['full_name']!.text = n;
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final r = await CheckoutService.addAddress({for (final e in _c.entries) e.key: e.value.text.trim()});
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.ok) {
      Navigator.pop(context, r.data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message), backgroundColor: DT.error));
    }
  }

  Widget _f(String key, String label, {bool required = true, TextInputType? kb, List<TextInputFormatter>? fm, String? Function(String?)? v}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PxLabel(label, required: required, optional: !required),
          PxTextField(
            controller: _c[key]!,
            keyboardType: kb,
            inputFormatters: fm,
            capitalization: TextCapitalization.words,
            validator: v ?? (required ? (x) => (x ?? '').trim().isEmpty ? 'Required' : null : null),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              children: [
                Text('New delivery address', style: DT.text(size: 17, weight: FontWeight.w800)),
                const SizedBox(height: 12),
                _f('full_name', 'Full name'),
                _f('mobile_no', 'Mobile number',
                    kb: TextInputType.phone,
                    fm: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    v: (x) => RegExp(r'^[6-9]\d{9}$').hasMatch((x ?? '').trim()) ? null : 'Enter a valid 10-digit number'),
                _f('address_line1', 'House / building, street'),
                _f('address_line2', 'Area, landmark', required: false),
                Row(children: [
                  Expanded(child: _f('village', 'Village / locality')),
                  const SizedBox(width: 10),
                  Expanded(child: _f('taluka', 'Taluka')),
                ]),
                Row(children: [
                  Expanded(child: _f('district', 'District')),
                  const SizedBox(width: 10),
                  Expanded(child: _f('city', 'City')),
                ]),
                Row(children: [
                  Expanded(child: _f('state', 'State')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _f('pincode', 'Pincode',
                        kb: TextInputType.number,
                        fm: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        v: (x) => (x ?? '').trim().length == 6 ? null : '6 digits'),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Text('Save address'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// RESULT
// =====================================================================
class _OrderResultScreen extends StatefulWidget {
  final List<PlacedOrder> orders;
  final List<(String, String)> failed;
  final String phone;
  const _OrderResultScreen({required this.orders, required this.failed, required this.phone});

  @override
  State<_OrderResultScreen> createState() => _OrderResultScreenState();
}

class _OrderResultScreenState extends State<_OrderResultScreen> {
  Future<void> _pay(PlacedOrder o) async {
    final r = await OrderPaymentHelper.pay(context,
        shipOrderId: o.orderId, description: 'Order ${o.orderNumber}', phone: widget.phone);
    if (r == OrderPayOutcome.paid && mounted) setState(() => o.paid = true);
  }

  @override
  Widget build(BuildContext context) {
    final unpaid = widget.orders.where((o) => o.paymentMethod == 'PREPAID' && !o.paid).length;
    final total = widget.orders.fold<double>(0, (s, o) => s + o.total);
    return Scaffold(
      backgroundColor: DT.background,
      appBar: AppBar(title: const Text('Order placed'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: unpaid == 0 ? DT.emerald50 : DT.amber50,
                shape: BoxShape.circle,
              ),
              child: Icon(unpaid == 0 ? Icons.check_rounded : Icons.schedule_rounded,
                  size: 46, color: unpaid == 0 ? DT.emerald700 : DT.amber700),
            ),
          ),
          const SizedBox(height: 14),
          Text(unpaid == 0 ? 'Thank you! Your order is placed' : 'Order placed – payment pending',
              textAlign: TextAlign.center, style: DT.text(size: 19, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            unpaid == 0
                ? 'The seller will confirm and ship it soon.'
                : 'Pay now to confirm ${unpaid == 1 ? 'it' : 'them'}. You can also pay later from My Orders.',
            textAlign: TextAlign.center,
            style: DT.text(size: 13, color: DT.slate500),
          ),
          const SizedBox(height: 18),
          for (final o in widget.orders)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DT.rLg),
                border: Border.all(color: DT.slate200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(o.productName, style: DT.text(size: 14, weight: FontWeight.w800))),
                  o.paymentMethod == 'COD'
                      ? const PxPill(text: 'Cash on delivery', bg: DT.slate100, fg: DT.onyx700)
                      : o.paid
                      ? const PxPill(text: 'Paid', bg: DT.emerald50, fg: DT.emerald700, icon: Icons.check_rounded)
                      : const PxPill(text: 'Payment pending', bg: DT.amber50, fg: DT.amber800),
                ]),
                const SizedBox(height: 4),
                Text('Order ${o.orderNumber} · Qty ${o.quantity}', style: DT.text(size: 12, color: DT.slate500)),
                const SizedBox(height: 8),
                Text(
                  '${formatRupees(o.subtotal)} + ${o.shipping > 0 ? formatRupees(o.shipping) : 'free'} shipping = ${formatRupees(o.total)}',
                  style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.onyx800),
                ),
                if (o.paymentMethod == 'PREPAID' && !o.paid) ...[
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: () => _pay(o), child: Text('Pay ${formatRupees(o.total)} now')),
                ],
              ]),
            ),
          if (widget.failed.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DT.errorBg,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.errorBorder),
              ),
              child: Text(
                'Not ordered (still in your cart):\n${widget.failed.map((f) => '• ${f.$1}: ${f.$2}').join('\n')}',
                style: DT.text(size: 12.5, color: DT.error, height: 1.5),
              ),
            ),
          const SizedBox(height: 8),
          Text('Order total incl. shipping: ${formatRupees(total)}',
              textAlign: TextAlign.center, style: DT.text(size: 13, weight: FontWeight.w700)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('My orders')),
                      body: const OrdersScreen(),
                    ),
                  ),
                ),
                child: const Text('View my orders'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}