// ============ Seller Model ============

class Seller {
  final int id;
  final String businessType;
  final String businessCategory;
  final String contactPersonName;
  final String designation;
  final String email;
  final String mobile;
  final String alternateMobile;
  final String landline;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String panNumber;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String branchName;
  final bool isApproved;
  final String createdAt;

  Seller({
    required this.id,
    required this.businessType,
    required this.businessCategory,
    required this.contactPersonName,
    required this.designation,
    required this.email,
    required this.mobile,
    required this.alternateMobile,
    required this.landline,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.panNumber,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    required this.branchName,
    required this.isApproved,
    required this.createdAt,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      businessType: json['business_type']?.toString() ?? '',
      businessCategory: json['business_category']?.toString() ?? '',
      contactPersonName: json['contact_person_name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      alternateMobile: json['alternate_mobile']?.toString() ?? '',
      landline: json['landline']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      panNumber: json['pan_number']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      ifscCode: json['ifsc_code']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      isApproved: json['is_approved'] == true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_type': businessType,
      'business_category': businessCategory,
      'contact_person_name': contactPersonName,
      'designation': designation,
      'email': email,
      'mobile': mobile,
      'alternate_mobile': alternateMobile,
      'landline': landline,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'pan_number': panNumber,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
      'branch_name': branchName,
      'is_approved': isApproved,
      'created_at': createdAt,
    };
  }
}

// ============ Seller List Response ============

class SellerListResponse {
  final String status;
  final String? message;
  final List<Seller> data;

  SellerListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory SellerListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return SellerListResponse(
      status: json['status']?.toString() ?? 'error',
      message: json['message']?.toString(),
      data: dataList.map((e) => Seller.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status.toLowerCase() == 'success';
  bool get hasSeller => data.isNotEmpty;
  Seller? get firstSeller => data.isNotEmpty ? data.first : null;
}

// ============ Seller Request (Create/Update) ============

class SellerRequest {
  final int? id;                  // only for update
  final int? user;                // only for create
  final String businessType;
  final String businessCategory;
  final String contactPersonName;
  final String designation;
  final String email;
  final String mobile;
  final String? alternateMobile;
  final String? landline;
  final String address;
  final String state;
  final String city;
  final String pincode;
  final String? panNumber;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? branchName;

  SellerRequest({
    this.id,
    this.user,
    required this.businessType,
    required this.businessCategory,
    required this.contactPersonName,
    required this.designation,
    required this.email,
    required this.mobile,
    this.alternateMobile,
    this.landline,
    required this.address,
    required this.state,
    required this.city,
    required this.pincode,
    this.panNumber,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.branchName,
  });

  /// For CREATE — includes "user" field
  Map<String, dynamic> toCreateJson() {
    return {
      if (user != null) 'user': user,
      'business_type': businessType,
      'business_category': businessCategory,
      'contact_person_name': contactPersonName,
      'designation': designation,
      'email': email,
      'mobile': mobile,
      'alternate_mobile': alternateMobile ?? '',
      'landline': landline ?? '',
      'address': address,
      'state': state,
      'city': city,
      'pincode': pincode,
      'pan_number': panNumber ?? '',
      'account_number': accountNumber ?? '',
      'ifsc_code': ifscCode ?? '',
      'bank_name': bankName ?? '',
      'branch_name': branchName ?? '',
    };
  }

  /// For UPDATE — includes "id" (no "user")
  Map<String, dynamic> toUpdateJson() {
    return {
      if (id != null) 'id': id,
      'business_type': businessType,
      'business_category': businessCategory,
      'contact_person_name': contactPersonName,
      'designation': designation,
      'email': email,
      'mobile': mobile,
      'alternate_mobile': alternateMobile ?? '',
      'landline': landline ?? '',
      'address': address,
      'state': state,
      'city': city,
      'pincode': pincode,
      'pan_number': panNumber ?? '',
      'account_number': accountNumber ?? '',
      'ifsc_code': ifscCode ?? '',
      'bank_name': bankName ?? '',
      'branch_name': branchName ?? '',
    };
  }

  /// Dropdown options
  static const List<Map<String, String>> businessTypeOptions = [
    {'value': 'individual', 'label': 'Individual'},
    {'value': 'partnership', 'label': 'Partnership'},
    {'value': 'llp', 'label': 'LLP'},
    {'value': 'private_limited', 'label': 'Private Limited'},
    {'value': 'public_limited', 'label': 'Public Limited'},
  ];
}

// ============ Seller Action Response (Create/Update) ============

class SellerActionResponse {
  final String status;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  SellerActionResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  factory SellerActionResponse.fromJson(Map<String, dynamic> json) {
    return SellerActionResponse(
      status: json['status']?.toString() ?? 'error',
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'])
          : null,
      errors: json['errors'] is Map
          ? Map<String, dynamic>.from(json['errors'])
          : null,
    );
  }

  bool get isSuccess => status.toLowerCase() == 'success';

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