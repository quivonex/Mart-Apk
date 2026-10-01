import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cart_model.dart';
import 'api_urls.dart';
import '../utils/shared_preferences_helper.dart';

class CartService {
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

  // ============ Update Cart Quantity ============
  static Future<UpdateCartQuantityResponse> updateCartQuantity(
      UpdateCartQuantityRequest request) async {
    try {
      final accessToken = await SharedPreferencesHelper.getAccessToken();

      if (accessToken == null) {
        throw Exception('Please login to update cart');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.updateCartQuantityUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return UpdateCartQuantityResponse.fromJson(responseData);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        String errorMessage = 'Failed to update quantity';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'];
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