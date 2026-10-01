// ============ Company Name (for dropdown) ============

class CompanyName {
  final int id;
  final String name;

  CompanyName({required this.id, required this.name});

  factory CompanyName.fromJson(Map<String, dynamic> json) {
    return CompanyName(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

// ============ Company Names Response ============

class CompanyNamesResponse {
  final bool status;
  final String? message;
  final List<CompanyName> data;

  CompanyNamesResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory CompanyNamesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return CompanyNamesResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => CompanyName.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
}

// ============ Branch Model ============

class Branch {
  final int id;
  final int company;
  final String companyName;
  final String name;
  final String phoneNumber;
  final String email;
  final String address;
  final bool isActive;

  Branch({
    required this.id,
    required this.company,
    required this.companyName,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.isActive,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      company: json['company'] is int
          ? json['company']
          : int.tryParse(json['company']?.toString() ?? '0') ?? 0,
      companyName: json['company_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company': company,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
    };
  }
}

// ============ Branch List Response ============

class BranchListResponse {
  final bool status;
  final String? message;
  final List<Branch> data;

  BranchListResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory BranchListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return BranchListResponse(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: list.map((e) => Branch.fromJson(e)).toList(),
    );
  }

  bool get isSuccess => status;
  bool get hasBranches => data.isNotEmpty;
}

// ============ Branch Action Response (create/update/delete/restore) ============

class BranchActionResponse {
  final bool status;
  final String? message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  BranchActionResponse({
    required this.status,
    this.message,
    this.data,
    this.errors,
  });

  factory BranchActionResponse.fromJson(Map<String, dynamic> json) {
    return BranchActionResponse(
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