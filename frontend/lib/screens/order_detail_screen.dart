import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';

// =====================================================================
//  OnyxMart M3 design tokens (mirrors the HTML / Tailwind config)
// =====================================================================

class _C {
  // Brand
  static const brand50 = Color(0xFFEFF6FF);
  static const brand100 = Color(0xFFDBEAFE);
  static const brand200 = Color(0xFFBFDBFE);
  static const brand600 = Color(0xFF2563EB);
  static const brand700 = Color(0xFF1D4ED8);

  // Onyx
  static const onyx900 = Color(0xFF0B132B);

  // Slate
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  // Emerald
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);

  // Amber
  static const amber50 = Color(0xFFFFFBEB);
  static const amber200 = Color(0xFFFDE68A);
  static const amber300 = Color(0xFFFCD34D);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const amber800 = Color(0xFF92400E);

  // Red
  static const red50 = Color(0xFFFEF2F2);
  static const red200 = Color(0xFFFECACA);
  static const red300 = Color(0xFFFCA5A5);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
}

TextStyle _ts(
    double size, {
      FontWeight weight = FontWeight.w500,
      Color color = _C.slate800,
      double? spacing,
      double? height,
    }) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    );

TextStyle _mono(
    double size, {
      FontWeight weight = FontWeight.w500,
      Color color = _C.slate400,
    }) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);

// =====================================================================
//  Status helpers
// =====================================================================

String _norm(String s) =>
    s.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '_');

bool _isCancelled(String s) => s.contains('CANCEL') || s.contains('FAILED');

bool _isReturn(String s) =>
    s.contains('RETURN') || s.contains('REFUND') || s.startsWith('RTO');

/// 0 = Placed, 1 = Shipped, 2 = Out for delivery, 3 = Delivered
int _stepIndex(String s) {
  if (s == 'DELIVERED') return 3;
  if (s.contains('OUT_FOR_DELIVERY')) return 2;
  if (s.contains('SHIPPED') ||
      s.contains('DISPATCH') ||
      s.contains('TRANSIT') ||
      s.contains('PICKED')) {
    return 1;
  }
  return 0;
}

class _StatusVisual {
  final Color bg;
  final Color fg;
  final Color border;
  const _StatusVisual(this.bg, this.fg, this.border);
}

_StatusVisual _statusVisual(String status) {
  final s = _norm(status);
  if (s == 'DELIVERED') {
    return const _StatusVisual(_C.brand50, _C.brand700, _C.brand200);
  }
  if (_isCancelled(s)) {
    return const _StatusVisual(_C.red50, _C.red700, _C.red200);
  }
  if (_isReturn(s)) {
    return const _StatusVisual(_C.amber50, _C.amber800, _C.amber200);
  }
  return const _StatusVisual(_C.slate100, _C.slate700, _C.slate200);
}

void _snack(BuildContext context, String message, {Color? background}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: _ts(13, weight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: background ?? _C.slate900,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

// =====================================================================
//  Shared UI building blocks
// =====================================================================

PreferredSizeWidget _onyxAppBar(
    BuildContext context, {
      required String title,
      String? subtitle,
      List<Widget>? actions,
    }) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleSpacing: 0,
    iconTheme: const IconThemeData(color: _C.slate700),
    shape: Border(
      bottom: BorderSide(color: _C.slate200.withOpacity(0.8)),
    ),
    leading: IconButton(
      tooltip: 'Go back',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: _ts(18,
              weight: FontWeight.w700, color: _C.slate900, spacing: -0.3),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: _ts(11, color: _C.slate400, spacing: 0.6),
          ),
        ],
      ],
    ),
    actions: actions,
  );
}

class _OnyxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _OnyxCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.slate200.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _C.brand600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: _ts(14, weight: FontWeight.w700, color: _C.slate900),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color border;
  final double radius;
  final double fontSize;

  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
    this.radius = 999,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: _ts(fontSize, weight: FontWeight.w700, color: fg, spacing: 0.4),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: _ts(12.5, color: _C.slate500)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ??
                  Text(
                    value ?? '-',
                    textAlign: TextAlign.right,
                    style: _ts(12.5,
                        weight: FontWeight.w700,
                        color: valueColor ?? _C.slate800),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  const _IconTap({
    required this.icon,
    required this.onTap,
    this.size = 16,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: size, color: _C.slate400),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final double size;

  const _Thumb({required this.url, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(Icons.image_outlined,
        color: _C.slate400, size: size * 0.4);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.slate200.withOpacity(0.7)),
      ),
      child: url.isEmpty
          ? placeholder
          : Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _C.slate300),
            ),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback? onPressed;
  final bool loading;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            splashColor: foreground.withOpacity(0.08),
            highlightColor: foreground.withOpacity(0.05),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: foreground),
                    )
                  else
                    Icon(icon, size: 19, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: _ts(14, weight: FontWeight.w700, color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.brand600),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: _C.red50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: _C.red600, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: _ts(16, weight: FontWeight.w700, color: _C.slate900)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _ts(13, color: _C.slate500, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Try again',
                    style: _ts(14,
                        weight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.brand600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
//  Order Detail Screen
// =====================================================================

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderDetailData? _orderDetail;
  bool _isLoading = true;
  String? _error;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetail();
  }

  Future<void> _loadOrderDetail() async {
    setState(() {
      _isLoading = _orderDetail == null; // keep content visible on refresh
      _error = null;
    });

    try {
      final response = await OrderService.getOrderDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _orderDetail = response.data;
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

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 52,
          height: 52,
          decoration:
          const BoxDecoration(color: _C.red50, shape: BoxShape.circle),
          child: const Icon(Icons.cancel_outlined, color: _C.red600, size: 26),
        ),
        title: Text(
          'Cancel this order?',
          textAlign: TextAlign.center,
          style: _ts(17, weight: FontWeight.w700, color: _C.slate900),
        ),
        content: Text(
          'This can\'t be undone. If you paid online, the refund goes back to your original payment method.',
          textAlign: TextAlign.center,
          style: _ts(13, color: _C.slate500, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.slate200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Keep order',
                        style: _ts(13.5,
                            weight: FontWeight.w700, color: _C.slate700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.red600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel order',
                        style: _ts(13.5,
                            weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final response = await OrderService.cancelOrder(widget.orderId);
      if (!mounted) return;
      _snack(context, response.message ?? 'Order cancelled.',
          background: _C.emerald600);
      _loadOrderDetail();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''),
          background: _C.red600);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  /// order.shipmentId → order.shipment.shipmentId fallback
  int get _effectiveShipmentId {
    if (_orderDetail == null) return 0;
    return _orderDetail!.shipmentId > 0
        ? _orderDetail!.shipmentId
        : _orderDetail!.shipment.shipmentId;
  }

  void _openTracking() {
    if (_orderDetail == null) return;
    final shipmentId = _effectiveShipmentId;

    if (shipmentId == 0) {
      _snack(context, 'Tracking isn\'t available for this order yet.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShipmentTrackingScreen(shipmentId: shipmentId),
      ),
    );
  }

  void _openReturn() {
    if (_orderDetail == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReturnOrderScreen(orderDetail: _orderDetail!),
      ),
    ).then((_) => _loadOrderDetail());
  }

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    _snack(context, message);
  }

  void _showHelp(OrderDetailData order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.slate200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Need help with this order?',
                  style:
                  _ts(16, weight: FontWeight.w700, color: _C.slate900)),
              const SizedBox(height: 6),
              Text(
                'Share your order ID with support so they can find your order quickly.',
                style: _ts(13, color: _C.slate500, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                  color: _C.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.slate200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(order.orderNumber,
                          style: _mono(14,
                              weight: FontWeight.w700, color: _C.slate900)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _copy(order.orderNumber, 'Order ID copied');
                      },
                      icon: const Icon(Icons.content_copy_rounded,
                          size: 16, color: _C.brand600),
                      label: Text('Copy',
                          style: _ts(13,
                              weight: FontWeight.w700, color: _C.brand600)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.slate50,
      appBar: _onyxAppBar(
        context,
        title: 'Order Details',
        subtitle: 'ONYXMART STORE',
        actions: [
          if (_orderDetail != null)
            IconButton(
              tooltip: 'Help',
              icon: const Icon(Icons.more_vert_rounded, color: _C.slate600),
              onPressed: () => _showHelp(_orderDetail!),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _LoadingView();

    if (_error != null && _orderDetail == null) {
      return _ErrorView(
        title: 'Couldn\'t load this order',
        message: _error!,
        onRetry: _loadOrderDetail,
      );
    }

    if (_orderDetail == null) {
      return Center(
        child: Text('Order not found.',
            style: _ts(14, color: _C.slate500)),
      );
    }

    final order = _orderDetail!;
    final shipmentId = _effectiveShipmentId;

    return RefreshIndicator(
      color: _C.brand600,
      onRefresh: _loadOrderDetail,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildStatusCard(order),
          const SizedBox(height: 14),
          _buildItemCard(order),
          if (order.shipment.courierCompany.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildShipmentCard(order),
          ],
          const SizedBox(height: 14),
          _buildAddressCard(order),
          const SizedBox(height: 14),
          _buildPaymentCard(order),
          if (order.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildNotesCard(order),
          ],
          const SizedBox(height: 20),
          _buildActions(order, shipmentId),
        ],
      ),
    );
  }

  // ---------------- Status card ----------------

  Widget _buildStatusCard(OrderDetailData order) {
    final s = _norm(order.status);
    final visual = _statusVisual(order.status);
    final terminal = _isCancelled(s) || _isReturn(s);

    return _OnyxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.orderNumber,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(16,
                                weight: FontWeight.w800,
                                color: _C.slate900,
                                spacing: 0.4),
                          ),
                        ),
                        const SizedBox(width: 2),
                        _IconTap(
                          icon: Icons.content_copy_rounded,
                          tooltip: 'Copy order ID',
                          onTap: () =>
                              _copy(order.orderNumber, 'Order ID copied'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Placed on ${order.formattedDate}',
                        style: _ts(12, color: _C.slate500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                label: order.status.toUpperCase().replaceAll('_', ' '),
                bg: visual.bg,
                fg: visual.fg,
                border: visual.border,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: _C.slate100),
          const SizedBox(height: 14),
          if (!terminal) ...[
            _DeliveryStepper(current: _stepIndex(s)),
            const SizedBox(height: 12),
          ],
          _buildStatusNote(order, s),
        ],
      ),
    );
  }

  Widget _buildStatusNote(OrderDetailData order, String s) {
    IconData icon;
    Color iconColor;
    List<InlineSpan> spans;

    final base = _ts(12, color: _C.slate600, height: 1.4);
    final bold = _ts(12, weight: FontWeight.w700, color: _C.slate800);

    if (_isCancelled(s)) {
      icon = Icons.cancel_rounded;
      iconColor = _C.red600;
      spans = [const TextSpan(text: 'This order has been cancelled.')];
    } else if (_isReturn(s)) {
      icon = Icons.assignment_return_rounded;
      iconColor = _C.amber700;
      spans = [
        const TextSpan(text: 'Return status: '),
        TextSpan(text: order.status.replaceAll('_', ' '), style: bold),
      ];
    } else {
      switch (_stepIndex(s)) {
        case 3:
          icon = Icons.task_alt_rounded;
          iconColor = _C.emerald600;
          spans = [
            const TextSpan(text: 'Package delivered at '),
            TextSpan(text: order.address.city, style: bold),
          ];
          break;
        case 2:
          icon = Icons.local_shipping_rounded;
          iconColor = _C.brand600;
          spans = [
            const TextSpan(text: 'Out for delivery to '),
            TextSpan(text: order.address.city, style: bold),
          ];
          break;
        case 1:
          icon = Icons.local_shipping_outlined;
          iconColor = _C.brand600;
          spans = order.shipment.courierCompany.isNotEmpty
              ? [
            const TextSpan(text: 'Shipped via '),
            TextSpan(
                text: order.shipment.courierCompany, style: bold),
          ]
              : [const TextSpan(text: 'Your package is on its way')];
          break;
        default:
          icon = Icons.inventory_2_outlined;
          iconColor = _C.slate500;
          spans = [
            const TextSpan(text: 'We\'re preparing your order for dispatch')
          ];
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _C.slate50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(TextSpan(style: base, children: spans))),
        ],
      ),
    );
  }

  // ---------------- Item card ----------------

  Widget _buildItemCard(OrderDetailData order) {
    final product = order.product;
    return _OnyxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ITEMS IN THIS SHIPMENT (${product.quantity})',
            style: _ts(11,
                weight: FontWeight.w700, color: _C.slate400, spacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(url: product.thumbnailS3Key),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _ts(14,
                                weight: FontWeight.w700,
                                color: _C.slate900,
                                height: 1.35),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.formattedSubtotal,
                          style: _ts(14,
                              weight: FontWeight.w700, color: _C.slate900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Qty: ${product.quantity} × ${order.formattedPrice}',
                            style: _ts(12, color: _C.slate600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        Text(
                          'Fulfilled by Onyx',
                          style: _ts(12,
                              weight: FontWeight.w600, color: _C.brand600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- Shipment card ----------------

  Widget _buildShipmentCard(OrderDetailData order) {
    final shipment = order.shipment;
    return _OnyxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.local_shipping_outlined,
            title: 'Shipment',
            trailing: shipment.status.isNotEmpty
                ? _Pill(
              label: shipment.status,
              bg: _C.slate100,
              fg: _C.slate600,
              border: _C.slate200,
              radius: 6,
            )
                : null,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              children: [
                _InfoRow(label: 'Courier', value: shipment.courierCompany),
                _InfoRow(
                  label: 'AWB code',
                  valueWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shipment.awbCode.isEmpty ? '-' : shipment.awbCode,
                        style: _mono(12,
                            weight: FontWeight.w700, color: _C.slate800),
                      ),
                      if (shipment.awbCode.isNotEmpty)
                        _IconTap(
                          icon: Icons.content_copy_rounded,
                          size: 14,
                          tooltip: 'Copy AWB code',
                          onTap: () =>
                              _copy(shipment.awbCode, 'AWB code copied'),
                        ),
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

  // ---------------- Address card ----------------

  Widget _buildAddressCard(OrderDetailData order) {
    final address = order.address;
    return _OnyxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.location_on_outlined,
            title: 'Delivery Address',
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.city,
                    style:
                    _ts(14, weight: FontWeight.w700, color: _C.slate800)),
                const SizedBox(height: 2),
                Text('${address.state} - ${address.pincode}',
                    style: _ts(12, color: _C.slate600, height: 1.5)),
                if (address.mobile.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _copy(address.mobile, 'Phone number copied'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call_outlined,
                              size: 15, color: _C.slate500),
                          const SizedBox(width: 6),
                          Text(address.mobile,
                              style: _ts(12,
                                  weight: FontWeight.w600,
                                  color: _C.slate700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Payment card ----------------

  Widget _buildPaymentCard(OrderDetailData order) {
    final paid = order.paymentStatus;
    return _OnyxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
              icon: Icons.receipt_outlined, title: 'Payment Summary'),
          const SizedBox(height: 10),
          _InfoRow(label: 'Method', value: order.paymentMethod),
          _InfoRow(
            label: 'Status',
            valueWidget: _Pill(
              label: paid ? 'Paid' : 'Pending',
              bg: paid ? _C.emerald50 : _C.amber50,
              fg: paid ? _C.emerald700 : _C.amber600,
              border: paid ? _C.emerald100 : _C.amber200,
              radius: 6,
              fontSize: 11.5,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1, color: _C.slate100),
          ),
          _InfoRow(label: 'Subtotal', value: order.formattedSubtotal),
          if (order.discountAmount > 0)
            _InfoRow(
              label: 'Discount',
              value: '- ${order.formattedDiscount}',
              valueColor: _C.emerald600,
            ),
          _InfoRow(label: 'Shipping', value: order.formattedShipping),
          _InfoRow(label: 'Tax (GST)', value: order.formattedTax),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: _C.slate900.withOpacity(0.9), width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount',
                    style:
                    _ts(14, weight: FontWeight.w700, color: _C.slate900)),
                Text(
                  order.formattedAmount,
                  style: _ts(17,
                      weight: FontWeight.w800,
                      color: _C.onyx900,
                      spacing: -0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Notes card ----------------

  Widget _buildNotesCard(OrderDetailData order) {
    return _OnyxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(icon: Icons.notes_rounded, title: 'Notes'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(order.notes,
                style: _ts(13, color: _C.slate600, height: 1.5)),
          ),
        ],
      ),
    );
  }

  // ---------------- Actions ----------------

  Widget _buildActions(OrderDetailData order, int shipmentId) {
    final isDelivered = _norm(order.status) == 'DELIVERED';
    final buttons = <Widget>[
      if (shipmentId > 0)
        _ActionButton(
          label: 'Track Order',
          icon: Icons.local_shipping_outlined,
          background: Colors.white,
          foreground: _C.brand700,
          border: _C.brand200,
          onPressed: _openTracking,
        ),
      if (order.canCancel)
        _ActionButton(
          label: _isCancelling ? 'Cancelling...' : 'Cancel Order',
          icon: Icons.cancel_outlined,
          background: _C.red50,
          foreground: _C.red700,
          border: _C.red300,
          loading: _isCancelling,
          onPressed: _isCancelling ? null : _cancelOrder,
        ),
      if (isDelivered)
        _ActionButton(
          label: 'Return Order',
          icon: Icons.assignment_return_outlined,
          background: _C.amber50,
          foreground: _C.amber800,
          border: _C.amber300,
          onPressed: _openReturn,
        ),
    ];

    return Column(
      children: [
        for (final b in buttons)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => _showHelp(order),
          icon: const Icon(Icons.help_outline_rounded,
              size: 16, color: _C.slate500),
          label: Text('Need help with this order?',
              style: _ts(12, weight: FontWeight.w600, color: _C.slate500)),
        ),
      ],
    );
  }
}

// =====================================================================
//  Delivery stepper (Placed → Shipped → Out for delivery → Delivered)
// =====================================================================

class _DeliveryStepper extends StatelessWidget {
  final int current;

  const _DeliveryStepper({required this.current});

  static const _labels = ['Placed', 'Shipped', 'Out for\ndelivery', 'Delivered'];
  static const _icons = [
    Icons.receipt_long_rounded,
    Icons.inventory_2_rounded,
    Icons.local_shipping_rounded,
    Icons.verified_rounded,
  ];
  static const double _colW = 64;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const start = _colW / 2;
        final end = width - _colW / 2;
        final segment = (end - start) / 3;
        final progressWidth = segment * current;

        return SizedBox(
          height: 62,
          child: Stack(
            children: [
              Positioned(
                left: start,
                right: _colW / 2,
                top: 11,
                child: Container(height: 2, color: _C.slate200),
              ),
              Positioned(
                left: start,
                top: 11,
                width: progressWidth,
                child: Container(height: 2, color: _C.brand600),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  4,
                      (i) => SizedBox(width: _colW, child: _buildStep(i)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(int i) {
    final delivered = current == 3;
    Widget circle;
    Color labelColor;
    FontWeight labelWeight = FontWeight.w600;

    if (i == 3 && delivered) {
      circle = Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: _C.emerald600,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _C.emerald100, spreadRadius: 4)],
        ),
        child: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
      );
      labelColor = _C.emerald700;
      labelWeight = FontWeight.w700;
    } else if (i < current) {
      circle = Container(
        width: 24,
        height: 24,
        decoration:
        const BoxDecoration(color: _C.brand600, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      );
      labelColor = _C.slate700;
    } else if (i == current) {
      circle = Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: _C.brand600,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _C.brand100, spreadRadius: 4)],
        ),
        child: Icon(_icons[i], size: 13, color: Colors.white),
      );
      labelColor = _C.brand700;
      labelWeight = FontWeight.w700;
    } else {
      circle = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _C.slate300, width: 1.5),
        ),
      );
      labelColor = _C.slate400;
    }

    return Column(
      children: [
        circle,
        const SizedBox(height: 6),
        Text(
          _labels[i],
          textAlign: TextAlign.center,
          maxLines: 2,
          style: _ts(10, weight: labelWeight, color: labelColor, height: 1.2),
        ),
      ],
    );
  }
}

// =====================================================================
//  Shipment Tracking Screen
// =====================================================================

class ShipmentTrackingScreen extends StatefulWidget {
  final int shipmentId;

  const ShipmentTrackingScreen({super.key, required this.shipmentId});

  @override
  State<ShipmentTrackingScreen> createState() =>
      _ShipmentTrackingScreenState();
}

class _ShipmentTrackingScreenState extends State<ShipmentTrackingScreen> {
  TrackShipmentData? _trackingData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracking();
  }

  Future<void> _loadTracking() async {
    setState(() {
      _isLoading = _trackingData == null;
      _error = null;
    });

    try {
      final response = await OrderService.trackShipment(widget.shipmentId);
      if (!mounted) return;
      setState(() {
        _trackingData = response.data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.slate50,
      appBar: _onyxAppBar(context,
          title: 'Track Shipment', subtitle: 'ONYXMART STORE'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _LoadingView();

    if (_error != null && _trackingData == null) {
      return _ErrorView(
        title: 'Couldn\'t load tracking',
        message: _error!,
        onRetry: _loadTracking,
      );
    }

    final tracking = _trackingData;
    if (tracking == null || tracking.trackingData == null) {
      return _buildEmpty(
          'No tracking updates yet. Pull down to check again later.');
    }

    final data = tracking.trackingData!;
    final track =
    data.shipmentTrack.isNotEmpty ? data.shipmentTrack.first : null;
    final activities = data.shipmentTrackActivities;

    return RefreshIndicator(
      color: _C.brand600,
      onRefresh: _loadTracking,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (track != null) _buildCourierCard(track),
          const SizedBox(height: 18),
          if (activities.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'TRACKING HISTORY',
                style: _ts(11,
                    weight: FontWeight.w700, color: _C.slate400, spacing: 1),
              ),
            ),
            _OnyxCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                children: [
                  for (var i = 0; i < activities.length; i++)
                    _buildTimelineEntry(
                      activities[i],
                      isFirst: i == 0,
                      isLast: i == activities.length - 1,
                    ),
                ],
              ),
            ),
          ] else
            _OnyxCard(
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 18, color: _C.slate400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tracking history will appear once the courier scans your package.',
                      style: _ts(12.5, color: _C.slate500, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return RefreshIndicator(
      color: _C.brand600,
      onRefresh: _loadTracking,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          const Icon(Icons.local_shipping_outlined,
              size: 44, color: _C.slate300),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(message,
                textAlign: TextAlign.center,
                style: _ts(13, color: _C.slate500, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildCourierCard(dynamic track) {
    return _OnyxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.brand50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: _C.brand600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.courierName as String,
                      style:
                      _ts(15, weight: FontWeight.w700, color: _C.slate900),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('AWB ', style: _ts(11.5, color: _C.slate400)),
                        Flexible(
                          child: Text(
                            track.awbCode as String,
                            overflow: TextOverflow.ellipsis,
                            style: _mono(11.5,
                                weight: FontWeight.w600, color: _C.slate600),
                          ),
                        ),
                        _IconTap(
                          icon: Icons.content_copy_rounded,
                          size: 13,
                          tooltip: 'Copy AWB code',
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: track.awbCode as String));
                            _snack(context, 'AWB code copied');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: _C.slate100),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Current status',
            valueWidget: _Pill(
              label: track.currentStatus as String,
              bg: _C.brand50,
              fg: _C.brand700,
              border: _C.brand200,
              radius: 6,
            ),
          ),
          _InfoRow(
            label: 'Expected delivery',
            value: track.formattedEdd as String,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(dynamic activity,
      {required bool isFirst, required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 3),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst ? _C.brand600 : Colors.white,
                    shape: BoxShape.circle,
                    border: isFirst
                        ? null
                        : Border.all(color: _C.slate300, width: 2),
                    boxShadow: isFirst
                        ? const [
                      BoxShadow(color: _C.brand100, spreadRadius: 4)
                    ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: _C.slate200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.status as String,
                    style: _ts(13,
                        weight: FontWeight.w700,
                        color: isFirst ? _C.slate900 : _C.slate700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    activity.activity as String,
                    style: _ts(12, color: _C.slate600, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: _C.slate400),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${activity.formattedDate}  |  ${activity.location}',
                          style: _ts(11, color: _C.slate400),
                        ),
                      ),
                    ],
                  ),
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
//  Return Order Screen
// =====================================================================

class _ReturnReason {
  final String value;
  final String label;
  final IconData icon;
  const _ReturnReason(this.value, this.label, this.icon);
}

class ReturnOrderScreen extends StatefulWidget {
  final OrderDetailData orderDetail;

  const ReturnOrderScreen({super.key, required this.orderDetail});

  @override
  State<ReturnOrderScreen> createState() => _ReturnOrderScreenState();
}

class _ReturnOrderScreenState extends State<ReturnOrderScreen> {
  final _reasonNoteController = TextEditingController();

  int _quantity = 1;
  String? _selectedReason;
  bool _isSubmitting = false;

  static const List<_ReturnReason> _reasons = [
    _ReturnReason('DAMAGED', 'Damaged product', Icons.broken_image_outlined),
    _ReturnReason('WRONG_ITEM', 'Wrong item received', Icons.swap_horiz_rounded),
    _ReturnReason('SIZE_ISSUE', 'Size or fit issue', Icons.straighten_rounded),
    _ReturnReason('QUALITY_ISSUE', 'Quality issue', Icons.thumb_down_alt_outlined),
    _ReturnReason('OTHER', 'Other', Icons.more_horiz_rounded),
  ];

  int get _maxQty => widget.orderDetail.product.quantity;

  @override
  void dispose() {
    _reasonNoteController.dispose();
    super.dispose();
  }

  Future<void> _submitReturn() async {
    if (_selectedReason == null) {
      _snack(context, 'Select a reason for the return.',
          background: _C.red600);
      return;
    }

    if (_quantity < 1 || _quantity > _maxQty) {
      _snack(context, 'Return quantity must be between 1 and $_maxQty.',
          background: _C.red600);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final note = _reasonNoteController.text.trim();
      final response = await OrderService.returnOrder(
        orderId: widget.orderDetail.orderId,
        quantity: _quantity,
        reason: _selectedReason!,
        reasonNote: note.isEmpty ? null : note,
      );

      if (!mounted) return;

      _snack(context, response.message ?? 'Return request submitted.',
          background: _C.emerald600);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''),
          background: _C.red600);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.orderDetail;

    return Scaffold(
      backgroundColor: _C.slate50,
      appBar: _onyxAppBar(context,
          title: 'Return Order', subtitle: order.orderNumber),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Product
            _OnyxCard(
              child: Row(
                children: [
                  _Thumb(url: order.product.thumbnailS3Key, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _ts(14,
                              weight: FontWeight.w700, color: _C.slate900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ordered: ${order.product.quantity} × ${order.formattedPrice}',
                          style: _ts(12, color: _C.slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            _label('Return quantity'),
            _OnyxCard(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items to return',
                            style: _ts(13.5,
                                weight: FontWeight.w600, color: _C.slate800)),
                        Text('Up to $_maxQty',
                            style: _ts(11.5, color: _C.slate400)),
                      ],
                    ),
                  ),
                  _qtyButton(
                    Icons.remove_rounded,
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style:
                      _ts(16, weight: FontWeight.w800, color: _C.slate900),
                    ),
                  ),
                  _qtyButton(
                    Icons.add_rounded,
                    _quantity < _maxQty
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            _label('Reason for return'),
            for (final reason in _reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildReasonTile(reason),
              ),

            const SizedBox(height: 14),
            _label('Additional notes (optional)'),
            TextField(
              controller: _reasonNoteController,
              maxLines: 4,
              maxLength: 500,
              style: _ts(13.5, color: _C.slate800),
              decoration: InputDecoration(
                hintText: 'Tell us what went wrong',
                hintStyle: _ts(13.5, color: _C.slate400),
                filled: true,
                fillColor: Colors.white,
                counterStyle: _ts(11, color: _C.slate400),
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.brand600, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _C.slate200.withOpacity(0.9))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.brand600,
                  disabledBackgroundColor: _C.brand600.withOpacity(0.6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : Text(
                  'Submit Return Request',
                  style: _ts(14.5,
                      weight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: _ts(11, weight: FontWeight.w700, color: _C.slate400, spacing: 1),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? _C.brand50 : _C.slate100,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon,
              size: 18, color: enabled ? _C.brand700 : _C.slate300),
        ),
      ),
    );
  }

  Widget _buildReasonTile(_ReturnReason reason) {
    final selected = _selectedReason == reason.value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedReason = reason.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? _C.brand50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _C.brand600 : _C.slate200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(reason.icon,
                  size: 20, color: selected ? _C.brand600 : _C.slate500),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason.label,
                  style: _ts(13.5,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _C.brand700 : _C.slate700),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? _C.brand600 : _C.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

