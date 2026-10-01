// ============ Send OTP for Password Reset Models ============

// Send OTP Request
class ForgotPasswordSendOtpRequest {
  final String email;

  ForgotPasswordSendOtpRequest({
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }
}

// Send OTP Response
class ForgotPasswordSendOtpResponse {
  final String message;

  ForgotPasswordSendOtpResponse({
    required this.message,
  });

  factory ForgotPasswordSendOtpResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordSendOtpResponse(
      message: json['message'] ?? 'OTP sent to your email',
    );
  }
}

// ============ Verify OTP for Password Reset Models ============

// Verify OTP Request
class ForgotPasswordVerifyOtpRequest {
  final String email;
  final String otp;

  ForgotPasswordVerifyOtpRequest({
    required this.email,
    required this.otp,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'otp': otp,
    };
  }
}

// Verify OTP Response
class ForgotPasswordVerifyOtpResponse {
  final String message;

  ForgotPasswordVerifyOtpResponse({
    required this.message,
  });

  factory ForgotPasswordVerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordVerifyOtpResponse(
      message: json['message'] ?? 'OTP verified successfully',
    );
  }
}

// ============ Reset Password Models ============

// Reset Password Request
class ForgotPasswordResetRequest {
  final String email;
  final String password;
  final String confirmPassword;

  ForgotPasswordResetRequest({
    required this.email,
    required this.password,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
    };
  }
}

// Reset Password Response
class ForgotPasswordResetResponse {
  final String message;

  ForgotPasswordResetResponse({
    required this.message,
  });

  factory ForgotPasswordResetResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResetResponse(
      message: json['message'] ?? 'Password reset successful! Please sign in.',
    );
  }
}