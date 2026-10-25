import 'package:qnx_mart/l10n/app_language.dart';
// lib/models/franchise_plan_model.dart
//
// Matches POST /franchicies/product-franchise-plans/
// {
//   "status": true,
//   "message": "Franchise plans fetched successfully.",
//   "count": 2,
//   "data": [
//     {
//       "id": 1,
//       "company_id": 1,
//       "user": 1,
//       "product": 1,
//       "plan_name": "Silver",
//       "amount": "300000.00",
//       "description": "Tea Franchise",
//       "plan_products": [
//         { "id": 1, "item_name": "Cup", "quantity": "500.00", "unit": "pcs" },
//         ...
//       ]
//     }
//   ]
// }

class FranchisePlanRequest {
  final String slug;

  FranchisePlanRequest({required this.slug});

  Map<String, dynamic> toJson() => {'slug': slug};
}

// ============ Plan Product Item ============

class FranchisePlanProduct {
  final int id;
  final String itemName;
  final String quantity; // API sends string like "500.00"
  final String unit;

  FranchisePlanProduct({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
  });

  factory FranchisePlanProduct.fromJson(Map<String, dynamic> json) {
    return FranchisePlanProduct(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      itemName: json['item_name']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '0',
      unit: json['unit']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_name': itemName,
    'quantity': quantity,
    'unit': unit,
  };

  /// "500.00" → 500, "20.50" → 20.5
  double get quantityValue =>
      double.tryParse(quantity.replaceAll(',', '')) ?? 0.0;

  /// "500.00" → "500", "20.50" → "20.5"
  String get quantityLabel {
    final v = quantityValue;
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}

// ============ Franchise Plan ============

class FranchisePlan {
  final int id;
  final int companyId;
  final int? userId;
  final int product;
  final String planName;
  final String amount;
  final String description;
  final List<FranchisePlanProduct> planProducts;

  FranchisePlan({
    required this.id,
    required this.companyId,
    this.userId,
    required this.product,
    required this.planName,
    required this.amount,
    required this.description,
    required this.planProducts,
  });

  factory FranchisePlan.fromJson(Map<String, dynamic> json) {
    final productsList = json['plan_products'] as List? ?? [];
    return FranchisePlan(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      companyId: json['company_id'] is int
          ? json['company_id']
          : int.tryParse(json['company_id']?.toString() ?? '0') ?? 0,
      userId: json['user'] is int
          ? json['user']
          : int.tryParse(json['user']?.toString() ?? ''),
      product: json['product'] is int
          ? json['product']
          : int.tryParse(json['product']?.toString() ?? '0') ?? 0,
      planName: json['plan_name']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      description: json['description']?.toString() ?? '',
      planProducts: productsList
          .whereType<Map>()
          .map((e) => FranchisePlanProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    if (userId != null) 'user': userId,
    'product': product,
    'plan_name': planName,
    'amount': amount,
    'description': description,
    'plan_products': planProducts.map((p) => p.toJson()).toList(),
  };

  /// "300000.00" → "₹3,00,000"  (Indian grouping)
  String get amountLabel {
    final v = double.tryParse(amount.replaceAll(',', '')) ?? 0;
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(2);
    final parts = s.split('.');
    var n = parts[0];
    if (n.length > 3) {
      final last3 = n.substring(n.length - 3);
      var rest = n.substring(0, n.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      n = '${groups.join(',')},$last3';
    }
    return '₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
  }
}

// ============ Plans Response ============

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
      status: json['status'] == true ||
          json['status']?.toString().toLowerCase() == 'true',
      message: json['message']?.toString(),
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      data: dataList
          .whereType<Map>()
          .map((e) => FranchisePlan.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get hasPlans => data.isNotEmpty;
  bool get isEmpty => data.isEmpty;
}

// ============ Apply Request ============

class FranchiseApplyRequest {
  final int company;
  final int product;
  final int franchisePlan;
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
  final String joiningDate;
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

  Map<String, dynamic> toJson() => {
    'company': company,
    'product': product,
    'FranchisePlan': franchisePlan,
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

  static String todayDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class FranchiseApplyResponse {
  final dynamic status;
  final String? message;
  final Map<String, dynamic>? errors;
  final String? error;

  FranchiseApplyResponse({this.status, this.message, this.errors, this.error});

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

  bool get isSuccess {
    if (status is bool) return status == true;
    if (status is String) return status.toString().toLowerCase() == 'success';
    return false;
  }

  String get displayMessage {
    if (isSuccess) {
      return message ?? tr('Franchise application submitted successfully!');
    }
    if (errors != null && errors!.isNotEmpty) {
      final firstKey = errors!.keys.first;
      final firstError = errors![firstKey];
      if (firstError is List && firstError.isNotEmpty) {
        return firstError.first.toString();
      }
      return firstError.toString();
    }
    return message ?? error ?? tr('Something went wrong.');
  }

  List<String> get allErrors {
    if (errors == null) return [];
    final all = <String>[];
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