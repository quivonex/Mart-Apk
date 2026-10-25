import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import 'order_detail_screen.dart';
import 'return_orders_screen.dart';
import 'reorder_screen.dart';
import '../utils/order_payment_helper.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kRed = Color(0xFFC62828);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = [
    'All',
    'Pending',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled / Returns',
  ];

  /// Backend statuses shown under each tab (every status belongs to one tab).
  static const List<Set<String>> _tabStatuses = [
    {},
    {'PENDING'},
    {'CONFIRMED', 'PACKED'},
    {'SHIPPED', 'OUT_FOR_DELIVERY'},
    {'DELIVERED'},
    {'CANCELLED', 'RETURN_REQUESTED', 'RETURN_PICKUP', 'RETURN_IN_TRANSIT', 'RETURNED', 'REFUNDED'},
  ];

  List<OrderData> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await OrderService.getMyOrders({});
      setState(() {
        _orders = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<OrderData> get _filteredOrders {
    if (_selectedTab == 0) return _orders;
    final wanted = _tabStatuses[_selectedTab];
    return _orders.where((o) => wanted.contains(o.status.toUpperCase())).toList();
  }

  Future<void> _payNow(OrderData order) async {
    final r = await OrderPaymentHelper.pay(
      context,
      shipOrderId: order.orderId,
      description: tr('Order {0}', [order.orderNumber]),
    );
    if (!mounted) return;
    if (r == OrderPayOutcome.paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Payment received for {0}. Your order is confirmed.', [order.orderNumber]))),
      );
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppConstants.surfaceColor,
      child: Column(
        children: [
          _buildTabBar(),
          if (_hasReturns) _buildReturnsLink(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

    bool get _hasReturns => _orders.any((o) {
        final s = o.status.toUpperCase();
        return s.contains('RETURN') || s == 'REFUNDED';
      });

  // "My returns" → shipping/return-orders/ list with tracking
  Widget _buildReturnsLink() {
    final n = _orders.where((o) {
      final s = o.status.toUpperCase();
      return s.contains('RETURN') || s == 'REFUNDED';
    }).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: const Color(0xFFEAF1F9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReturnOrdersScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9DBEE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_return_outlined, size: 20, color: _kBrand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('My returns · {0} order{1}', [n, n == 1 ? '' : 's']),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _kBrand),
                  ),
                ),
                Text(tr('Track'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kBrand)),
                const Icon(Icons.chevron_right_rounded, color: _kBrand),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final isSelected = _selectedTab == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? _kBrand
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  tr(_tabs[index]),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppConstants.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor:
          AlwaysStoppedAnimation<Color>(_kBrand),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_filteredOrders.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(_filteredOrders[index]);
        },
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppConstants.textLight.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedTab == 0
                ? tr('No orders found')
                : tr('No {0} orders', [tr(_tabs[_selectedTab])]),
            style: const TextStyle(
              fontSize: 16,
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(tr('Refresh')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: _kRed,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              tr('Failed to load orders'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kRed,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(_error!),
              style: const TextStyle(
                fontSize: 13,
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                tr('Retry'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderData order) {
    final Color statusColor =
    order.awaitingPayment ? const Color(0xFFF7931E) : Color(order.statusColorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(order.orderNumber),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(order.formattedDate),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tr(order.statusLabel),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppConstants.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  image: order.product.thumbnailS3Key.isNotEmpty
                      ? DecorationImage(
                    image: NetworkImage(order.product.thumbnailS3Key),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: order.product.thumbnailS3Key.isEmpty
                    ? const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppConstants.textLight,
                  size: 24,
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trData(order.product.name),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('Qty: {0}', [order.product.quantity]),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('Total Amount'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppConstants.textSecondary,
                ),
              ),
              Text(
                tr(order.formattedAmount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _kBrand,
                ),
              ),
            ],
          ),
          if (order.awaitingPayment) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Color(0xFFC2410C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('Online payment not completed. Pay to confirm this order.'),
                      style: TextStyle(fontSize: 12, color: Color(0xFFC2410C), height: 1.35),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _payNow(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand, foregroundColor: Colors.white,
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(tr('Pay now')),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderDetailScreen(orderId: order.orderId), // ✅ FIXED
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _kBrand.withOpacity(0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    tr('View Details'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kBrand,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final placed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => ReorderScreen(order: order)),
                    );
                    if (placed == true && mounted) _loadOrders();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    tr('Re-order'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}