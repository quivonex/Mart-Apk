import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/forgot_password_model.dart';
import 'api_urls.dart';

class ForgotPasswordService {
  // Send OTP for Password Reset
  static Future<ForgotPasswordSendOtpResponse> sendOtp(
      ForgotPasswordSendOtpRequest request,
      ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.forgotPasswordSendOtpUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ForgotPasswordSendOtpResponse.fromJson(responseData);
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

  // Verify OTP for Password Reset
  static Future<ForgotPasswordVerifyOtpResponse> verifyOtp(
      ForgotPasswordVerifyOtpRequest request,
      ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.forgotPasswordVerifyOtpUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ForgotPasswordVerifyOtpResponse.fromJson(responseData);
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

  // Reset Password
  static Future<ForgotPasswordResetResponse> resetPassword(
      ForgotPasswordResetRequest request,
      ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiUrls.forgotPasswordResetUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ForgotPasswordResetResponse.fromJson(responseData);
      } else {
        String errorMessage = 'Password reset failed';
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