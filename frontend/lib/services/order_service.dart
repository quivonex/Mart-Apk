import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import 'api_urls.dart';

class OrderService {
  static const String _contentType = 'application/json';

  static const String _tokenKey = 'access_token';

  static const List<String> _fallbackTokenKeys = [
    'access_token',
    'accessToken',
    'token',
    'auth_token',
    'authToken',
    'bearer_token',
  ];

  static Future<String?> _getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String? token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) return token;

      for (final key in _fallbackTokenKeys) {
        token = prefs.getString(key);
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== API 1: My Orders ====================
  static Future<OrderResponse> getMyOrders(Map<String, dynamic> body) async {
    try {
      final String? accessToken = await _getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Authentication required. Please login again.');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.myOrdersUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': _contentType,
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthenticated. Please login again.');
      }

      if (response.statusCode >= 400) {
        try {
          final errorData = jsonDecode(response.body);
          final msg = errorData['message'] ??
              errorData['detail'] ??
              'Server error: ${response.statusCode}';
          throw Exception(msg);
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }

      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;
      final OrderResponse orderResponse = OrderResponse.fromJson(jsonData);

      if (!orderResponse.success) {
        throw Exception(orderResponse.message ?? 'Failed to load orders.');
      }

      return orderResponse;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to load orders: ${e.toString()}');
    }
  }

  // ==================== API 2: Order Detail ====================
  static Future<OrderDetailResponse> getOrderDetail(int orderId) async {
    try {
      final String? accessToken = await _getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Authentication required. Please login again.');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.myOrderDetailUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': _contentType,
          'Accept': 'application/json',
        },
        body: jsonEncode({'order_id': orderId}),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthenticated. Please login again.');
      }

      if (response.statusCode >= 400) {
        try {
          final errorData = jsonDecode(response.body);
          final msg = errorData['message'] ??
              errorData['detail'] ??
              'Server error: ${response.statusCode}';
          throw Exception(msg);
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }

      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;
      final OrderDetailResponse detailResponse =
          OrderDetailResponse.fromJson(jsonData);

      if (!detailResponse.success) {
        throw Exception(detailResponse.message ?? 'Order not found.');
      }

      return detailResponse;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to load order detail: ${e.toString()}');
    }
  }

  // ==================== API 3: Cancel Order ====================
  static Future<CancelOrderResponse> cancelOrder(int orderId) async {
    try {
      final String? accessToken = await _getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Authentication required. Please login again.');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.cancelOrderUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': _contentType,
          'Accept': 'application/json',
        },
        body: jsonEncode({'order_id': orderId}),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthenticated. Please login again.');
      }

      if (response.statusCode >= 400) {
        try {
          final errorData = jsonDecode(response.body);
          final msg = errorData['message'] ??
              errorData['detail'] ??
              'Server error: ${response.statusCode}';
          throw Exception(msg);
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }

      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;
      final CancelOrderResponse cancelResponse =
          CancelOrderResponse.fromJson(jsonData);

      if (!cancelResponse.success) {
        throw Exception(cancelResponse.message ?? 'Failed to cancel order.');
      }

      return cancelResponse;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to cancel order: ${e.toString()}');
    }
  }

  // ==================== API 4: Track Shipment ====================
  static Future<TrackShipmentResponse> trackShipment(int shipmentId) async {
    try {
      final String? accessToken = await _getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Authentication required. Please login again.');
      }

      final response = await http.post(
        Uri.parse(ApiUrls.trackShipmentUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': _contentType,
          'Accept': 'application/json',
        },
        body: jsonEncode({'shipment_id': shipmentId}),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthenticated. Please login again.');
      }

      if (response.statusCode >= 400) {
        try {
          final errorData = jsonDecode(response.body);
          final msg = errorData['message'] ??
              errorData['detail'] ??
              'Server error: ${response.statusCode}';
          throw Exception(msg);
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }

      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;
      final TrackShipmentResponse trackResponse =
          TrackShipmentResponse.fromJson(jsonData);

      if (!trackResponse.success) {
        throw Exception(
            trackResponse.message ?? 'Tracking information not available.');
      }

      return trackResponse;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to track shipment: ${e.toString()}');
    }
  }

  // ==================== API 5: Return Order ====================
  static Future<ReturnOrderResponse> returnOrder({
    required int orderId,
    required int quantity,
    required String reason,
    String? reasonNote,
  }) async {
    try {
      final String? accessToken = await _getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Authentication required. Please login again.');
      }

      final Map<String, dynamic> body = {
        'order_id': orderId,
        'quantity': quantity,
        'reason': reason,
      };

      if (reasonNote != null && reasonNote.isNotEmpty) {
        body['reason_note'] = reasonNote;
      }

      final response = await http.post(
        Uri.parse(ApiUrls.returnOrderUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': _contentType,
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthenticated. Please login again.');
      }

      if (response.statusCode >= 400) {
        try {
          final errorData = jsonDecode(response.body);
          final msg = errorData['message'] ??
              errorData['detail'] ??
              'Server error: ${response.statusCode}';
          throw Exception(msg);
        } catch (_) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }

      final Map<String, dynamic> jsonData =
          jsonDecode(response.body) as Map<String, dynamic>;
      final ReturnOrderResponse returnResponse =
          ReturnOrderResponse.fromJson(jsonData);

      if (!returnResponse.success) {
        throw Exception(
            returnResponse.message ?? 'Failed to submit return request.');
      }

      return returnResponse;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to submit return: ${e.toString()}');
    }
  }
}
