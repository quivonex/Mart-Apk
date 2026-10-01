import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/registration_model.dart';
import 'api_urls.dart';

class RegistrationService {
  // Send OTP
  static Future<SendOtpResponse> sendOtp(SendOtpRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.sendOtpUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return SendOtpResponse.fromJson(responseData);
      } else {
        String errorMessage = 'Failed to send OTP';
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
      if (e is Exception) {
        throw Exception(e.toString());
      }
      throw Exception('Network error. Please check your connection.');
    }
  }

  // Verify OTP
  static Future<VerifyOtpResponse> verifyOtp(VerifyOtpRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.verifyOtpUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return VerifyOtpResponse.fromJson(responseData);
      } else {
        String errorMessage = 'OTP verification failed';
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
      if (e is Exception) {
        throw Exception(e.toString());
      }
      throw Exception('Network error. Please check your connection.');
    }
  }

  // Complete Registration
  static Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.registerUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return RegisterResponse.fromJson(responseData);
      } else {
        String errorMessage = 'Registration failed';
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
      if (e is Exception) {
        throw Exception(e.toString());
      }
      throw Exception('Network error. Please check your connection.');
    }
  }
}