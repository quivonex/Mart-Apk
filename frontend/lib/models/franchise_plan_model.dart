class FranchisePlanRequest {
  final String slug;

  FranchisePlanRequest({required this.slug});

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
    };
  }
}// ============ Plan Product Item ============

class FranchisePlanProduct {
  final String itemName;
  final int quantity;
  final String unit;

  FranchisePlanProduct({
    required this.itemName,
    required this.quantity,
    required this.unit,
  });

  factory FranchisePlanProduct.fromJson(Map<String, dynamic> json) {
    return FranchisePlanProduct(
      itemName: json['item_name']?.toString() ?? '',
      quantity: json['quantity'] is int
          ? json['quantity']
          : int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

// ============ Franchise Plan ============

class FranchisePlan {
  final int id;
  final String planName;
  final String amount;
  final String description;
  final int companyId;
  final int product;
  final List<FranchisePlanProduct> planProducts;

  FranchisePlan({
    required this.id,
    required this.planName,
    required this.amount,
    required this.description,
    required this.companyId,
    required this.product,
    required this.planProducts,
  });

  factory FranchisePlan.fromJson(Map<String, dynamic> json) {
    final productsList = json['plan_products'] as List? ?? [];
    return FranchisePlan(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      planName: json['plan_name']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      description: json['description']?.toString() ?? '',
      companyId: json['company_id'] is int
          ? json['company_id']
          : int.tryParse(json['company_id']?.toString() ?? '0') ?? 0,
      product: json['product'] is int
          ? json['product']
          : int.tryParse(json['product']?.toString() ?? '0') ?? 0,
      planProducts:
      productsList.map((item) => FranchisePlanProduct.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_name': planName,
      'amount': amount,
      'description': description,
      'company_id': companyId,
      'product': product,
      'plan_products': planProducts.map((p) => p.toJson()).toList(),
    };
  }
}

// ============ Franchise Plans Response ============

class FranchisePlanResponse {
  final bool status;
  final String? message;
  final int count;
  final List<FranchisePlan> data;

  FranchisePlanResponse({
    required this.status,
    this.message,
    this.count = 0,
    required this.data,
  });

  factory FranchisePlanResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return FranchisePlanResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString(),
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      data: dataList.map((item) => FranchisePlan.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (message != null) 'message': message,
      'count': count,
      'data': data.map((p) => p.toJson()).toList(),
    };
  }

  bool get hasPlans => data.isNotEmpty;
  bool get isEmpty => data.isEmpty;
}

class FranchiseApplyRequest {
  final int company;
  final int product;
  final int franchisePlan; // maps to "FranchisePlan" key
  final String franchiseName;
  final String ownerName;
  final String email;
  final String mobileNo;
  final String alternateMobileNo;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String gstNo;
  final String panNo;
  final String joiningDate; // YYYY-MM-DD
  final String? franchiseReferralCode;

  FranchiseApplyRequest({
    required this.company,
    required this.product,
    required this.franchisePlan,
    required this.franchiseName,
    required this.ownerName,
    required this.email,
    required this.mobileNo,
    this.alternateMobileNo = '',
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.gstNo = '',
    this.panNo = '',
    required this.joiningDate,
    this.franchiseReferralCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'company': company,
      'product': product,
      'FranchisePlan': franchisePlan, // ⚠️ capital 'F' as per API
      'franchise_name': franchiseName,
      'owner_name': ownerName,
      'email': email,
      'mobile_no': mobileNo,
      'alternate_mobile_no': alternateMobileNo,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'gst_no': gstNo,
      'pan_no': panNo,
      'joining_date': joiningDate,
      'franchise_referral_code': franchiseReferralCode,
    };
  }

  /// Helper — today's date in YYYY-MM-DD format
  static String todayDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class FranchiseApplyResponse {
  final dynamic status; // Can be bool true or String "success"
  final String? message;
  final Map<String, dynamic>? errors;
  final String? error;

  FranchiseApplyResponse({
    this.status,
    this.message,
    this.errors,
    this.error,
  });

  factory FranchiseApplyResponse.fromJson(Map<String, dynamic> json) {
    return FranchiseApplyResponse(
      status: json['status'],
      message: json['message']?.toString(),
      errors: json['errors'] is Map
          ? Map<String, dynamic>.from(json['errors'])
          : null,
      error: json['error']?.toString(),
    );
  }

  /// Success if status is `true` (bool) OR `"success"` (string)
  bool get isSuccess {
    if (status is bool) return status == true;
    if (status is String) return status.toString().toLowerCase() == 'success';
    return false;
  }

  /// Build a user-friendly message (including field errors if any)
  String get displayMessage {
    if (isSuccess) {
      return message ?? 'Franchise application submitted successfully!';
    }

    // If field-level errors exist, show first one
    if (errors != null && errors!.isNotEmpty) {
      final firstKey = errors!.keys.first;
      final firstError = errors![firstKey];
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }

    return message ?? error ?? 'Something went wrong.';
  }

  /// All field errors as a flat list (for UI display)
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