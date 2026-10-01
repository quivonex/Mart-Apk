// ============ Add to Cart Request ============

class AddToCartRequest {
  final int productId;
  final int userId;
  final int quantity;

  AddToCartRequest({
    required this.productId,
    required this.userId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'user_id': userId,
      'quantity': quantity,
    };
  }
}

// ============ Add to Cart Response ============

class AddToCartResponse {
  final bool status;
  final String message;

  AddToCartResponse({
    required this.status,
    required this.message,
  });

  factory AddToCartResponse.fromJson(Map<String, dynamic> json) {
    return AddToCartResponse(
      status: _parseStatus(json['status']),
      message: json['message'] ?? json['msg'] ?? 'Added to cart',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
    };
  }
}

// ============ Get Cart List Request ============

class GetCartListRequest {
  final int userId;

  GetCartListRequest({
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
    };
  }
}

// ============ Cart Item Model ============

class CartItemModel {
  final int id;
  final int productId;
  final String productName;
  final String productCode;
  final String thumbnail;
  final double unitPrice;
  final int quantity;
  final bool codAvailable;

  CartItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.thumbnail,
    required this.unitPrice,
    required this.quantity,
    required this.codAvailable,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    String thumb = json['thumbnail'] ?? '';
    if (thumb.isNotEmpty && !thumb.startsWith('http')) {
      thumb = 'https://api.qnxmartb2b.com/$thumb';
    }

    return CartItemModel(
      id: json['id'] ?? 0,
      productId: json['product'] ?? json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      productCode: json['product_code'] ?? '',
      thumbnail: thumb,
      unitPrice: _parseDouble(json['unit_price']),
      quantity: json['quantity'] ?? 0,
      codAvailable: json['COD_available'] ?? false,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_code': productCode,
      'thumbnail': thumbnail,
      'unit_price': unitPrice,
      'quantity': quantity,
      'COD_available': codAvailable,
    };
  }
}

// ============ Get Cart List Response ============

class GetCartListResponse {
  final bool status;
  final List<CartItemModel> cartItems;

  GetCartListResponse({
    required this.status,
    required this.cartItems,
  });

  factory GetCartListResponse.fromJson(Map<String, dynamic> json) {
    List<CartItemModel> items = [];
    if (json['cart_items'] != null && json['cart_items'] is List) {
      items = (json['cart_items'] as List)
          .map((item) => CartItemModel.fromJson(item))
          .toList();
    }
    return GetCartListResponse(
      status: _parseStatus(json['status']),
      cartItems: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'cart_items': cartItems.map((item) => item.toJson()).toList(),
    };
  }
}

// ============ Update Cart Quantity Request ============

class UpdateCartQuantityRequest {
  final int cartId;
  final int quantity;

  UpdateCartQuantityRequest({
    required this.cartId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'cart_id': cartId,
      'quantity': quantity,
    };
  }
}

// ============ Update Cart Quantity Response ============

class UpdateCartQuantityResponse {
  final bool status;
  final String message;

  UpdateCartQuantityResponse({
    required this.status,
    required this.message,
  });

  factory UpdateCartQuantityResponse.fromJson(Map<String, dynamic> json) {
    return UpdateCartQuantityResponse(
      status: _parseStatus(json['status']),
      message: json['message'] ?? json['msg'] ?? 'Quantity updated',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
    };
  }
}

// ============ Remove From Cart Request ============

class RemoveFromCartRequest {
  final int cartItemId;

  RemoveFromCartRequest({
    required this.cartItemId,
  });

  Map<String, dynamic> toJson() {
    return {
      'cart_item_id': cartItemId,
    };
  }
}

// ============ Remove From Cart Response ============

class RemoveFromCartResponse {
  final bool status;
  final String message;

  RemoveFromCartResponse({
    required this.status,
    required this.message,
  });

  factory RemoveFromCartResponse.fromJson(Map<String, dynamic> json) {
    return RemoveFromCartResponse(
      status: _parseStatus(json['status']),
      message: json['message'] ?? json['msg'] ?? 'Item removed from cart',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
    };
  }
}

// ============ Status Parser Helper ============
// API returns "success" (String) instead of true (bool)

bool _parseStatus(dynamic value) {
  if (value == true) return true;
  if (value is String) return value.toLowerCase() == 'success';
  return false;
}