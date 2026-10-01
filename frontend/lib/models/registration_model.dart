// ============ Send OTP Models ============

// Send OTP Request
class SendOtpRequest {
  final String email;

  SendOtpRequest({
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }
}

// Send OTP Response
class SendOtpResponse {
  final String message;

  SendOtpResponse({
    required this.message,
  });

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendOtpResponse(
      message: json['message'] ?? 'OTP sent successfully',
    );
  }
}

// ============ Verify OTP Models ============

// Verify OTP Request
class VerifyOtpRequest {
  final String email;
  final String otp;

  VerifyOtpRequest({
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
class VerifyOtpResponse {
  final String message;

  VerifyOtpResponse({
    required this.message,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      message: json['message'] ?? 'Email verified successfully',
    );
  }
}

// ============ Registration Models ============

// Registration Request
class RegisterRequest {
  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final String username;
  final String password;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'address': address,
      'username': username,
      'password': password,
    };
  }
}

// Registration Response
class RegisterResponse {
  final String message;

  RegisterResponse({
    required this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      message: json['message'] ?? 'Account created successfully',
    );
  }
}