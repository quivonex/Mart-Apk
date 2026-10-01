import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_model.dart';
import 'api_urls.dart';

class LoginService {
  // Login API call
  static Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.loginUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      // Parse response
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Success
        return LoginResponse.fromJson(responseData);
      } else {
        // Error - extract message from response
        String errorMessage = 'Login failed';
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'];
        } else if (responseData is Map && responseData.containsKey('error')) {
          errorMessage = responseData['error'];
        } else if (responseData is Map && responseData.containsKey('detail')) {
          errorMessage = responseData['detail'];
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Network or parsing error
      if (e is Exception) {
        throw Exception(e.toString());
      }
      throw Exception('Network error. Please check your connection.');
    }
  }
}