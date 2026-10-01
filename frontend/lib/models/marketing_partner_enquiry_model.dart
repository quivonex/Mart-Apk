import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

/// ==================== REQUEST MODEL ====================
class MarketingPartnerEnquiryRequest {
  final String applicationType;
  final String fullName;
  final String? email;
  final String mobile;
  final int? stateId;
  final String? state;
  final int? districtId;
  final String? district;
  final int? talukaId;
  final String? taluka;
  final int? villageId;
  final String? village;
  final String pincode;
  final String? workingArea;
  final String? profession;
  final String? experience;
  final List<String>? promotionPlatforms;
  final String? teamSize;
  final XFile? profileImage; // Changed from File? to XFile?
  final String? referredByCode;

  MarketingPartnerEnquiryRequest({
    this.applicationType = 'marketing_partner',
    required this.fullName,
    this.email,
    required this.mobile,
    this.stateId,
    this.state,
    this.districtId,
    this.district,
    this.talukaId,
    this.taluka,
    this.villageId,
    this.village,
    required this.pincode,
    this.workingArea,
    this.profession,
    this.experience,
    this.promotionPlatforms,
    this.teamSize,
    this.profileImage,
    this.referredByCode,
  });

  /// Convert to Map for multipart/form-data request
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'application_type': applicationType,
      'full_name': fullName,
      'mobile': mobile,
      'pincode': pincode,
    };

    if (email != null && email!.isNotEmpty) map['email'] = email;
    if (stateId != null) map['state_id'] = stateId.toString();
    if (state != null && state!.isNotEmpty) map['state'] = state;
    if (districtId != null) map['district_id'] = districtId.toString();
    if (district != null && district!.isNotEmpty) map['district'] = district;
    if (talukaId != null) map['taluka_id'] = talukaId.toString();
    if (taluka != null && taluka!.isNotEmpty) map['taluka'] = taluka;
    if (villageId != null) map['village_id'] = villageId.toString();
    if (village != null && village!.isNotEmpty) map['village'] = village;
    if (workingArea != null && workingArea!.isNotEmpty) {
      map['working_area'] = workingArea;
    }
    if (profession != null && profession!.isNotEmpty) {
      map['profession'] = profession;
    }
    if (experience != null && experience!.isNotEmpty) {
      map['experience'] = experience;
    }
    if (promotionPlatforms != null && promotionPlatforms!.isNotEmpty) {
      map['promotion_platforms'] = promotionPlatforms;
    }
    if (teamSize != null && teamSize!.isNotEmpty) map['team_size'] = teamSize;
    if (referredByCode != null && referredByCode!.isNotEmpty) {
      map['referred_by_code'] = referredByCode;
    }

    return map;
  }
}

/// ==================== RESPONSE MODEL ====================
class MarketingPartnerEnquiryResponse {
  final bool status;
  final String message;
  final Map<String, dynamic>? data;
  final Map<String, List<String>>? errors;

  MarketingPartnerEnquiryResponse({
    required this.status,
    required this.message,
    this.data,
    this.errors,
  });

  factory MarketingPartnerEnquiryResponse.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>>? parsedErrors;

    if (json['errors'] != null && json['errors'] is Map) {
      parsedErrors = {};
      (json['errors'] as Map).forEach((key, value) {
        if (value is List) {
          parsedErrors![key.toString()] =
              value.map((e) => e.toString()).toList();
        } else {
          parsedErrors![key.toString()] = [value.toString()];
        }
      });
    }

    return MarketingPartnerEnquiryResponse(
      status: json['status'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
      errors: parsedErrors,
    );
  }

  /// Get first error message as a single string
  String get firstErrorMessage {
    if (errors != null && errors!.isNotEmpty) {
      final firstKey = errors!.keys.first;
      final firstList = errors![firstKey];
      if (firstList != null && firstList.isNotEmpty) {
        return firstList.first;
      }
    }
    return message;
  }

  /// Get all error messages joined
  String get allErrorMessages {
    if (errors != null && errors!.isNotEmpty) {
      final List<String> allErrors = [];
      errors!.forEach((key, value) {
        allErrors.addAll(value);
      });
      return allErrors.join('\n');
    }
    return message;
  }
}