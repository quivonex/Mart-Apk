class PropertyEnquiryRequest {
  final int property;              // required
  final String customerName;       // required, min 2 chars
  final String customerEmail;      // required, valid email
  final String customerMobile;     // required, 10 digits
  final String? flatType;          // optional — studio, 1_bhk, 2_bhk, etc.
  final double? budgetMin;         // optional
  final double? budgetMax;         // optional, >= budgetMin
  final String message;            // required, min 10 chars
  final String status;             // always "new"
  final String? referralCode;      // optional

  PropertyEnquiryRequest({
    required this.property,
    required this.customerName,
    required this.customerEmail,
    required this.customerMobile,
    this.flatType,
    this.budgetMin,
    this.budgetMax,
    required this.message,
    this.status = 'new',
    this.referralCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'property': property,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_mobile': customerMobile,
      'flat_type': flatType,         // null if not selected
      'budget_min': budgetMin,       // null if empty
      'budget_max': budgetMax,       // null if empty
      'message': message,
      'status': status,              // always "new"
      if (referralCode != null && referralCode!.isNotEmpty)
        'referral_code': referralCode,
    };
  }

  /// Flat type options for dropdown
  static const List<Map<String, String>> flatTypeOptions = [
    {'value': 'studio', 'label': 'Studio'},
    {'value': '1_bhk', 'label': '1 BHK'},
    {'value': '2_bhk', 'label': '2 BHK'},
    {'value': '3_bhk', 'label': '3 BHK'},
    {'value': '4_bhk', 'label': '4 BHK'},
    {'value': '5_bhk', 'label': '5 BHK'},
    {'value': 'other', 'label': 'Other'},
  ];
}

class PropertyEnquiryResponse {
  final bool? success;               // API returns "success" field
  final dynamic status;              // some APIs use "status"
  final String? message;
  final Map<String, dynamic>? errors;
  final String? error;

  PropertyEnquiryResponse({
    this.success,
    this.status,
    this.message,
    this.errors,
    this.error,
  });

  factory PropertyEnquiryResponse.fromJson(Map<String, dynamic> json) {
    // Handle both "success" and "status" fields
    bool? successValue;
    if (json['success'] is bool) {
      successValue = json['success'];
    } else if (json['status'] is bool) {
      successValue = json['status'];
    } else if (json['status'] is String) {
      successValue =
          json['status'].toString().toLowerCase() == 'success';
    }

    return PropertyEnquiryResponse(
      success: successValue,
      status: json['status'],
      message: json['message']?.toString(),
      errors: json['errors'] is Map
          ? Map<String, dynamic>.from(json['errors'])
          : null,
      error: json['error']?.toString(),
    );
  }

  /// Success if `success == true` OR `status == true/"success"`
  bool get isSuccess => success == true;

  /// User-friendly message (picks first field error if any)
  String get displayMessage {
    if (isSuccess) {
      return message ?? 'Enquiry submitted successfully.';
    }

    if (errors != null && errors!.isNotEmpty) {
      final firstKey = errors!.keys.first;
      final firstError = errors![firstKey];
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }

    return message ?? error ?? 'Something went wrong';
  }

  /// All field errors as a flat list
  List<String> get allErrors {
    if (errors == null) return [];
    final List<String> all = [];
    errors!.forEach((key, value) {
      if (value is List) {
        for (final e in value) {
          all.add(e.toString());
        }
      } else {
        all.add(value.toString());
      }
    });
    return all;
  }
}