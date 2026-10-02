// ============ Company Image ============

class CompanyImage {
  final int id;
  final String url;
  final String imageS3Key;

  CompanyImage({
    required this.id,
    required this.url,
    required this.imageS3Key,
  });

  factory CompanyImage.fromJson(Map<String, dynamic> json) {
    return CompanyImage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      url: json['url']?.toString() ?? '',
      imageS3Key: json['image_s3_key']?.toString() ?? '',
    );
  }

  /// Prefer url, fallback to s3 key
  String get displayUrl => url.isNotEmpty ? url : imageS3Key;
}

// ============ Company Model ============

class Company {
  final int id;
  final String name;
  final String logo;
  final List<CompanyImage> images;
  final String companySlogan;
  final String ownerName;
  final String email;
  final String phoneNumber;
  final String whatsappNo;
  final String address;
  final String state;
  final String district;
  final String taluka;
  final String village;
  final String pincode;
  final String pickupLocation;
  final String gstNumber;
  final String companyPanNo;
  final String registrationNo;
  final String ianNo;
  final String farmRegistrationYear;
  final String websiteUrl;
  final String youtubeUrl;
  final String facebookUrl;
  final String linkedinUrl;
  final String instagramUrl;
  final String privacyPolicyUrl;
  final String termsConditionsUrl;
  final List<String> multipleEmailIds;
  final List<String> contacts;
  final String shortDescription;
  final String longDescription;
  final String latitude;
  final String longitude;
  final bool isActive;
  final bool isiCertified;
  final bool isoCertified;
  final bool codAvailable;
  final String createdAt;
  final String paymentStatus; // "paid" or "pending"

  Company({
    required this.id,
    required this.name,
    required this.logo,
    required this.images,
    required this.companySlogan,
    required this.ownerName,
    required this.email,
    required this.phoneNumber,
    required this.whatsappNo,
    required this.address,
    required this.state,
    required this.district,
    required this.taluka,
    required this.village,
    required this.pincode,
    required this.pickupLocation,
    required this.gstNumber,
    required this.companyPanNo,
    required this.registrationNo,
    required this.ianNo,
    required this.farmRegistrationYear,
    required this.websiteUrl,
    required this.youtubeUrl,
    required this.facebookUrl,
    required this.linkedinUrl,
    required this.instagramUrl,
    required this.privacyPolicyUrl,
    required this.termsConditionsUrl,
    required this.multipleEmailIds,
    required this.contacts,
    required this.shortDescription,
    required this.longDescription,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.isiCertified,
    required this.isoCertified,
    required this.codAvailable,
    required this.createdAt,
    required this.paymentStatus,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    final imagesList = json['images'] as List? ?? [];

    List<String> parseStringList(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).toList();
      }
      return [];
    }

    return Company(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      images: imagesList.map((e) => CompanyImage.fromJson(e)).toList(),
      companySlogan: json['company_slogan']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      whatsappNo: json['whatsapp_no']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      taluka: json['taluka']?.toString() ?? '',
      village: json['village']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      pickupLocation: json['pickup_location']?.toString() ?? '',
      gstNumber: json['gst_number']?.toString() ?? '',
      companyPanNo: json['company_pan_no']?.toString() ?? '',
      registrationNo: json['registration_no']?.toString() ?? '',
      ianNo: json['IAN_No']?.toString() ?? '',
      farmRegistrationYear:
      json['farm_registration_year']?.toString() ?? '',
      websiteUrl: json['website_url']?.toString() ?? '',
      youtubeUrl: json['youtube_url']?.toString() ?? '',
      facebookUrl: json['facebook_url']?.toString() ?? '',
      linkedinUrl: json['linkedin_url']?.toString() ?? '',
      instagramUrl: json['instagram_url']?.toString() ?? '',
      privacyPolicyUrl: json['privacy_policy_url']?.toString() ?? '',
      termsConditionsUrl:
      json['terms_conditions_url']?.toString() ?? '',
      multipleEmailIds: parseStringList(json['multiple_email_ids']),
      contacts: parseStringList(json['contacts']),
      shortDescription: json['short_description']?.toString() ?? '',
      longDescription: json['long_description']?.toString() ?? '',
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      isActive: json['is_active'] == true,
      isiCertified: json['ISI_certified'] == true,
      isoCertified: json['ISO_certified'] == true,
      codAvailable: json['COD_available'] == true,
      createdAt: json['created_at']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? 'pending',
    );
  }

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isPaymentPending => paymentStatus.toLowerCase() == 'pending';
}

// ============ Company List Response ============

class CompanyListResponse {
  final bool status;
  final String? message;
  final List<Company> data;

  CompanyListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory CompanyListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return CompanyListResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: dataList.map((e) => Company.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
  bool get hasCompanies => data.isNotEmpty;
}

// ============ Company Create/Update Response ============

class CompanyActionResponse {
  final bool status;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  CompanyActionResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  factory CompanyActionResponse.fromJson(Map<String, dynamic> json) {
    return CompanyActionResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'])
          : null,
      errors: json['errors'] is Map
          ? Map<String, dynamic>.from(json['errors'])
          : null,
    );
  }

  bool get isSuccess => status;

  int? get newId {
    if (data == null) return null;
    final id = data!['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String get displayMessage {
    if (isSuccess) return message ?? 'Success';

    if (errors != null && errors!.isNotEmpty) {
      final firstKey = errors!.keys.first;
      final firstError = errors![firstKey];
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }

    return message ?? 'Something went wrong';
  }
}

// ============ Payment Order Response ============
//
// Backend returns:
// { "status": true, "order_id": "order_xxx", "amount": "999.00",
//   "amount_in_paise": 99900, "key": "rzp_...", "company_id": 5 }
//
// NOTE: "amount" is a STRING in rupees, so the old int.tryParse() returned
// null. Use amountInPaise for Razorpay.

class CompanyPaymentOrderResponse {
  final bool status;
  final String? message;
  final String? key;
  final String amount; // rupees, e.g. "999.00"
  final int amountInPaise; // e.g. 99900
  final String? orderId;
  final String currency;
  final int? companyId;

  CompanyPaymentOrderResponse({
    required this.status,
    this.message,
    this.key,
    this.amount = '0',
    this.amountInPaise = 0,
    this.orderId,
    this.currency = 'INR',
    this.companyId,
  });

  factory CompanyPaymentOrderResponse.fromJson(Map<String, dynamic> json) {
    final rupees = json['amount']?.toString() ?? '0';
    int paise = json['amount_in_paise'] is int
        ? json['amount_in_paise']
        : int.tryParse(json['amount_in_paise']?.toString() ?? '') ?? 0;
    if (paise == 0) {
      paise = ((double.tryParse(rupees) ?? 0) * 100).round();
    }
    return CompanyPaymentOrderResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      key: json['key']?.toString(),
      amount: rupees,
      amountInPaise: paise,
      orderId: json['order_id']?.toString(),
      currency: json['currency']?.toString() ?? 'INR',
      companyId: json['company_id'] is int
          ? json['company_id']
          : int.tryParse(json['company_id']?.toString() ?? ''),
    );
  }

  bool get isSuccess =>
      status && (orderId?.isNotEmpty ?? false) && (key?.isNotEmpty ?? false);

  String get amountLabel {
    final v = double.tryParse(amount) ?? amountInPaise / 100;
    return v == v.roundToDouble() ? '₹${v.toInt()}' : '₹${v.toStringAsFixed(2)}';
  }
}

// ============ Payment Verify Response ============

class CompanyPaymentVerifyResponse {
  final bool status;
  final String? message;

  CompanyPaymentVerifyResponse({
    required this.status,
    this.message,
  });

  factory CompanyPaymentVerifyResponse.fromJson(Map<String, dynamic> json) {
    return CompanyPaymentVerifyResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
    );
  }

  bool get isSuccess => status;
}

// ============ Company Detail Response ============
// POST /company/company/single-retrieve/  body: { "company_id": 5 }

class CompanyDetailResponse {
  final bool status;
  final String? message;
  final Company? data;

  CompanyDetailResponse({required this.status, this.message, this.data});

  factory CompanyDetailResponse.fromJson(Map<String, dynamic> json) {
    return CompanyDetailResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? Company.fromJson(Map<String, dynamic>.from(json['data']))
          : null,
    );
  }

  bool get isSuccess => status && data != null;
}

// ============ Simple Response (soft-delete / restore) ============
// Backend returns { "message": "..."} on success, { "error": "..." } on failure.

class CompanySimpleResponse {
  final bool status;
  final String message;

  CompanySimpleResponse({required this.status, required this.message});

  bool get isSuccess => status;
}