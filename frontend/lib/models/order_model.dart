// ==================== My Orders List Models ====================

class OrderResponse {
  final bool success;
  final List<OrderData> data;
  final String? message;

  OrderResponse({
    required this.success,
    required this.data,
    this.message,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>?)
          ?.map((item) => OrderData.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.map((item) => item.toJson()).toList(),
      'message': message,
    };
  }
}

class OrderData {
  final int orderId;              // ✅ ADDED
  final String orderNumber;
  final String createdAt;
  final ProductInfo product;
  final double totalAmount;
  final String status;
  final CompanyInfo company;

  OrderData({
    required this.orderId,          // ✅ ADDED
    required this.orderNumber,
    required this.createdAt,
    required this.product,
    required this.totalAmount,
    required this.status,
    required this.company,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      orderId: json['order_id'] is int
          ? json['order_id']
          : int.tryParse(json['order_id']?.toString() ?? '0') ?? 0, // ✅ ADDED
      orderNumber: json['order_number'] ?? '',
      createdAt: json['created_at'] ?? '',
      product: ProductInfo.fromJson(json['product'] ?? {}),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? '',
      company: CompanyInfo.fromJson(json['company'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,          // ✅ ADDED
      'order_number': orderNumber,
      'created_at': createdAt,
      'product': product.toJson(),
      'total_amount': totalAmount,
      'status': status,
      'company': company.toJson(),
    };
  }

  String get formattedDate {
    try {
      final dateTime = DateTime.parse(createdAt);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return createdAt;
    }
  }

  String get formattedAmount {
    return '₹${totalAmount.toStringAsFixed(0)}';
  }

  int get statusColorValue {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 0xFFFF9800;
      case 'CONFIRMED':
        return 0xFF2196F3;
      case 'SHIPPED':
        return 0xFF4CAF50;
      case 'DELIVERED':
        return 0xFF0D47A1;
      case 'CANCELLED':
        return 0xFFF44336;
      default:
        return 0xFF9E9E9E;
    }
  }
}

class ProductInfo {
  final String name;
  final String thumbnailS3Key;
  final int quantity;

  ProductInfo({
    required this.name,
    required this.thumbnailS3Key,
    required this.quantity,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      name: json['name'] ?? '',
      thumbnailS3Key: json['thumbnail_s3_key'] ?? '',
      quantity: json['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'thumbnail_s3_key': thumbnailS3Key,
      'quantity': quantity,
    };
  }
}

class CompanyInfo {
  final String name;

  CompanyInfo({
    required this.name,
  });

  factory CompanyInfo.fromJson(Map<String, dynamic> json) {
    return CompanyInfo(
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}

// ==================== Order Detail Models ====================

class OrderDetailResponse {
  final bool success;
  final OrderDetailData? data;
  final String? message;

  OrderDetailResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory OrderDetailResponse.fromJson(Map<String, dynamic> json) {
    return OrderDetailResponse(
      success: json['success'] ?? false,
      data: json['data'] != null
          ? OrderDetailData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.toJson(),
      'message': message,
    };
  }
}

class OrderDetailData {
  final int orderId;
  final String orderNumber;
  final String status;
  final String createdAt;
  final String updatedAt;
  final ProductInfo product;
  final double price;
  final double subtotal;
  final AddressInfo address;
  final ShipmentInfo shipment;
  final String paymentMethod;
  final bool paymentStatus;
  final double discountAmount;
  final double shippingCharge;
  final double taxAmount;
  final double totalAmount;
  final String notes;
  final bool canCancel;
  final int shipmentId;
  final List<StatusHistory> statusHistory;

  OrderDetailData({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.product,
    required this.price,
    required this.subtotal,
    required this.address,
    required this.shipment,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.discountAmount,
    required this.shippingCharge,
    required this.taxAmount,
    required this.totalAmount,
    required this.notes,
    required this.canCancel,
    required this.shipmentId,
    required this.statusHistory,
  });

  factory OrderDetailData.fromJson(Map<String, dynamic> json) {
    return OrderDetailData(
      orderId: json['order_id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      product: ProductInfo.fromJson(json['product'] ?? {}),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      address: AddressInfo.fromJson(json['address'] ?? {}),
      shipment: ShipmentInfo.fromJson(json['shipment'] ?? {}),
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? false,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      shippingCharge: (json['shipping_charge'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] ?? '',
      canCancel: json['can_cancel'] ?? false,
      shipmentId: json['shipment_id'] ?? 0,
      statusHistory: (json['status_history'] as List<dynamic>?)
          ?.map((item) => StatusHistory.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'order_number': orderNumber,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'product': product.toJson(),
      'price': price,
      'subtotal': subtotal,
      'address': address.toJson(),
      'shipment': shipment.toJson(),
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'discount_amount': discountAmount,
      'shipping_charge': shippingCharge,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'notes': notes,
      'can_cancel': canCancel,
      'shipment_id': shipmentId,
      'status_history': statusHistory.map((item) => item.toJson()).toList(),
    };
  }

  String get formattedDate {
    try {
      final dateTime = DateTime.parse(createdAt);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return createdAt;
    }
  }

  String get formattedAmount => '₹${totalAmount.toStringAsFixed(0)}';
  String get formattedSubtotal => '₹${subtotal.toStringAsFixed(0)}';
  String get formattedPrice => '₹${price.toStringAsFixed(0)}';
  String get formattedDiscount => '₹${discountAmount.toStringAsFixed(0)}';
  String get formattedShipping => '₹${shippingCharge.toStringAsFixed(0)}';
  String get formattedTax => '₹${taxAmount.toStringAsFixed(0)}';

  int get statusColorValue {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 0xFFFF9800;
      case 'CONFIRMED':
        return 0xFF2196F3;
      case 'PACKED':
        return 0xFF9C27B0;
      case 'SHIPPED':
        return 0xFF4CAF50;
      case 'OUT FOR DELIVERY':
        return 0xFF00BCD4;
      case 'DELIVERED':
        return 0xFF0D47A1;
      case 'CANCELLED':
        return 0xFFF44336;
      default:
        return 0xFF9E9E9E;
    }
  }
}

class AddressInfo {
  final String city;
  final String state;
  final String pincode;
  final String mobile;

  AddressInfo({
    required this.city,
    required this.state,
    required this.pincode,
    required this.mobile,
  });

  factory AddressInfo.fromJson(Map<String, dynamic> json) {
    return AddressInfo(
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      mobile: json['mobile'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'state': state,
      'pincode': pincode,
      'mobile': mobile,
    };
  }

  String get fullAddress => '$city, $state - $pincode';
}

class ShipmentInfo {
  final int shipmentId;              // ✅ ADDED
  final String courierCompany;
  final String awbCode;
  final String status;

  ShipmentInfo({
    required this.shipmentId,         // ✅ ADDED
    required this.courierCompany,
    required this.awbCode,
    required this.status,
  });

  factory ShipmentInfo.fromJson(Map<String, dynamic> json) {
    return ShipmentInfo(
      shipmentId: json['shipment_id'] is int
          ? json['shipment_id']
          : int.tryParse(json['shipment_id']?.toString() ?? '0') ?? 0, // ✅ ADDED
      courierCompany: json['courier_company'] ?? '',
      awbCode: json['awb_code'] ?? '',
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_id': shipmentId,     // ✅ ADDED
      'courier_company': courierCompany,
      'awb_code': awbCode,
      'status': status,
    };
  }
}

class StatusHistory {
  final String status;
  final String timestamp;

  StatusHistory({
    required this.status,
    required this.timestamp,
  });

  factory StatusHistory.fromJson(Map<String, dynamic> json) {
    return StatusHistory(
      status: json['status'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'timestamp': timestamp,
    };
  }

  String get formattedDate {
    try {
      final dateTime = DateTime.parse(timestamp);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return timestamp;
    }
  }
}

// ==================== Cancel Order Model ====================

class CancelOrderResponse {
  final bool success;
  final String? message;

  CancelOrderResponse({
    required this.success,
    this.message,
  });

  factory CancelOrderResponse.fromJson(Map<String, dynamic> json) {
    return CancelOrderResponse(
      success: json['success'] ?? false,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
    };
  }
}

// ==================== Track Shipment Models ====================

class TrackShipmentResponse {
  final bool success;
  final TrackShipmentData? data;
  final String? message;

  TrackShipmentResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory TrackShipmentResponse.fromJson(Map<String, dynamic> json) {
    return TrackShipmentResponse(
      success: json['success'] ?? false,
      data: json['data'] != null
          ? TrackShipmentData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data?.toJson(),
      'message': message,
    };
  }
}

class TrackShipmentData {
  final TrackingData? trackingData;

  TrackShipmentData({
    this.trackingData,
  });

  factory TrackShipmentData.fromJson(Map<String, dynamic> json) {
    return TrackShipmentData(
      trackingData: json['tracking_data'] != null
          ? TrackingData.fromJson(json['tracking_data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tracking_data': trackingData?.toJson(),
    };
  }
}

class TrackingData {
  final List<ShipmentTrack> shipmentTrack;
  final String trackUrl;
  final List<ShipmentTrackActivity> shipmentTrackActivities;

  TrackingData({
    required this.shipmentTrack,
    required this.trackUrl,
    required this.shipmentTrackActivities,
  });

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    return TrackingData(
      shipmentTrack: (json['shipment_track'] as List<dynamic>?)
          ?.map((item) => ShipmentTrack.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      trackUrl: json['track_url'] ?? '',
      shipmentTrackActivities: (json['shipment_track_activities'] as List<dynamic>?)
          ?.map((item) => ShipmentTrackActivity.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_track': shipmentTrack.map((item) => item.toJson()).toList(),
      'track_url': trackUrl,
      'shipment_track_activities':
      shipmentTrackActivities.map((item) => item.toJson()).toList(),
    };
  }
}

class ShipmentTrack {
  final String courierName;
  final String awbCode;
  final String currentStatus;
  final String edd;

  ShipmentTrack({
    required this.courierName,
    required this.awbCode,
    required this.currentStatus,
    required this.edd,
  });

  factory ShipmentTrack.fromJson(Map<String, dynamic> json) {
    return ShipmentTrack(
      courierName: json['courier_name'] ?? '',
      awbCode: json['awb_code'] ?? '',
      currentStatus: json['current_status'] ?? '',
      edd: json['edd'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courier_name': courierName,
      'awb_code': awbCode,
      'current_status': currentStatus,
      'edd': edd,
    };
  }

  String get formattedEdd {
    try {
      final dateTime = DateTime.parse(edd);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return edd;
    }
  }
}

class ShipmentTrackActivity {
  final String date;
  final String status;
  final String activity;
  final String location;

  ShipmentTrackActivity({
    required this.date,
    required this.status,
    required this.activity,
    required this.location,
  });

  factory ShipmentTrackActivity.fromJson(Map<String, dynamic> json) {
    return ShipmentTrackActivity(
      date: json['date'] ?? '',
      status: json['status'] ?? '',
      activity: json['activity'] ?? '',
      location: json['location'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'status': status,
      'activity': activity,
      'location': location,
    };
  }

  String get formattedDate {
    try {
      final dateTime = DateTime.parse(date);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} $hour:$minute';
    } catch (e) {
      return date;
    }
  }
}

// ==================== Return Order Model ====================

class ReturnOrderResponse {
  final bool success;
  final String? message;

  ReturnOrderResponse({
    required this.success,
    this.message,
  });

  factory ReturnOrderResponse.fromJson(Map<String, dynamic> json) {
    return ReturnOrderResponse(
      success: json['success'] ?? false,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
    };
  }
}