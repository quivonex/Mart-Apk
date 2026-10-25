import 'package:qnx_mart/l10n/app_language.dart';
class PropertyEnquiryRequest {
  final int property;              // required
  final String customerName;       // required, min 2 chars
  final String customerEmail;      // required, valid email
  final String customerMobile;     // required, 10 digits
  final String? flatType;          // optional — studio, 1_bhk, 2_bhk, etc.
  final double? budgetMin;         // optional
  final double? budgetMax;         // optional, >= budgetMin
  final String message;            // required, min 10 chars
  final String status;             // always "new" (read-only on the backend)
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

  /// Only digits, last 10 (so "+91 98765 43210" → "9876543210").
  static String cleanMobile(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  static num _money(double v) => v == v.roundToDouble() ? v.toInt() : v;

  /// Empty optional values are left out instead of being sent as null.
  Map<String, dynamic> toJson() {
    return {
      'property': property,
      'customer_name': customerName.trim(),
      'customer_email': customerEmail.trim(),
      'customer_mobile': cleanMobile(customerMobile),
      'message': message.trim(),
      if (flatType != null && flatType!.isNotEmpty) 'flat_type': flatType,
      if (budgetMin != null) 'budget_min': _money(budgetMin!),
      if (budgetMax != null) 'budget_max': _money(budgetMax!),
      if (referralCode != null && referralCode!.trim().isNotEmpty)
        'referral_code': referralCode!.trim(),
    };
  }

  /// Flat type options for dropdown (same keys as the backend FlatType choices)
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
  final String? detail;              // DRF auth / 404 / 405 errors
  final int? statusCode;

  /// Backend: website (user-posted) properties need an active customer
  /// subscription → 403 {subscription_required: true}.
  final bool subscriptionRequired;

  /// Backend: 403 "Your enquiry limit has been exhausted."
  final bool limitExhausted;

  /// True when the user must buy / renew a subscription to continue.
  bool get needsSubscription => subscriptionRequired || limitExhausted;

  PropertyEnquiryResponse({
    this.subscriptionRequired = false,
    this.limitExhausted = false,
    this.success,
    this.status,
    this.message,
    this.errors,
    this.error,
    this.detail,
    this.statusCode,
  });

  factory PropertyEnquiryResponse.fromJson(Map<String, dynamic> json,
      {int? statusCode}) {
    // Handle both "success" and "status" fields
    bool? successValue;
    if (json['success'] is bool) {
      successValue = json['success'];
    } else if (json['status'] is bool) {
      successValue = json['status'];
    } else if (json['status'] is String) {
      successValue = json['status'].toString().toLowerCase() == 'success';
    }

    // Some DRF errors come back as the field map itself: {"customer_mobile": [...]}
    Map<String, dynamic>? errors = json['errors'] is Map
        ? Map<String, dynamic>.from(json['errors'])
        : null;
    if (errors == null &&
        successValue == null &&
        statusCode != null &&
        statusCode >= 400 &&
        json.values.any((v) => v is List)) {
      errors = {
        for (final e in json.entries)
          if (e.value is List) e.key: e.value,
      };
    }

    return PropertyEnquiryResponse(
      success: successValue ??
          (statusCode != null && statusCode >= 400 ? false : null),
      status: json['status'],
      message: json['message']?.toString(),
      errors: errors,
      error: json['error']?.toString(),
      detail: json['detail']?.toString(),
      statusCode: statusCode,
      subscriptionRequired: json['subscription_required'] == true,
      limitExhausted: statusCode == 403 &&
          (json.containsKey('enquiry_limit') ||
              '${json['message'] ?? ''}'.toLowerCase().contains('limit')),
    );
  }

  bool get isSuccess => success == true;

  static String _fieldLabel(String key) => switch (key) {
    'property' => tr('Property'),
    'customer_name' => tr('Name'),
    'customer_email' => tr('Email'),
    'customer_mobile' => tr('Mobile'),
    'flat_type' => tr('Flat type'),
    'budget_min' => tr('Min budget'),
    'budget_max' => tr('Max budget'),
    'message' => tr('Message'),
    _ => key.replaceAll('_', ' '),
  };

  static String _firstText(dynamic v) {
    if (v is List && v.isNotEmpty) return _firstText(v.first);
    if (v is Map && v.isNotEmpty) return _firstText(v.values.first);
    return v.toString();
  }

  /// User-friendly message — never just "Something went wrong".
  String get displayMessage {
    if (isSuccess) {
      return message ?? tr('Enquiry submitted successfully.');
    }

    if (errors != null && errors!.isNotEmpty) {
      final key = errors!.keys.first;
      final text = _firstText(errors![key]);
      if (key == 'non_field_errors') return text;
      if (key == 'property' && text.toLowerCase().contains('invalid pk')) {
        return tr('This property is no longer available for enquiries.');
      }
      return '${_fieldLabel(key)}: $text';
    }

    if (detail != null && detail!.isNotEmpty) {
      if (statusCode == 401 || statusCode == 403) {
        return tr('Please log in again to send an enquiry. ({0})', [detail]);
      }
      return detail!;
    }

    final m = message ?? error;
    if (m != null && m.isNotEmpty) return m;

    return switch (statusCode) {
      null => tr('Could not send enquiry. Please try again.'),
      401 || 403 => tr('Please log in again to send an enquiry.'),
      404 => tr('Enquiry service not found (404). Please check the server URL.'),
      >= 500 => tr('Server error ({0}). Please try again in a moment.', [statusCode]),
      _ => tr('Could not send enquiry (HTTP {0}).', [statusCode]),
    };
  }

  /// All field errors as a flat list
  List<String> get allErrors {
    if (errors == null) return [];
    final List<String> all = [];
    errors!.forEach((key, value) {
      if (value is List) {
        for (final e in value) {
          all.add('${_fieldLabel(key)}: $e');
        }
      } else {
        all.add('${_fieldLabel(key)}: $value');
      }
    });
    return all;
  }
}
