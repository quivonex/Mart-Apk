import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductEnquiryRequest {
  final String product;         // Product ID (required)
  final String personName;      // min 2 chars (required)
  final String email;           // valid email (required)
  final String contact;         // 10-digit mobile (required)
  final String address;         // full address (required)
  final String pincode;         // 6-digit (required)
  final String quantity;        // min 1 (required)
  final String message;         // min 10 chars (required)
  final String demoRequired;    // "yes" or "no" (required)
  final String? demoType;       // "at_location" or "online" (conditional)
  final String price;           // required
  final String? enquiryReferralCode;
  final String? selectedColor;
  final String? selectedSize;
  final String? selectedVariant;
  final String? selectedVariantData; // JSON string
  final File? attachment;       // JPG, PNG, WebP, PDF, max 5MB

  ProductEnquiryRequest({
    required this.product,
    required this.personName,
    required this.email,
    required this.contact,
    required this.address,
    required this.pincode,
    required this.quantity,
    required this.message,
    required this.demoRequired,
    this.demoType,
    required this.price,
    this.enquiryReferralCode,
    this.selectedColor,
    this.selectedSize,
    this.selectedVariant,
    this.selectedVariantData,
    this.attachment,
  });

  /// Convert to MultipartRequest for form-data POST
  Future<http.MultipartRequest> toMultipartRequest(String url) async {
    final request = http.MultipartRequest('POST', Uri.parse(url));

    // Required fields
    request.fields['product'] = product;
    request.fields['person_name'] = personName;
    request.fields['email'] = email;
    request.fields['contact'] = contact;
    request.fields['address'] = address;
    request.fields['pincode'] = pincode;
    request.fields['quantity'] = quantity;
    request.fields['message'] = message;
    request.fields['demo_required'] = demoRequired;
    request.fields['price'] = price;

    // Conditional: demo_type (only when demo_required = "yes")
    if (demoRequired == 'yes' && demoType != null && demoType!.isNotEmpty) {
      request.fields['demo_type'] = demoType!;
    }

    // Optional fields
    if (enquiryReferralCode != null && enquiryReferralCode!.isNotEmpty) {
      request.fields['enquiry_referral_code'] = enquiryReferralCode!;
    }
    if (selectedColor != null && selectedColor!.isNotEmpty) {
      request.fields['selected_color'] = selectedColor!;
    }
    if (selectedSize != null && selectedSize!.isNotEmpty) {
      request.fields['selected_size'] = selectedSize!;
    }
    if (selectedVariant != null && selectedVariant!.isNotEmpty) {
      request.fields['selected_variant'] = selectedVariant!;
    }
    if (selectedVariantData != null && selectedVariantData!.isNotEmpty) {
      request.fields['selected_variant_data'] = selectedVariantData!;
    }

    // Optional: attachment file
    if (attachment != null) {
      final file = await http.MultipartFile.fromPath(
        'attachment',
        attachment!.path,
      );
      request.files.add(file);
    }

    return request;
  }
}

class ProductEnquiryResponse {
  final dynamic status; // Can be bool true/false or missing
  final String? message;
  final Map<String, dynamic>? errors;
  final String? error;

  ProductEnquiryResponse({
    this.status,
    this.message,
    this.errors,
    this.error,
  });

  factory ProductEnquiryResponse.fromJson(Map<String, dynamic> json) {
    return ProductEnquiryResponse(
      status: json['status'],
      message: json['message']?.toString(),
      errors: json['errors'] is Map
          ? Map<String, dynamic>.from(json['errors'])
          : null,
      error: json['error']?.toString(),
    );
  }

  /// Success if status == true (bool)
  bool get isSuccess {
    if (status is bool) return status == true;
    if (status is String) return status.toString().toLowerCase() == 'success';
    return false;
  }

  /// User-friendly message
  String get displayMessage {
    if (isSuccess) {
      return message ?? 'Enquiry submitted successfully';
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

  /// All field errors as flat list
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