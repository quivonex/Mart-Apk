class LoanEnquiryRequest {
  final String name;
  final String mobile;
  final String email;
  final String loanType;
  final double loanAmount;
  final int tenureYears;
  final double monthlyIncome;
  final String city;
  final String state;
  final String pincode;
  final String? remarks;

  LoanEnquiryRequest({
    required this.name,
    required this.mobile,
    required this.email,
    required this.loanType,
    required this.loanAmount,
    required this.tenureYears,
    required this.monthlyIncome,
    required this.city,
    required this.state,
    required this.pincode,
    this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobile': mobile,
      'email': email,
      'loan_type': loanType,
      'loan_amount': loanAmount,
      'tenure_years': tenureYears,
      'monthly_income': monthlyIncome,
      'city': city,
      'state': state,
      'pincode': pincode,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
    };
  }

  // Loan Type Options
  static const List<Map<String, String>> loanTypeOptions = [
    {'value': 'home_loan', 'label': 'Home Loan'},
    {'value': 'property_loan', 'label': 'Property Loan'},
    {'value': 'land_loan', 'label': 'Land Loan'},
    {'value': 'construction_loan', 'label': 'Construction Loan'},
    {'value': 'loan_against_property', 'label': 'Loan Against Property'},
  ];
}

class LoanEnquiryResponse {
  final bool? status;
  final String? message;
  final String? error;

  LoanEnquiryResponse({
    this.status,
    this.message,
    this.error,
  });

  factory LoanEnquiryResponse.fromJson(Map<String, dynamic> json) {
    return LoanEnquiryResponse(
      status: json['status'] as bool?,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  bool get isSuccess => status == true;

  String get displayMessage {
    if (isSuccess) {
      return message ?? 'Enquiry submitted successfully!';
    }
    return message ?? error ?? 'Something went wrong';
  }
}