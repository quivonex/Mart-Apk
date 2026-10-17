import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cart_model.dart';
import 'api_urls.dart';
import '../utils/shared_preferences_helper.dart';

/// Result of [CartService.shippingEstimate].
class CartShippingEstimate {
  /// Live courier charge (₹). null = could not be priced → shown "At checkout".
  final double? amount;

  /// Delivery pincode the estimate is for.
  final String? pincode;

  /// Why there is no amount (no saved address, product weight missing, …).
  final String? note;

  const CartShippingEstimate({this.amount, this.pincode, this.note});
}

class CartService {
  // ============ Shipping estimate (replaces the fixed ₹500) ============
  //   POST order/address/list/        {}  -> {status, data:[{id, pincode, …}]}
  //   POST shiprocket/shipping-rates/ {product_ids:[…], address_id, payment_method}
  //        -> {status:true, total_shipping_charge, companies:[…]}
  // Live courier rate (weight / size / pickup + delivery pincode).
  // The final charge is still set by the backend when the order is placed.
  static int? _addressId;
  static String? _addressPincode;

  static Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body, String token) async {
    final res = await http
        .post(
      Uri.parse('${ApiUrls.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 40));
    try {
      final d = jsonDecode(res.body);
      final m = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
      m['_code'] = res.statusCode;
      return m;
    } catch (_) {
      return {'_code': res.statusCode, 'message': 'Server error (${res.statusCode}).'};
    }
  }

  static Future<CartShippingEstimate> shippingEstimate(
      List<int> productIds, {
        bool cod = false,
      }) async {
    if (productIds.isEmpty) return const CartShippingEstimate(amount: 0);
    try {
      final token = await SharedPreferencesHelper.getAccessToken();
      if (token == null || token.isEmpty) {
        return const CartShippingEstimate(note: 'Log in to see shipping');
      }

      // 1. Saved delivery address (first one) – cached once found.
      if (_addressId == null) {
        final a = await _postJson('/order/address/list/', {}, token);
        final list = a['data'] is List ? a['data'] as List : const [];
        final first = list.whereType<Map>().firstWhere(
              (m) => m['id'] != null,
          orElse: () => const {},
        );
        if (first.isNotEmpty) {
          _addressId = first['id'] is int ? first['id'] : int.tryParse('${first['id']}');
          _addressPincode = '${first['pincode'] ?? ''}';
        }
      }
      if (_addressId == null) {
        return const CartShippingEstimate(note: 'Add a delivery address at checkout to see shipping');
      }

      // 2. Live courier rate for the selected products.
      final r = await _postJson('/shiprocket/shipping-rates/', {
        'product_ids': productIds,
        'address_id': _addressId,
        'payment_method': cod ? 'COD' : 'Prepaid',
      }, token);
      final ok = (r['_code'] as int) < 300 && (r['status'] == true || r['success'] == true);
      if (!ok) {
        if (r['_code'] == 404 && '${r['message']}'.toLowerCase().contains('address')) {
          _addressId = null; // address deleted – look it up again next time
        }
        return CartShippingEstimate(
          pincode: _addressPincode,
          note: '${r['message'] ?? r['error'] ?? 'Shipping will be calculated at checkout'}',
        );
      }
      final total = double.tryParse('${r['total_shipping_charge'] ?? ''}') ?? 0;
      return total > 0
          ? CartShippingEstimate(amount: total, pincode: _addressPincode)
          : CartShippingEstimate(pincode: _addressPincode, note: 'Calculated by courier at checkout');
    } catch (e) {
      final s = e.toString();
      return CartShippingEstimate(
        note: s.contains('SocketException') || s.contains('ClientException')
            ? 'Could not reach the server'
            : 'Shipping will be calculated at checkout',
      );
    }
  }

  /// Forget the cached address (e.g. after the user adds/changes one).
  static void resetShippingAddress() {
    _addressId = null;
    _addressPincode = null;
  }

  // ============ Add Product to Cart ============
  static Future<AddToCartResponse> addToCart(AddToCartRequest request) async {
    try {
      final accessToken = await SharedPreferencesHelper.getAccessToken();

      if (accessToken == null) {
        throw Exception('Please login to add items to cart');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.addToCartUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AddToCartResponse.fromJson(responseData);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        String errorMessage = 'Failed to add to cart';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData.containsKey('msg')) {
            errorMessage = responseData['msg'];
          } else if (responseData.containsKey('error')) {
            errorMessage = responseData['error'];
          } else if (responseData.containsKey('detail')) {
            errorMessage = responseData['detail'];
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============ Get Cart List ============
  static Future<GetCartListResponse> getCartList(
      GetCartListRequest request) async {
    try {
      final accessToken = await SharedPreferencesHelper.getAccessToken();

      if (accessToken == null) {
        throw Exception('Please login to view cart');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.getCartListUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return GetCartListResponse.fromJson(responseData);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        String errorMessage = 'Failed to fetch cart';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData.containsKey('msg')) {
            errorMessage = responseData['msg'];
          } else if (responseData.containsKey('error')) {
            errorMessage = responseData['error'];
          } else if (responseData.containsKey('detail')) {
            errorMessage = responseData['detail'];
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============ Change Quantity (+1 / -1) ============
  // The backend has no cart update API. cart/add/ adds `quantity` to the
  // existing cart row, so +1 / -1 changes the quantity of that product.
  // Never send -1 when the quantity is 1 – remove the item instead.
  static Future<AddToCartResponse> changeQuantity({
    required int productId,
    required int delta,
  }) async {
    final userId = await SharedPreferencesHelper.getUserId();
    if (userId == null) {
      throw Exception('Please login to update cart');
    }
    final response = await addToCart(
      AddToCartRequest(productId: productId, userId: userId, quantity: delta),
    );
    if (!response.status) {
      throw Exception(response.message);
    }
    return response;
  }

  // ============ Remove Item from Cart ============
  static Future<RemoveFromCartResponse> removeFromCart(
      RemoveFromCartRequest request) async {
    try {
      final accessToken = await SharedPreferencesHelper.getAccessToken();

      if (accessToken == null) {
        throw Exception('Please login to remove items from cart');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.removeFromCartUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return RemoveFromCartResponse.fromJson(responseData);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        String errorMessage = 'Failed to remove item';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData.containsKey('msg')) {
            errorMessage = responseData['msg'];
          } else if (responseData.containsKey('error')) {
            errorMessage = responseData['error'];
          } else if (responseData.containsKey('detail')) {
            errorMessage = responseData['detail'];
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
