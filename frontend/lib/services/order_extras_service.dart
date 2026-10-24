// lib/services/order_extras_service.dart
//
// Orders – extra features (Bearer token)
//
//   POST shipping/download-invoice/      {order_id}
//        -> {success, order_id, order_number, shiprocket_order_id,
//            data:{is_invoice_created, invoice_url, not_created:[]}}   (Shiprocket)
//   POST shipping/return-orders/         {}
//        -> {success, count, data:[{return_id, return_number, order_id, order_number,
//            product, quantity, reason, reason_note, refund_amount, status,
//            order_status, created_at, updated_at}]}
//        ⚠ backend returns every user's returns → filtered here to my order ids.
//   POST shipping/return-order/track/    {return_id}
//        -> {success, data:{return_id, return_number, shipment_id, awb_code,
//            courier_company, status, tracking_status, tracking_data}}
//   POST order/address/update/           {id, full_name, mobile_no, address_line1, …, pincode}
//        -> {status:"success", data:{address}}

import '../models/order_model.dart';
import 'api_urls.dart';
import 'checkout_service.dart';
import 'order_service.dart';
import 'qnx_api.dart';

class OrderExtrasResult<T> {
  final bool ok;
  final T? data;
  final String message;
  final bool needsLogin;
  const OrderExtrasResult(this.ok, this.data, this.message, {this.needsLogin = false});
}

class ReturnOrderItem {
  final int returnId;
  final String returnNumber;
  final int orderId;
  final String orderNumber;
  final String product;
  final int quantity;
  final String reason;
  final String reasonNote;
  final double refundAmount;
  final String status;
  final String orderStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReturnOrderItem({
    required this.returnId,
    required this.returnNumber,
    required this.orderId,
    required this.orderNumber,
    required this.product,
    required this.quantity,
    required this.reason,
    required this.reasonNote,
    required this.refundAmount,
    required this.status,
    required this.orderStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReturnOrderItem.fromJson(Map<String, dynamic> j) => ReturnOrderItem(
        returnId: qInt(j['return_id'] ?? j['id']) ?? 0,
        returnNumber: qStr(j['return_number']),
        orderId: qInt(j['order_id']) ?? 0,
        orderNumber: qStr(j['order_number']),
        product: qStr(j['product']),
        quantity: qInt(j['quantity']) ?? 1,
        reason: qStr(j['reason']),
        reasonNote: qStr(j['reason_note']),
        refundAmount: qDbl(j['refund_amount']),
        status: qStr(j['status']),
        orderStatus: qStr(j['order_status']),
        createdAt: qDate(j['created_at']),
        updatedAt: qDate(j['updated_at']),
      );

  /// "damaged_product" → "Damaged product"
  String get reasonLabel {
    final r = reason.replaceAll('_', ' ').trim();
    return r.isEmpty ? '' : r[0].toUpperCase() + r.substring(1).toLowerCase();
  }
}

class ReturnTrackEvent {
  final String status;
  final String location;
  final String date;
  const ReturnTrackEvent(this.status, this.location, this.date);
}

class ReturnTrackInfo {
  final int returnId;
  final String returnNumber;
  final String awbCode;
  final String courier;
  final String status;
  final String trackingStatus;
  final String trackUrl;
  final String etd;
  final List<ReturnTrackEvent> events;

  const ReturnTrackInfo({
    required this.returnId,
    required this.returnNumber,
    required this.awbCode,
    required this.courier,
    required this.status,
    required this.trackingStatus,
    required this.trackUrl,
    required this.etd,
    required this.events,
  });

  factory ReturnTrackInfo.fromJson(Map<String, dynamic> j) {
    // Shiprocket: tracking_data → {track_status, shipment_track:[…],
    //   shipment_track_activities:[{date, activity, location, status}], track_url, etd}
    dynamic td = j['tracking_data'];
    if (td is Map && td['tracking_data'] is Map) td = td['tracking_data'];
    final t = td is Map ? Map<String, dynamic>.from(td) : <String, dynamic>{};
    final events = <ReturnTrackEvent>[];
    for (final a in (t['shipment_track_activities'] as List? ?? const []).whereType<Map>()) {
      events.add(ReturnTrackEvent(
        qStr(a['activity'] ?? a['sr-status-label'] ?? a['status']),
        qStr(a['location']),
        qStr(a['date']),
      ));
    }
    var current = qStr(j['tracking_status']);
    final st = t['shipment_track'];
    if (current.isEmpty && st is List && st.isNotEmpty && st.first is Map) {
      current = qStr((st.first as Map)['current_status']);
    }
    return ReturnTrackInfo(
      returnId: qInt(j['return_id']) ?? 0,
      returnNumber: qStr(j['return_number']),
      awbCode: qStr(j['awb_code']),
      courier: qStr(j['courier_company']),
      status: qStr(j['status']),
      trackingStatus: current,
      trackUrl: qStr(t['track_url']),
      etd: qStr(t['etd']),
      events: events,
    );
  }
}

class OrderExtrasService {
  OrderExtrasService._();

  // ── Invoice ────────────────────────────────────────────
  /// Returns the invoice PDF URL.
  static Future<OrderExtrasResult<String>> invoiceUrl(int orderId) async {
    final r = await QnxApi.post(ApiUrls.orderInvoiceUrl, {'order_id': orderId});
    if (!r.ok) {
      return OrderExtrasResult(false, null, r.error('Could not get the invoice.'), needsLogin: r.authFailed);
    }
    final url = _findUrl(r.body);
    if (url == null) {
      return const OrderExtrasResult(false, null, 'Invoice is not ready yet. Please try again later.');
    }
    return OrderExtrasResult(true, url, '');
  }

  static String? _findUrl(dynamic v) {
    if (v is Map) {
      for (final k in const ['invoice_url', 'url', 'invoice']) {
        final s = v[k];
        if (s is String && s.startsWith('http')) return s;
      }
      for (final e in v.values) {
        final f = _findUrl(e);
        if (f != null) return f;
      }
    } else if (v is List) {
      for (final e in v) {
        final f = _findUrl(e);
        if (f != null) return f;
      }
    }
    return null;
  }

  // ── Returns ────────────────────────────────────────────
  /// My return requests (newest first).
  static Future<OrderExtrasResult<List<ReturnOrderItem>>> myReturns() async {
    final r = await QnxApi.post(ApiUrls.returnOrdersUrl, const {});
    if (!r.ok) {
      return OrderExtrasResult(false, null, r.error('Could not load your returns.'), needsLogin: r.authFailed);
    }
    final all = r.list.map(ReturnOrderItem.fromJson).toList();

    // The list API is not user-scoped yet → keep only returns of my orders.
    Set<int> mine = {};
    try {
      final orders = await OrderService.getMyOrders({});
      mine = {for (final OrderData o in orders.data) o.orderId};
    } catch (_) {
      return const OrderExtrasResult(false, null, 'Could not load your orders. Please try again.');
    }
    final list = all.where((e) => mine.contains(e.orderId)).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return OrderExtrasResult(true, list, '');
  }

  static Future<OrderExtrasResult<ReturnTrackInfo>> trackReturn(int returnId) async {
    final r = await QnxApi.post(ApiUrls.returnOrderTrackUrl, {'return_id': returnId});
    if (!r.ok) {
      return OrderExtrasResult(false, null, r.error('Tracking is not available yet.'), needsLogin: r.authFailed);
    }
    return OrderExtrasResult(true, ReturnTrackInfo.fromJson(r.dataMap), '');
  }

  // ── Address ────────────────────────────────────────────
  static Future<OrderExtrasResult<DeliveryAddress>> updateAddress(int id, Map<String, String> fields) async {
    final r = await QnxApi.post(ApiUrls.addressUpdateUrl, {...fields, 'id': id, 'country': 'India'});
    if (!r.ok) {
      return OrderExtrasResult(false, null, r.error('Could not update the address.'), needsLogin: r.authFailed);
    }
    final d = r.map['data'];
    final addr = d is Map ? DeliveryAddress.fromJson(Map<String, dynamic>.from(d)) : null;
    return OrderExtrasResult(true, addr, 'Address updated');
  }
}
